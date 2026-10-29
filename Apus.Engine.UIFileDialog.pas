// Modal file selection on the real filesystem. Layout is deliberately kept in one method.
// This file is licensed under the terms of BSD-3 (see license.txt).
unit Apus.Engine.UIFileDialog;
interface
 uses Apus.Core, Apus.Files, Apus.Engine.Types, Apus.Engine.UITypes, Apus.Engine.UIWidgets,
  Apus.Engine.UITable, Apus.Engine.UIScene, Apus.Engine.Window;

 type
  TFileDialogMode=(fdOpen,fdSave);
  TFileType=record
   title,masks,ext:String8;
  end;
  TFileDialogResult=record
   accepted:boolean;
   path:String8;
   typeIndex:integer;
  end;
  TUIFileDialog=class;
  TFileDialogScene=class;
  TFileDialogPathEvent=procedure(dialog:TUIFileDialog;const path:String8) of object;
  TFileDialogValidate=function(dialog:TUIFileDialog;const value:TFileDialogResult):boolean of object;
  TFileDialogDone=procedure(dialog:TUIFileDialog;const value:TFileDialogResult) of object;

  // Setup runs in the owning window thread and starts a new request. A standalone widget calls onDone directly; the scene host
  // closes and restores focus before delivering it. Callbacks must not free the widget inline.
  TUIFileDialog=class(TUIElement)
   mode:TFileDialogMode;
   types:array of TFileType;
   showHidden:boolean;
   recentFolders,favoriteFolders:Strings8;
   onLocationsChanged:TObjProcedure; // the app may persist the two lists
   table:TUITable;
   placesPanel,previewPanel,optionsPanel:TUIElement;
   onSelect:TFileDialogPathEvent;
   onValidate:TFileDialogValidate;
   onDone:TFileDialogDone;
   constructor Create(width,height:single;parent:TUIElement;name:String8='');
   procedure Setup(mode:TFileDialogMode;const folder,fileName:String8;typeIndex:integer=0);
   procedure SetFolder(const path:String8); // '' clears the listing; drive buttons select a root
   function Folder:String8;
   procedure Confirm;
   procedure Cancel;
   procedure ShowError(const message:String8);
   function onHotKey(keycode:byte;shiftstate:byte):boolean; override;
   procedure Resize(newWidth,newHeight:single); override;
  protected
   pathEdit,nameEdit:TUIEditBox;
   typeBar:TUIElement;
   allTypeButton:TUIToggleButton;
   typeButtons:array of TUIToggleButton;
   upButton,acceptButton,cancelButton:TUIButton;
   nameLabel,messageLabel:TUILabel;
   navigationPanel,driveBar:TUIElement;
   directoryOutline,locationsList:TUITable;
   pinButton:TUIButton;
   procedure CreateControls; virtual;
   procedure LayoutControls; virtual;
  private
   fFolder,overwritePath:String8;
   items:TFolderItems;
   finished:boolean;
   allTypes:boolean;
   activeTypes:array of boolean;
   selectedType:integer;
   host:TFileDialogScene;
   procedure Refresh;
   procedure BuildDrives;
   procedure BuildTypes;
   procedure TypeClicked(index:integer;active:boolean);
   procedure UpdateTypes;
   procedure DriveClicked;
   procedure BuildLocations;
   procedure LocationSelected(sender:TUITable;row:integer);
   procedure LocationAction(tag:NativeInt;remove:boolean);
   function LocationPath(tag:NativeInt):String8;
   procedure PinFolder;
   procedure RememberFolder;
   procedure GoUp;
   procedure PathEntered;
   procedure Edited;
   function ItemPath(index:integer):String8;
   procedure RowSelected(sender:TUITable;row:integer);
   procedure RowActivated(sender:TUITable;row:integer);
   procedure Finish(const value:TFileDialogResult);
  end;

  // A reusable scene owned by the application, one per caller/window if needed.
  TFileDialogScene=class(TUIScene)
   dialog:TUIFileDialog;
   frame:TUIWindow;
   constructor Create(const sceneName:String8='FileDialog';wnd:TWindow=nil);
   destructor Destroy; override;
   procedure Open(modal:boolean=true);
   procedure onResize; override;
  private
   prevFocus:TUIElement;
   procedure Close;
  end;

implementation
 uses SysUtils, Math, Types, Apus.Conv, Apus.Strings, Apus.Geom2D, Apus.EventMan, Apus.Engine.Keys,
  Apus.Engine.API, Apus.Engine.DefaultStyle,
  Apus.Engine.UI, Apus.Engine.UIShapes, Apus.Engine.SceneEffects{$IFDEF MSWINDOWS}, Windows{$ENDIF};

 type
  TDialogButton=class(TUIButton)
   handler:TObjProcedure;
   procedure DoClick; override;
  end;
  TDialogEdit=class(TUIEditBox)
   dialog:TUIFileDialog;
   isPath:boolean;
   function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
   procedure onUniChar(ch:Char32;scancode:byte); override;
  end;
  TTypeChip=class(TUIToggleButton)
   dialog:TUIFileDialog;
   index:integer; // -1 is All
   procedure DoClick; override;
  end;
  TDriveBar=class(TUIElement)
   availableWidth:single;
   expanded:boolean;
   procedure Arrange(width:single);
   procedure UpdateHover;
   procedure onMouseMove; override;
   procedure onTimer; override;
  end;
  TDriveButton=class(TDialogButton)
   procedure onMouseMove; override;
  end;
  TLocationsList=class(TUITable)
   dialog:TUIFileDialog;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onMouseMove; override;
  end;

 const
  DRIVE_MIN_WIDTH=32;
  LOCATION_ACTION_WIDTH=26;

 function PathIndex(const paths:Strings8;const path:String8):integer; forward;

 procedure DrawPin(const r:TRect;scale:single;remove:boolean;color:cardinal);
 var
  x,y:single;
 begin
  x:=(r.Left+r.Right)*0.5; y:=(r.Top+r.Bottom)*0.5;
  if remove then begin
   draw.Line(x-4*scale,y-4*scale,x+4*scale,y+4*scale,color);
   draw.Line(x-4*scale,y+4*scale,x+4*scale,y-4*scale,color);
  end else begin
   draw.FillRect(round(x-3*scale),round(y-7*scale),round(x+3*scale),round(y-5*scale),color);
   draw.FillRect(round(x-scale),round(y-5*scale),round(x+scale),round(y),color);
   draw.FillTriangle(x-5*scale,y+scale,x+5*scale,y+scale,x,y-3*scale,color,color,color);
   draw.Line(x,y+scale,x,y+7*scale,color);
  end;
 end;

 procedure DrawPinButton(element:TUIElement);
 var
  dialog:TUIFileDialog;
  color:cardinal;
 begin
  DrawDefaultUI(element,false);
  dialog:=TUIFileDialog(element.parent);
  if PathIndex(dialog.favoriteFolders,dialog.Folder)>=0 then color:=$FF244C78
   else color:=element.GetStyleColor('color',$FF303030);
  DrawPin(element.globalRect,element.globalScale,false,color);
 end;

 procedure DrawDriveBar(element:TUIElement);
 var
  bar:TDriveBar;
  r:TRect;
  x,y,s:single;
  color:cardinal;
 begin
  bar:=TDriveBar(element);
  r:=element.globalRect;
  draw.FillRect(r.Left,r.Top,r.Right-1,r.Bottom-1,element.GetStyleColor('fill',$FFBCB8B0));
  if not bar.expanded and (length(bar.children)*DRIVE_MIN_WIDTH>bar.availableWidth) then begin
   s:=element.globalScale;
   x:=r.Right-7*s; y:=(r.Top+r.Bottom)*0.5;
   color:=element.GetStyleColor('color',$FF303030);
   draw.FillTriangle(x-2*s,y-4*s,x-2*s,y+4*s,x+2*s,y,color,color,color);
  end;
 end;

 procedure TDriveBar.Arrange(width:single);
 var
  i,n:integer;
  full,buttonWidth:single;
  clipped:boolean;
 begin
  availableWidth:=width;
  n:=length(children);
  clipped:=n*DRIVE_MIN_WIDTH>width;
  full:=width;
  if clipped and expanded then full:=n*DRIVE_MIN_WIDTH;
  if clipped and not expanded then SetPaddings(0,0,12,0) else SetPadding(0);
  Resize(full,28);
  if n=0 then exit;
  if clipped then buttonWidth:=DRIVE_MIN_WIDTH else buttonWidth:=width/n;
  for i:=0 to n-1 do begin
   children[i].SetPos(i*buttonWidth,0);
   children[i].Resize(buttonWidth-2,26);
  end;
 end;

 procedure TDriveBar.UpdateHover;
 var
  over:boolean;
 begin
  over:=(underMouse=self) or ((underMouse<>nil) and underMouse.HasParent(self));
  if expanded<>over then begin
   expanded:=over;
   Arrange(availableWidth);
  end;
  if expanded then timer:=30 else timer:=0;
 end;

 procedure TDriveBar.onMouseMove;
 begin
  inherited;
  UpdateHover;
 end;

 procedure TDriveBar.onTimer;
 begin
  UpdateHover;
 end;

 procedure TDriveButton.onMouseMove;
 begin
  inherited;
  TDriveBar(parent).UpdateHover;
 end;

 procedure DrawLocations(element:TUIElement);
 var
  list:TLocationsList;
  r,cell,icon:TRect;
  font:TFontHandle;
  s,rowH,pos:single;
  first,place,row,y,baseline:integer;
  tag:NativeInt;
  color,fill:cardinal;
  path,labelText:String8;
  remove,pinned:boolean;
 begin
  list:=TLocationsList(element);
  s:=list.globalScale;
  r:=list.GetClientPosOnScreen;
  font:=list.StyleFont;
  draw.FillRect(r.Left,r.Top,r.Right-1,r.Bottom-1,list.GetStyleColor('fill',$FFD0D0D8));
  draw.Rect(r.Left,r.Top,r.Right-1,r.Bottom-1,list.GetStyleColor('line-color',$FF808080));
  rowH:=list.rowHeight*s;
  pos:=list.ScrollPos*s;
  first:=trunc(pos/rowH);
  remove:=(list.GetWindow.shiftState and sscCtrl)<>0;
  gfx.clip.Rect(r);
  for place:=first to list.RowCount-1 do begin
   y:=r.Top+round(place*rowH-pos);
   if y>=r.Bottom then break;
   row:=list.RowAt(place);
   tag:=list.RowTag(row);
   cell:=Types.Rect(r.Left,y,r.Left+round(list.RowsWidth*s),y+round(rowH));
   fill:=0;
   if row=list.selected then fill:=list.GetStyleColor('selection-fill',$FF707090)
   else if row=list.hoverRow then fill:=list.GetStyleColor('row-hover-fill',$20808080);
   if fill<>0 then draw.FillRect(cell.Left,cell.Top,cell.Right-1,cell.Bottom-1,fill);
   path:=list.dialog.LocationPath(tag);
   if path='' then begin
    labelText:=list.CellText(row,0);
    color:=list.GetStyleColor('color',$FF303030);
   end else begin
    labelText:=Files.GetName(path);
    if labelText='' then labelText:=path else labelText:=labelText+'  '+Files.GetDir(path);
    pinned:=PathIndex(list.dialog.favoriteFolders,path)>=0;
    if tag<$10000 then color:=list.GetStyleColor('favorite-color',$FF244C78)
     else color:=list.GetStyleColor('recent-color',$FF585860);
    icon:=cell;
    icon.Left:=icon.Right-round(LOCATION_ACTION_WIDTH*s);
    if row=list.selected then color:=list.GetStyleColor('selection-color',$FFFFFFFF);
    if pinned or remove then DrawPin(icon,s,remove,color)
     else DrawPin(icon,s,false,list.GetStyleColor('recent-pin-color',$FF929298));
   end;
   baseline:=round((cell.Top+cell.Bottom-1)*0.5+txt.Height(font)*0.45);
   gfx.clip.Rect(Types.Rect(cell.Left+round(5*s),cell.Top,cell.Right-round(LOCATION_ACTION_WIDTH*s),cell.Bottom));
   txt.Write(font,cell.Left+round(5*s),baseline,color,labelText);
   gfx.clip.Restore;
  end;
  gfx.clip.Restore;
 end;

 procedure TLocationsList.onMouseButtons(button:byte;state:boolean);
 var
  p:TVec2;
  row:integer;
 begin
  if (button=1) and state then begin
   p:=TransformFromScreen(Vec2(curMouseX,curMouseY));
   row:=RowAtPoint(p.x,p.y);
   if (row>=0) and (p.x>=RowsWidth-LOCATION_ACTION_WIDTH) and (RowTag(row)>=0) then begin
    dialog.LocationAction(RowTag(row),(GetWindow.shiftState and sscCtrl)<>0);
    exit;
   end;
  end;
  inherited;
 end;

 procedure TLocationsList.onMouseMove;
 begin
  inherited;
  if hoverRow>=0 then hint:=dialog.LocationPath(RowTag(hoverRow)) else hint:='';
 end;
 type
  TDirectoryNode=record
   path:String8;
   depth:integer;
  end;
  // Local tree adapter: one row per visible directory. The disclosure area expands
  // independently of selection; the file table never contains directory rows.
  TDirectoryOutline=class(TUITable)
   dialog:TUIFileDialog;
   nodes:array of TDirectoryNode;
   expanded:Strings8;
   current:String8;
   building:boolean;
   constructor Create(parent:TUIElement;dialog:TUIFileDialog;const name:String8);
   procedure Build(const folder:String8);
   procedure DirectorySelected(sender:TUITable;row:integer);
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure ToggleNode(index:integer);
  end;

 // Temporary private helper until Files supplies a UTF-8 absolute-path API (PaintRaw E-26).
 function FullPath(const path:String8):String8;
 {$IFDEF MSWINDOWS}
 var
  source,buffer:UnicodeString;
  part:PWideChar;
  count,written:cardinal;
 {$ENDIF}
 begin
  {$IFDEF MSWINDOWS}
  source:=UnicodeString(path);
  count:=GetFullPathNameW(PWideChar(source),0,nil,part);
  if count=0 then RaiseLastOSError;
  repeat
   SetLength(buffer,count);
   written:=GetFullPathNameW(PWideChar(source),count,PWideChar(buffer),part);
   if written=0 then RaiseLastOSError;
   if written<count then break;
   count:=written+1;
  until false;
  SetLength(buffer,written);
  result:=String8(buffer);
  {$ELSE}
  result:=String8(ExpandFileName(string(path)));
  {$ENDIF}
 end;

 function JoinPath(const folder,name:String8):String8;
 begin
  result:=folder;
  if (result<>'') and not (result[length(result)] in ['/', '\']) then result:=result+PathDelim;
  result:=result+name;
 end;

 // The dialog browses real files even when the application has installed a VFS provider.
 function NativeFileExists(const path:String8):boolean;
 {$IFDEF MSWINDOWS}
 var
  attr:cardinal;
 {$ENDIF}
 begin
  {$IFDEF MSWINDOWS}
  attr:=GetFileAttributesW(PWideChar(UnicodeString(path)));
  result:=(attr<>INVALID_FILE_ATTRIBUTES) and (attr and FILE_ATTRIBUTE_DIRECTORY=0);
  {$ELSE}
  result:=SysUtils.FileExists(string(path));
  {$ENDIF}
 end;

 function SamePath(const a,b:String8):boolean;
 begin
  {$IFDEF MSWINDOWS}
  result:=UTF8.ToLower(a)=UTF8.ToLower(b);
  {$ELSE}
  result:=a=b;
  {$ENDIF}
 end;

 function PathIndex(const paths:Strings8;const path:String8):integer;
 var
  i:integer;
 begin
  for i:=0 to high(paths) do if SamePath(paths[i],path) then exit(i);
  result:=-1;
 end;

 procedure RemovePath(var paths:Strings8;index:integer);
 var
  i:integer;
 begin
  for i:=index to high(paths)-1 do paths[i]:=paths[i+1];
  SetLength(paths,length(paths)-1);
 end;

 function ParentFolder(const path:String8):String8;
 begin
  result:=FullPath(JoinPath(path,'..'));
 end;

 function FileSizeText(bytes:int64):String8;
 begin
  if bytes<1024 then result:=Conv.ToStr(bytes)+' B'
  else if bytes<1024*1024 then result:=Conv.ToStr(bytes/1024,1)+' KB'
  else if bytes<int64(1024)*1024*1024 then result:=Conv.ToStr(bytes/(1024*1024),1)+' MB'
  else result:=Conv.ToStr(bytes/(int64(1024)*1024*1024),1)+' GB';
 end;

 constructor TDirectoryOutline.Create(parent:TUIElement;dialog:TUIFileDialog;const name:String8);
 begin
  inherited Create(100,100,parent,name);
  self.dialog:=dialog;
  AddColumn('Directory Outline',0,taLeft,tsNone);
  onSelect:=DirectorySelected;
 end;

 procedure TDirectoryOutline.Build(const folder:String8);
 var
  root,p,parentPath:String8;
  selectedRow:integer;
 procedure AddNode(const path:String8;depth:integer);
 var
  listing:TFolderItems;
  names:Strings8;
  labelText,n:String8;
  item:TFolderItem;
  i,j,index,row:integer;
  opened:boolean;
 begin
  index:=length(nodes);
  SetLength(nodes,index+1);
  nodes[index].path:=path;
  nodes[index].depth:=depth;
  opened:=PathIndex(expanded,path)>=0;
  labelText:=Files.GetName(path);
  if labelText='' then labelText:=path;
  if opened then labelText:='- '+labelText else labelText:='+ '+labelText;
  labelText:=String8(StringOfChar(' ',depth*2))+labelText;
  row:=AddRow(index);
  SetCell(row,0,labelText);
  if SamePath(path,folder) then selectedRow:=row;
  if not opened then exit;
  listing:=Apus.Files.Folder.ListItems(path);
  names:=nil;
  for item in listing do
   if item.info.isDirectory and (dialog.showHidden or not item.hidden) then begin
    i:=length(names);
    SetLength(names,i+1);
    names[i]:=item.name;
   end;
  for i:=1 to high(names) do begin
   n:=names[i]; j:=i-1;
   while j>=0 do begin
    if NaturalCompare(UTF8.ToLower(names[j]),UTF8.ToLower(n))<=0 then break;
    names[j+1]:=names[j];
    dec(j);
   end;
   names[j+1]:=n;
  end;
  for n in names do AddNode(JoinPath(path,n),depth+1);
 end;
 begin
  building:=true;
  try
   selectedRow:=-1;
   ClearRows;
   nodes:=nil;
   if folder='' then exit;
   root:=folder;
   // Reveal the route on navigation, but permit collapsing the selected node later.
   p:=folder;
   repeat
    if not SamePath(current,folder) and (PathIndex(expanded,p)<0) then expanded:=expanded+[p];
    root:=p;
    parentPath:=ParentFolder(p);
    if SamePath(parentPath,p) then break;
    p:=parentPath;
   until false;
   current:=folder;
   AddNode(root,0);
   selected:=selectedRow;
  finally
   building:=false;
  end;
 end;

 procedure TDirectoryOutline.DirectorySelected(sender:TUITable;row:integer);
 var
  index:NativeInt;
 begin
  if building or (row<0) then exit;
  index:=RowTag(row);
  if (index>=0) and (index<length(nodes)) then dialog.SetFolder(nodes[index].path);
 end;

 procedure TDirectoryOutline.ToggleNode(index:integer);
 var
  i:integer;
 begin
  if (index<0) or (index>=length(nodes)) then exit;
  i:=PathIndex(expanded,nodes[index].path);
  if i<0 then expanded:=expanded+[nodes[index].path] else RemovePath(expanded,i);
  Build(dialog.Folder);
 end;

 procedure TDirectoryOutline.onMouseButtons(button:byte;state:boolean);
 var
  p:TVec2;
  row,index:integer;
 begin
  if (button=1) and state then begin
   p:=TransformFromScreen(Vec2(curMouseX,curMouseY));
   row:=RowAtPoint(p.x,p.y);
   if row>=0 then begin
    index:=RowTag(row);
    if (index>=0) and (index<length(nodes)) and (p.x<20+nodes[index].depth*8) then begin
     ToggleNode(index);
     exit;
    end;
   end;
  end;
  inherited;
 end;

 procedure TDialogButton.DoClick;
 begin
  inherited;
  if Assigned(handler) then handler;
 end;

 function TDialogEdit.onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean;
 var
  old:String8;
 begin
  if pressed and (TKey(keycode)=TKey.Enter) and (shiftstate=0) then begin
   if isPath then dialog.PathEntered else dialog.Confirm;
   exit(false);
  end;
  old:=text;
  result:=inherited onKey(keycode,pressed,shiftstate);
  if text<>old then dialog.Edited;
 end;

 procedure TDialogEdit.onUniChar(ch:Char32;scancode:byte);
 begin
  inherited;
  dialog.Edited;
 end;

 procedure TTypeChip.DoClick;
 begin
  inherited;
  if dialog<>nil then dialog.TypeClicked(index,toggled);
 end;

 constructor TUIFileDialog.Create(width,height:single;parent:TUIElement;name:String8);
 begin
  inherited;
  shape:=shapeFull;
  finished:=true;
  CreateControls;
  LayoutControls;
 end;

 procedure TUIFileDialog.CreateControls;
 function Button(const suffix,caption:String8;handler:TObjProcedure):TUIButton;
 var
  b:TDialogButton;
 begin
  b:=TDialogButton.Create(88,28,self,name+'\'+suffix);
  b.Setup(caption);
  b.handler:=handler;
  result:=b;
 end;
 function Edit(const suffix:String8;isPath:boolean):TUIEditBox;
 var
  e:TDialogEdit;
 begin
  e:=TDialogEdit.Create(100,28,self,name+'\'+suffix);
  e.dialog:=self;
  e.isPath:=isPath;
  e.maxlength:=32767;
  result:=e;
 end;
 begin
  pathEdit:=Edit('Path',true);
  upButton:=Button('Up','Up',GoUp);
  table:=TUITable.Create(100,100,self,name+'\Table');
  table.AddColumn('Name',0);
  table.AddColumn('Size',90,taRight,tsKey);
  table.AddColumn('Modified',150,taLeft,tsKey);
  table.SortBy(0);
  table.onSelect:=RowSelected;
  table.onActivate:=RowActivated;
  nameLabel:=TUILabel.Create(60,28,self).Setup('Name:');
  nameEdit:=Edit('Name',false);
  typeBar:=TUIElement.Create(100,28,self,name+'\Types');
  messageLabel:=TUILabel.Create(100,24,self,name+'\Message');
  acceptButton:=Button('Accept','Open',Confirm);
  acceptButton.default:=true;
  cancelButton:=Button('Cancel','Cancel',Cancel);
  placesPanel:=TUIElement.Create(0,0,self,name+'\Places');
  previewPanel:=TUIElement.Create(0,0,self,name+'\Preview');
  optionsPanel:=TUIElement.Create(0,0,self,name+'\Options');
  navigationPanel:=TUIElement.Create(340,100,self,name+'\Navigation');
  navigationPanel.order:=10;
  driveBar:=TDriveBar.Create(340,28,navigationPanel,name+'\Drives');
  driveBar.shape:=shapeFull;
  driveBar.flags.noParentClip:=true;
  driveBar.order:=$10000;
  driveBar.drawer:=DrawDriveBar;
  directoryOutline:=TDirectoryOutline.Create(navigationPanel,self,name+'\Directories');
  locationsList:=TLocationsList.Create(340,120,navigationPanel,name+'\Locations');
  TLocationsList(locationsList).dialog:=self;
  locationsList.drawer:=DrawLocations;
  locationsList.AddColumn('',0,taLeft,tsNone);
  locationsList.headerHeight:=0;
  locationsList.onSelect:=LocationSelected;
  pinButton:=Button('PinFolder','',PinFolder);
  pinButton.drawer:=DrawPinButton;
  pinButton.hint:='Pin current folder';
 end;

 procedure TUIFileDialog.LayoutControls;
 var
  w,h,left,right,bottom,navH,navW,locationsH,chipWidth:single;
  i:integer;
 procedure Place(e:TUIElement;x,y,w,h:single);
 begin
  e.SetPos(x,y);
  e.Resize(Math.Max(0.0,w),Math.Max(0.0,h));
 end;
 begin
  if table=nil then exit;
  w:=clientWidth; h:=clientHeight;
  navW:=Math.Min(340.0,w*0.42);
  navH:=Math.Max(0.0,h-16);
  Place(navigationPanel,8,8,navW,navH);
  driveBar.SetPos(0,0);
  TDriveBar(driveBar).Arrange(navW);
  locationsH:=Math.Min(160.0,navH*0.30);
  Place(directoryOutline,0,36,navW,navH-locationsH-44);
  Place(locationsList,0,navH-locationsH,navW,locationsH);
  left:=navW+24; right:=w-8; bottom:=h-104;
  Place(pathEdit,left,8,right-left-112,28);
  Place(upButton,right-104,8,68,28);
  Place(pinButton,right-28,8,28,28);
  Place(typeBar,left,44,right-left,28);
  if allTypeButton<>nil then begin
   chipWidth:=(right-left)/(length(typeButtons)+1);
   Place(allTypeButton,0,0,chipWidth-4,28);
   for i:=0 to high(typeButtons) do Place(typeButtons[i],(i+1)*chipWidth,0,chipWidth-4,28);
  end;
  // An unused slot occupies no space. Apps choose slot widths/heights when filling them.
  if length(placesPanel.children)>0 then begin
   Place(placesPanel,left,80,placesPanel.size.x,bottom-80);
   left:=left+placesPanel.size.x+8;
  end;
  if length(previewPanel.children)>0 then begin
   right:=right-previewPanel.size.x-8;
   Place(previewPanel,right+8,80,previewPanel.size.x,bottom-80);
  end;
  if length(optionsPanel.children)>0 then begin
   Place(optionsPanel,left,bottom-optionsPanel.size.y,right-left,optionsPanel.size.y);
   bottom:=bottom-optionsPanel.size.y-8;
  end;
  Place(table,left,80,right-left,bottom-80);
  Place(nameLabel,left,h-96,60,28);
  Place(nameEdit,left+60,h-96,right-left-60,28);
  Place(messageLabel,left,h-62,right-left,24);
  Place(acceptButton,w-192,h-36,88,28);
  Place(cancelButton,w-96,h-36,88,28);
 end;

 procedure TUIFileDialog.Resize(newWidth,newHeight:single);
 begin
  inherited;
  LayoutControls;
 end;

 procedure TUIFileDialog.Setup(mode:TFileDialogMode;const folder,fileName:String8;typeIndex:integer);
 begin
  self.mode:=mode;
  // Scenes may be constructed by the application thread. UI hotkeys belong to the
  // window thread, where Setup and input run, rather than to that constructor's thread.
  SetHotKey(ord(TKey.Escape));
  table.keyScope:=self;
  finished:=false;
  Edited;
  if length(types)>0 then selectedType:=Clamp(typeIndex,0,length(types)-1) else selectedType:=-1;
  allTypes:=true;
  activeTypes:=nil;
  SetLength(activeTypes,length(types));
  BuildTypes;
  if mode=fdOpen then acceptButton.caption:='Open' else acceptButton.caption:='Save';
  nameEdit.text:=fileName;
  BuildDrives;
  if folder='' then SetFolder('') else SetFolder(FullPath(folder));
  LayoutControls;
 end;

 procedure TUIFileDialog.ShowError(const message:String8);
 begin
  messageLabel.caption:=message;
 end;

 procedure TUIFileDialog.Edited;
 begin
  overwritePath:='';
  ShowError('');
 end;

 function TUIFileDialog.Folder:String8;
 begin
  result:=fFolder;
 end;

 procedure TUIFileDialog.SetFolder(const path:String8);
 var
  next:String8;
 begin
  try
   next:=path;
   if next<>'' then begin
    if Files.IsPathRelative(next) and (fFolder<>'') then next:=JoinPath(fFolder,next);
    next:=FullPath(JoinPath(next,'.'));
    if not Apus.Files.Folder.Exists(next) then begin
     ShowError('Folder not found: '+next);
     exit;
    end;
   end;
   fFolder:=next;
   pathEdit.text:=fFolder;
   Edited;
   Refresh;
   TDirectoryOutline(directoryOutline).Build(fFolder);
   RememberFolder;
   BuildLocations;
  except
   on e:Exception do ShowError(String8(e.Message));
  end;
 end;

 procedure TUIFileDialog.Refresh;
 var
  mask:String8;
  i,row:integer;
 begin
  table.ClearRows;
  if fFolder='' then begin
   items:=nil;
  end else begin
   mask:='';
   if allTypes then mask:='*'
   else for i:=0 to high(activeTypes) do if activeTypes[i] then begin
    if mask<>'' then mask:=mask+';';
    mask:=mask+types[i].masks;
   end;
   if mask='' then begin
    items:=nil;
    ShowError('No file types selected');
    exit;
   end;
   items:=Apus.Files.Folder.ListItems(fFolder,mask);
   for i:=0 to high(items) do with items[i] do begin
    if info.isDirectory then continue;
    if hidden and not showHidden then continue;
    row:=table.AddRow(i);
    table.SetCell(row,0,name);
    table.SetCell(row,1,FileSizeText(info.size),info.size);
    table.SetCell(row,2,String8(FormatDateTime('yyyy-mm-dd hh:nn',info.timestamp)),info.timestamp);
   end;
   ShowError('Files: '+Conv.ToStr(table.RowCount));
  end;
 end;

 procedure TUIFileDialog.BuildTypes;
 var
  b:TTypeChip;
  i:integer;
  caption:String8;
 begin
  typeBar.DeleteChildren;
  typeButtons:=nil;
  b:=TTypeChip.Create(48,28,typeBar,name+'\TypeAll');
  b.Setup('All',allTypes);
  b.dialog:=self; b.index:=-1;
  b.flags.canHaveFocus:=false;
  b.hint:='All files. Ctrl+click changes only this filter.';
  allTypeButton:=b;
  SetLength(typeButtons,length(types));
  for i:=0 to high(types) do begin
   caption:=types[i].ext;
   if caption<>'' then caption:=UTF8.ToUpper(copy(caption,2,length(caption))) else caption:=types[i].title;
   b:=TTypeChip.Create(48,28,typeBar,name+'\Type'+Conv.ToStr(i));
   b.Setup(caption,activeTypes[i]);
   b.dialog:=self; b.index:=i;
   b.flags.canHaveFocus:=false;
   b.hint:=types[i].title+' ('+types[i].masks+'). Ctrl+click changes only this filter.';
   typeButtons[i]:=b;
  end;
 end;

 procedure TUIFileDialog.UpdateTypes;
 var
  i:integer;
 begin
  allTypeButton.toggled:=allTypes;
  for i:=0 to high(typeButtons) do typeButtons[i].toggled:=activeTypes[i];
 end;

 procedure TUIFileDialog.TypeClicked(index:integer;active:boolean);
 var
  i:integer;
 begin
  if (GetWindow.shiftState and sscCtrl)=0 then begin
   allTypes:=false;
   for i:=0 to high(activeTypes) do activeTypes[i]:=false;
  end;
  if index<0 then allTypes:=active else begin
   activeTypes[index]:=active;
   if active then selectedType:=index;
  end;
  UpdateTypes;
  Edited;
  Refresh;
 end;

 procedure TUIFileDialog.BuildDrives;
 var
  roots:Strings8;
  i:integer;
  b:TDriveButton;
 begin
  driveBar.DeleteChildren;
  TDriveBar(driveBar).expanded:=false;
  roots:=Apus.Files.Folder.Roots;
  for i:=0 to high(roots) do begin
   b:=TDriveButton.Create(32,24,driveBar,name+'\Drive'+Conv.ToStr(i));
   b.caption:=roots[i];
   b.attributes.Item['path']:=JoinPath(roots[i],'');
   b.handler:=DriveClicked;
  end;
 end;

 procedure TUIFileDialog.DriveClicked;
 begin
  SetFolder(TUIButton.Sender.attributes.Item['path']);
 end;

 procedure TUIFileDialog.RememberFolder;
 var
  index,i:integer;
 begin
  if fFolder='' then exit;
  index:=PathIndex(recentFolders,fFolder);
  if index=0 then exit;
  if index>=0 then RemovePath(recentFolders,index);
  SetLength(recentFolders,Math.Min(12,length(recentFolders)+1));
  for i:=high(recentFolders) downto 1 do recentFolders[i]:=recentFolders[i-1];
  recentFolders[0]:=fFolder;
  if Assigned(onLocationsChanged) then onLocationsChanged;
 end;

 procedure TUIFileDialog.BuildLocations;
 var
  i:integer;
 begin
  locationsList.ClearRows;
  locationsList.SetCell(locationsList.AddRow(-1),0,'Favorites');
  for i:=0 to high(favoriteFolders) do
   locationsList.SetCell(locationsList.AddRow(i),0,favoriteFolders[i]);
  locationsList.SetCell(locationsList.AddRow(-1),0,'Recent');
  for i:=0 to high(recentFolders) do
   locationsList.SetCell(locationsList.AddRow($10000+i),0,recentFolders[i]);
  pinButton.flags.enabled:=fFolder<>'';
  if PathIndex(favoriteFolders,fFolder)>=0 then pinButton.hint:='Unpin current folder'
   else pinButton.hint:='Pin current folder';
 end;

 function TUIFileDialog.LocationPath(tag:NativeInt):String8;
 begin
  result:='';
  if tag<0 then exit;
  if tag>=$10000 then begin
   tag:=tag-$10000;
   if tag<length(recentFolders) then result:=recentFolders[tag];
  end else if tag<length(favoriteFolders) then result:=favoriteFolders[tag];
 end;

 procedure TUIFileDialog.LocationAction(tag:NativeInt;remove:boolean);
 var
  path:String8;
  index:integer;
 begin
  path:=LocationPath(tag);
  if path='' then exit;
  if remove then begin
   if tag>=$10000 then RemovePath(recentFolders,tag-$10000)
    else RemovePath(favoriteFolders,tag);
  end else begin
   index:=PathIndex(favoriteFolders,path);
   if index<0 then favoriteFolders:=favoriteFolders+[path]
    else RemovePath(favoriteFolders,index);
  end;
  BuildLocations;
  if Assigned(onLocationsChanged) then onLocationsChanged;
 end;

 procedure TUIFileDialog.LocationSelected(sender:TUITable;row:integer);
 var
  index:NativeInt;
  path:String8;
 begin
  if row<0 then exit;
  index:=sender.RowTag(row);
  if index<0 then exit;
  if index>=$10000 then begin
   index:=index-$10000;
   if index>=length(recentFolders) then exit;
   path:=recentFolders[index];
  end else begin
   if index>=length(favoriteFolders) then exit;
   path:=favoriteFolders[index];
  end;
  SetFolder(path);
 end;

 procedure TUIFileDialog.PinFolder;
 var
  index:integer;
 begin
  if fFolder='' then exit;
  index:=PathIndex(favoriteFolders,fFolder);
  if index<0 then favoriteFolders:=favoriteFolders+[fFolder]
   else RemovePath(favoriteFolders,index);
  BuildLocations;
  if Assigned(onLocationsChanged) then onLocationsChanged;
 end;

 procedure TUIFileDialog.GoUp;
 var
  parent:String8;
 begin
  if fFolder='' then exit;
  parent:=FullPath(JoinPath(fFolder,'..'));
  if parent=fFolder then parent:='';
  SetFolder(parent);
 end;

 procedure TUIFileDialog.PathEntered;
 begin
  SetFolder(pathEdit.text);
 end;

 function TUIFileDialog.ItemPath(index:integer):String8;
 begin
  if fFolder='' then result:=items[index].name else result:=JoinPath(fFolder,items[index].name);
 end;

 procedure TUIFileDialog.RowSelected(sender:TUITable;row:integer);
 var
  index:NativeInt;
  path:String8;
 begin
  Edited;
  path:='';
  if row>=0 then begin
   index:=table.RowTag(row);
   if (index>=0) and (index<length(items)) and not items[index].info.isDirectory then begin
    nameEdit.text:=items[index].name;
    path:=ItemPath(index);
   end;
  end;
  if Assigned(onSelect) then onSelect(self,path);
 end;

 procedure TUIFileDialog.RowActivated(sender:TUITable;row:integer);
 var
  index:NativeInt;
 begin
  index:=table.RowTag(row);
  if index<0 then GoUp
  else if index<length(items) then begin
   if items[index].info.isDirectory then SetFolder(ItemPath(index))
   else begin
    nameEdit.text:=items[index].name;
    Confirm;
   end;
  end;
 end;

 procedure TUIFileDialog.Confirm;
 var
  value:TFileDialogResult;
  path,ext:String8;
  exists:boolean;
 begin
  if finished then exit;
  try
   path:=nameEdit.text;
   if path='' then begin ShowError('Enter a file name'); exit; end;
   if Files.IsPathRelative(path) then begin
    if fFolder='' then begin ShowError('Choose a folder first'); exit; end;
    path:=JoinPath(fFolder,path);
   end;
   path:=FullPath(path);
   if Apus.Files.Folder.Exists(path) then begin
    SetFolder(path);
    nameEdit.text:='';
    exit;
   end;
   value.typeIndex:=selectedType;
   if (mode=fdSave) and (Files.GetExt(path)='') and
      (value.typeIndex>=0) and (value.typeIndex<length(types)) then begin
    ext:=types[value.typeIndex].ext;
    if (ext<>'') and (ext[1]<>'.') then ext:='.'+ext;
    path:=path+ext;
   end;
   if Apus.Files.Folder.Exists(path) then begin ShowError('The name belongs to a folder'); exit; end;
   exists:=NativeFileExists(path);
   if (mode=fdOpen) and not exists then begin ShowError('File not found: '+path); exit; end;
   if not Apus.Files.Folder.Exists(Files.GetDir(path)) then begin
    ShowError('Destination folder not found'); exit;
   end;
   if (mode=fdSave) and exists and (overwritePath<>path) then begin
    overwritePath:=path;
    ShowError('File exists. Press Save again to replace it.');
    exit;
   end;
   value.accepted:=true;
   value.path:=path;
   if Assigned(onValidate) and not onValidate(self,value) then exit;
   Finish(value);
  except
   on e:Exception do ShowError(String8(e.Message));
  end;
 end;

 procedure TUIFileDialog.Cancel;
 var
  value:TFileDialogResult;
 begin
  value.accepted:=false;
  value.path:='';
  value.typeIndex:=selectedType;
  Finish(value);
 end;

 procedure TUIFileDialog.Finish(const value:TFileDialogResult);
 begin
  if finished then exit;
  finished:=true;
  if host<>nil then host.Close;
  Signal('UI\'+name+'\Done',ord(value.accepted));
  if Assigned(onDone) then onDone(self,value);
 end;

 function TUIFileDialog.onHotKey(keycode:byte;shiftstate:byte):boolean;
 begin
  result:=(TKey(keycode)=TKey.Escape) and (shiftstate=0);
  if result then Cancel;
 end;

 constructor TFileDialogScene.Create(const sceneName:String8;wnd:TWindow);
 begin
  inherited Create(string(sceneName)+'Scene',false,wnd);
  zOrder:=100;
  UI.order:=zOrder;
  frame:=TUIWindow.Create(1100,580,true,UI,sceneName+'\Frame','Open');
  frame.minW:=680; frame.minH:=420;
  dialog:=TUIFileDialog.Create(frame.clientWidth,frame.clientHeight,frame,sceneName);
  dialog.SetAnchors(anchorAll);
  dialog.host:=self;
  onCreate;
 end;

 destructor TFileDialogScene.Destroy;
 begin
  if prevFocus<>nil then prevFocus.Release;
  inherited;
 end;

 procedure TFileDialogScene.onResize;
 begin
  inherited;
  if frame=nil then exit;
  frame.Resize(Math.Min(1116.0,UI.clientWidth-16),Math.Min(610.0,UI.clientHeight-16));
  frame.Center;
  dialog.LayoutControls;
 end;

 procedure TFileDialogScene.Open(modal:boolean);
 var
  f:TUIElement;
 begin
  if IsActive then exit;
  onResize;
  if dialog.mode=fdOpen then frame.caption:='Open' else frame.caption:='Save As';
  f:=FocusedElement;
  if (f<>nil) and f.Acquire then prevFocus:=f;
  // Immediate show/hide keeps completion deterministic and permits opening another dialog
  // from onDone. Effects still own modal-stack and input-lock handling.
  if modal then TShowWindowEffect.Create(self,0,sweShowModal,0)
   else TShowWindowEffect.Create(self,0,sweShow,0);
  FreeAndNil(effect);
  dialog.nameEdit.SetFocus;
  dialog.nameEdit.SelectAll;
 end;

 procedure TFileDialogScene.Close;
 var
  f:TUIElement;
 begin
  TShowWindowEffect.Create(self,0,sweHide,0);
  FreeAndNil(effect);
  f:=prevFocus;
  prevFocus:=nil;
  if f<>nil then begin
   if not f.deleted and f.IsVisible and f.IsEnabled then f.SetFocus;
   f.Release;
  end;
 end;

end.
