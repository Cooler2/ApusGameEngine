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
  // Semantic colors only; layout and hit areas do not depend on the palette.
  TFileDialogPalette=record
   background,surface,header,border,text,muted,disabled:cardinal;
   hover,selection,selectionText,accent:cardinal;
   badgeFill,badgeBorder,badgeInk,favoriteInk,removeInk:cardinal;
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
   palette:TFileDialogPalette;
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
   procedure ApplyPalette; // also applied to controls created by Setup
   function onHotKey(keycode:byte;shiftstate:byte):boolean; override;
   procedure Resize(newWidth,newHeight:single); override;
  protected
   pathEdit,nameEdit,filterEdit:TUIEditBox;
   typeBar:TUIElement;
   allTypeButton:TUIToggleButton;
   typeButtons:array of TUIToggleButton;
   upButton,acceptButton,cancelButton:TUIButton;
   nameLabel,messageLabel:TUILabel;
   navigationPanel,driveBar:TUIElement;
   directoryOutline,locationsList:TUITable;
   pinButton:TUIButton;
   filterClearButton:TUIButton;
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
   procedure Refresh(reload:boolean=true);
   procedure FilterChanged;
   procedure ClearFilter;
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
   isFilter:boolean;
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

 type
  TBadgeKind=(bkAddFavorite,bkFavorite,bkRemove,bkExpand,bkCollapse,bkClear);

 function DefaultPalette:TFileDialogPalette;
 begin
  result.background:=$FFE4E6E9; result.surface:=$FFF1F3F5; result.header:=$FFDCE1E6;
  result.border:=$FFABB3BD; result.text:=$FF303B48; result.muted:=$FF667584;
  result.disabled:=$FF939CA5; result.hover:=$FFD2DFEB; result.selection:=$FF356FA3;
  result.selectionText:=$FFFFFFFF; result.accent:=$FF527DA5;
  result.badgeFill:=$FFE2E7ED; result.badgeBorder:=$FFA0ADBA; result.badgeInk:=$FF61758A;
  result.favoriteInk:=$FF977836; result.removeInk:=$FFA96069;
 end;

 function PaletteOf(element:TUIElement):TFileDialogPalette;
 begin
  while element<>nil do begin
   if element is TUIFileDialog then exit(TUIFileDialog(element).palette);
   element:=element.parent;
  end;
  result:=DefaultPalette;
 end;

 procedure ThickLine(x1,y1,x2,y2,width:single;color:cardinal);
 var
  dx,dy,len:single;
 begin
  len:=sqrt(sqr(x2-x1)+sqr(y2-y1));
  if len=0 then exit;
  dx:=-(y2-y1)*width/(2*len); dy:=(x2-x1)*width/(2*len);
  draw.FillTriangle(x1+dx,y1+dy,x1-dx,y1-dy,x2+dx,y2+dy,color,color,color);
  draw.FillTriangle(x1-dx,y1-dy,x2-dx,y2-dy,x2+dx,y2+dy,color,color,color);
 end;

 procedure DrawBadge(element:TUIElement;const r:TRect;scale:single;kind:TBadgeKind;enabled:boolean=true);
 var
  x,y,radius,a,d:single;
  points:array[0..9] of TVec2;
  i,j:integer;
  fill,ink:cardinal;
  p:TFileDialogPalette;
 begin
  x:=(r.Left+r.Right)*0.5; y:=(r.Top+r.Bottom)*0.5;
  radius:=Math.Min(10*scale,(r.Bottom-r.Top-2*scale)*0.5);
  p:=PaletteOf(element);
  fill:=p.badgeFill; ink:=p.badgeInk;
  if kind=bkFavorite then ink:=p.favoriteInk else if kind=bkRemove then ink:=p.removeInk;
  if not enabled then ink:=p.disabled;
  draw.RoundRect(x-radius,y-radius,x+radius,y+radius,radius,scale,p.badgeBorder,fill);
  case kind of
   bkRemove,bkClear:begin
    ThickLine(x-3.4*scale,y-3.4*scale,x+3.4*scale,y+3.4*scale,1.5*scale,ink);
    ThickLine(x-3.4*scale,y+3.4*scale,x+3.4*scale,y-3.4*scale,1.5*scale,ink);
   end;
   bkExpand,bkCollapse:begin
    ThickLine(x-4*scale,y,x+4*scale,y,1.5*scale,ink);
    if kind=bkExpand then ThickLine(x,y-4*scale,x,y+4*scale,1.5*scale,ink);
   end;
   else begin
    for i:=0 to 9 do begin
     a:=-Pi/2+i*Pi/5;
     if odd(i) then d:=2.5*scale else d:=5.8*scale;
     points[i]:=Vec2(x+cos(a)*d,y+sin(a)*d);
    end;
    for i:=0 to 9 do begin
     j:=(i+1) mod 10;
     if kind=bkFavorite then
      draw.FillTriangle(x,y,points[i].x,points[i].y,points[j].x,points[j].y,ink,ink,ink)
     else ThickLine(points[i].x,points[i].y,points[j].x,points[j].y,1.1*scale,ink);
    end;
   end;
  end;
 end;

 procedure DrawPinButton(element:TUIElement);
 var
  dialog:TUIFileDialog;
  kind:TBadgeKind;
 begin
  dialog:=TUIFileDialog(element.parent);
  if PathIndex(dialog.favoriteFolders,dialog.Folder)>=0 then kind:=bkFavorite else kind:=bkAddFavorite;
  DrawBadge(element,element.globalRect,element.globalScale,kind,element.IsEnabled);
 end;

 procedure DrawClearFilter(element:TUIElement);
 begin
  DrawBadge(element,element.globalRect,element.globalScale,bkClear,element.IsEnabled);
 end;

 procedure DrawDialogButton(element:TUIElement);
 var
  b:TUIButton;
  p:TFileDialogPalette;
  r:TRect;
  fill,ink,border:cardinal;
  font:TFontHandle;
  toggled:boolean;
 begin
  b:=TUIButton(element); p:=PaletteOf(element); r:=element.globalRect;
  toggled:=(b is TUIToggleButton) and TUIToggleButton(b).toggled;
  fill:=p.header; ink:=p.text; border:=p.border;
  if toggled or b.pressed then fill:=p.selection else if b.IsHovered then fill:=p.hover;
  if toggled then ink:=p.selectionText;
  if b.default or (FocusedElement=b) then border:=p.accent;
  if not b.IsEnabled then ink:=p.disabled;
  draw.RoundRect(r.Left,r.Top,r.Right-1,r.Bottom-1,3*element.globalScale,element.globalScale,border,fill);
  font:=element.StyleFont;
  txt.Write(font,(r.Left+r.Right)*0.5,round((r.Top+r.Bottom-1)*0.5+txt.Height(font)*0.45),ink,b.caption,taCenter);
 end;

 procedure DrawDialogFrame(element:TUIElement);
 var
  frame:TUIWindow;
  p:TFileDialogPalette;
  r,client:TRect;
  font:TFontHandle;
 begin
  frame:=TUIWindow(element);
  p:=TFileDialogScene(frame.GetScene).dialog.palette;
  r:=frame.globalRect; client:=frame.GetClientPosOnScreen;
  draw.FillRect(r.Left,r.Top,r.Right-1,r.Bottom-1,p.background);
  draw.FillRect(r.Left,r.Top,r.Right-1,client.Top-1,p.header);
  draw.Rect(r.Left,r.Top,r.Right-1,r.Bottom-1,p.border);
  font:=frame.StyleFont;
  txt.Write(font,(r.Left+r.Right)*0.5,round((r.Top+client.Top-1)*0.5+txt.Height(font)*0.45),p.text,frame.caption,taCenter);
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

 // Preserve the root and as much of the tail as fits; only separator boundaries
 // are cut first. The fallback removes whole Unicode characters from a long leaf.
 function PathCaption(font:TFontHandle;const path:String8;width:single):String8;
 var
  root,tail,prefix,candidate:String8;
  chars:String32;
  i,j,rootLen,lo,hi,mid:integer;
 begin
  if width<=0 then exit('');
  if txt.Width(font,path)<=width then exit(path);
  rootLen:=0;
  if (length(path)>=3) and (path[2]=':') then rootLen:=3
  else if (length(path)>=2) and (path[1] in ['/','\']) and (path[2]=path[1]) then begin
   i:=3;
   for j:=1 to 2 do begin
    while (i<=length(path)) and not (path[i] in ['/','\']) do inc(i);
    rootLen:=Math.Min(i,length(path));
    inc(i);
   end;
  end else if (path<>'') and (path[1] in ['/','\']) then rootLen:=1;
  root:=copy(path,1,rootLen);
  prefix:=root+'...'+PathDelim;
  for i:=rootLen+1 to length(path) do if path[i] in ['/','\'] then begin
   candidate:=prefix+copy(path,i+1,length(path));
   if txt.Width(font,candidate)<=width then exit(candidate);
  end;
  if txt.Width(font,prefix)>width then begin
   if txt.Width(font,'...')<=width then exit('...') else exit('');
  end;
  tail:=Files.GetName(path);
  chars:=UTF8.Decode(tail);
  lo:=0; hi:=length(chars);
  while lo<hi do begin
   mid:=(lo+hi) div 2;
   candidate:=prefix+UTF8.Encode(copy(chars,mid,length(chars)-mid));
   if txt.Width(font,candidate)<=width then hi:=mid else lo:=mid+1;
  end;
  result:=prefix+UTF8.Encode(copy(chars,lo,length(chars)-lo));
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
   if row=list.selected then fill:=list.GetStyleColor('selection-fill',$FF356FA3)
   else if row=list.hoverRow then fill:=list.GetStyleColor('row-hover-fill',$FF99B5CF);
   if fill<>0 then draw.FillRect(cell.Left,cell.Top,cell.Right-1,cell.Bottom-1,fill);
   path:=list.dialog.LocationPath(tag);
   if path='' then begin
    labelText:=list.CellText(row,0);
    color:=list.GetStyleColor('color',$FF303030);
   end else begin
    labelText:=PathCaption(font,path,cell.Right-cell.Left-(LOCATION_ACTION_WIDTH+10)*s);
    pinned:=PathIndex(list.dialog.favoriteFolders,path)>=0;
    if tag<$10000 then color:=list.GetStyleColor('favorite-color',$FF244C78)
     else color:=list.GetStyleColor('recent-color',$FF585860);
    icon:=cell;
    icon.Left:=icon.Right-round(LOCATION_ACTION_WIDTH*s);
    if row=list.selected then color:=list.GetStyleColor('selection-color',$FFFFFFFF);
    if remove then DrawBadge(list,icon,s,bkRemove)
    else if pinned then DrawBadge(list,icon,s,bkFavorite)
     else DrawBadge(list,icon,s,bkAddFavorite);
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
   building,selecting:boolean;
   constructor Create(parent:TUIElement;dialog:TUIFileDialog;const name:String8);
   procedure Build(const folder:String8);
   procedure DirectorySelected(sender:TUITable;row:integer);
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onMouseMove; override;
   procedure ToggleNode(index:integer);
  end;

 procedure DrawDirectoryOutline(element:TUIElement);
 var
  table:TDirectoryOutline;
  r,cell,badge:TRect;
  font:TFontHandle;
  s,rowH,pos:single;
  first,place,row,index,y,headerBottom,baseline,textLeft:integer;
  color,fill:cardinal;
  kind:TBadgeKind;
 begin
  table:=TDirectoryOutline(element);
  r:=table.GetClientPosOnScreen;
  s:=table.globalScale;
  font:=table.StyleFont;
  headerBottom:=r.Top+round(table.headerHeight*s);
  draw.FillRect(r.Left,r.Top,r.Right-1,r.Bottom-1,table.GetStyleColor('fill',$FFD0D0D8));
  gfx.clip.Rect(Types.Rect(r.Left,headerBottom,r.Right,r.Bottom));
  rowH:=table.rowHeight*s;
  pos:=table.ScrollPos*s;
  first:=trunc(pos/rowH);
  for place:=first to table.RowCount-1 do begin
   y:=headerBottom+round(place*rowH-pos);
   if y>=r.Bottom then break;
   row:=table.RowAt(place);
   index:=table.RowTag(row);
   if (index<0) or (index>=length(table.nodes)) then continue;
   cell:=Types.Rect(r.Left,y,r.Left+round(table.RowsWidth*s),y+round(rowH));
   fill:=0;
   color:=table.GetStyleColor('color',$FF303030);
   if row=table.selected then begin
    fill:=table.GetStyleColor('selection-fill',$FF356FA3);
    color:=table.GetStyleColor('selection-color',$FFFFFFFF);
   end else if row=table.hoverRow then fill:=table.GetStyleColor('row-hover-fill',$FF99B5CF)
   else if odd(place) then fill:=table.GetStyleColor('row-alt-fill',0);
   if fill<>0 then draw.FillRect(cell.Left,cell.Top,cell.Right-1,cell.Bottom-1,fill);
   badge:=cell;
   badge.Left:=cell.Left+round((4+table.nodes[index].depth*14)*s);
   badge.Right:=badge.Left+round(20*s);
   if PathIndex(table.expanded,table.nodes[index].path)>=0 then kind:=bkCollapse else kind:=bkExpand;
   DrawBadge(table,badge,s,kind);
   textLeft:=badge.Right+round(5*s);
   baseline:=round((cell.Top+cell.Bottom-1)*0.5+txt.Height(font)*0.45);
   if textLeft<cell.Right-round(5*s) then begin
    gfx.clip.Rect(Types.Rect(textLeft,cell.Top,cell.Right-round(5*s),cell.Bottom));
    txt.Write(font,textLeft,baseline,color,table.CellText(row,0));
    gfx.clip.Restore;
   end;
  end;
  gfx.clip.Restore;
  draw.Rect(r.Left,r.Top,r.Right-1,r.Bottom-1,table.GetStyleColor('line-color',$FF808080));
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
  AddColumn('',0,taLeft,tsNone);
  headerHeight:=0;
  onSelect:=DirectorySelected;
  drawer:=DrawDirectoryOutline;
 end;

 procedure TDirectoryOutline.Build(const folder:String8);
 var
  root,p,parentPath,anchor:String8;
  selectedRow,topRow,index,i:integer;
  oldPos,offset:single;
  keepView:boolean;
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
  keepView:=selecting or SamePath(current,folder);
  oldPos:=ScrollPos;
  offset:=Frac(oldPos/rowHeight)*rowHeight;
  anchor:='';
  topRow:=RowAt(trunc(oldPos/rowHeight));
  if topRow>=0 then begin
   index:=RowTag(topRow);
   if (index>=0) and (index<length(nodes)) then anchor:=nodes[index].path;
  end;
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
   if keepView then begin
    for i:=0 to high(nodes) do if SamePath(nodes[i].path,anchor) then begin
     oldPos:=PlaceOf(i)*rowHeight+offset;
     break;
    end;
    scrollerV.SetValue(oldPos);
   end;
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
  if (index<0) or (index>=length(nodes)) then exit;
  selecting:=true;
  try
   dialog.SetFolder(nodes[index].path);
  finally
   selecting:=false;
  end;
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
    if (index>=0) and (index<length(nodes)) and
       (p.x>=4+nodes[index].depth*14) and (p.x<24+nodes[index].depth*14) then begin
     ToggleNode(index);
     exit;
    end;
   end;
  end;
  inherited;
 end;

 procedure TDirectoryOutline.onMouseMove;
 var
  index:NativeInt;
 begin
  inherited;
  hint:='';
  if hoverRow<0 then exit;
  index:=RowTag(hoverRow);
  if (index>=0) and (index<length(nodes)) then hint:=nodes[index].path;
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
   if isPath then dialog.PathEntered
   else if isFilter then begin
    dialog.table.SetFocus;
    dialog.table.selected:=dialog.table.RowAt(0);
   end else dialog.Confirm;
   exit(false);
  end;
  old:=text;
  result:=inherited onKey(keycode,pressed,shiftstate);
  if text<>old then
   if isFilter then dialog.FilterChanged else dialog.Edited;
 end;

 procedure TDialogEdit.onUniChar(ch:Char32;scancode:byte);
 var
  old:String8;
 begin
  old:=text;
  inherited;
  if text<>old then
   if isFilter then dialog.FilterChanged else dialog.Edited;
 end;

 procedure TTypeChip.DoClick;
 begin
  inherited;
  if dialog<>nil then dialog.TypeClicked(index,toggled);
 end;

 constructor TUIFileDialog.Create(width,height:single;parent:TUIElement;name:String8);
 begin
  inherited;
  palette:=DefaultPalette;
  shape:=shapeFull;
  finished:=true;
  CreateControls;
  ApplyPalette;
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
  b.drawer:=DrawDialogButton;
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
 procedure StyleTable(t:TUITable);
 begin
  t.style.SetAttr('selection-fill','$FF356FA3');
  t.style.SetAttr('selection-color','$FFFFFFFF');
  t.style.SetAttr('row-hover-fill','$FF99B5CF');
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
  filterEdit:=Edit('NameFilter',false);
  TDialogEdit(filterEdit).isFilter:=true;
  filterEdit.defaultText:=Str32('Filter by name...');
  filterEdit.hint:='Show file names containing this text, ignoring case';
  filterClearButton:=Button('ClearFilter','',ClearFilter);
  filterClearButton.drawer:=DrawClearFilter;
  filterClearButton.hint:='Clear name filter';
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
  StyleTable(table);
  StyleTable(directoryOutline);
  StyleTable(locationsList);
  pinButton:=Button('PinFolder','',PinFolder);
  pinButton.drawer:=DrawPinButton;
  pinButton.hint:='Add current folder to favorites';
 end;

 procedure TUIFileDialog.ApplyPalette;
 procedure C(e:TUIElement;const key:String8;value:cardinal);
 begin
  if e<>nil then e.style.SetAttr(key,'$'+String8(IntToHex(value,8)));
 end;
 procedure TableStyle(t:TUITable);
 var
  bar:TUIElement;
 begin
  C(t,'fill',palette.surface); C(t,'color',palette.text);
  C(t,'border-color',palette.border); C(t,'line-color',palette.border);
  C(t,'header-fill',palette.header); C(t,'header-color',palette.text);
  C(t,'header-hover-fill',palette.hover); C(t,'row-hover-fill',palette.hover);
  C(t,'selection-fill',palette.selection); C(t,'selection-color',palette.selectionText);
  C(t,'favorite-color',palette.favoriteInk); C(t,'recent-color',palette.muted);
  t.style.SetAttr('row-alt-fill','0');
  bar:=t.scrollerV.GetElement;
  bar.style.SetAttr('variant','flat');
  C(bar,'color',palette.muted); C(bar,'track-color',palette.surface); C(bar,'active-color',palette.accent);
 end;
 procedure EditStyle(e:TUIEditBox);
 begin
  C(e,'fill',palette.surface); C(e,'color',palette.text); C(e,'border-color',palette.border);
  e.style.SetAttr('border-width','1'); e.style.SetAttr('radius','3');
 end;
 begin
  C(self,'fill',palette.background); C(self,'color',palette.text);
  if table=nil then exit;
  TableStyle(table); TableStyle(directoryOutline); TableStyle(locationsList);
  EditStyle(pathEdit); EditStyle(nameEdit); EditStyle(filterEdit);
  C(driveBar,'fill',palette.background); C(driveBar,'color',palette.muted);
  C(messageLabel,'color',palette.removeInk);
  if host<>nil then begin
   C(host.frame,'color',palette.text);
   host.frame.style.SetAttr('font-size',GetStyleValue('font-size','9'));
  end;
 end;

 procedure TUIFileDialog.LayoutControls;
 var
  w,h,left,right,bottom,navH,navW,locationsH,chipWidth,tableTop,footer,statusH,nameY,filterW:single;
  inspector:TUIElement;
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
  left:=navW+24; right:=w-8;
  inspector:=nil;
  previewPanel.flags.visible:=(mode=fdOpen) and (length(previewPanel.children)>0);
  optionsPanel.flags.visible:=(mode=fdSave) and (length(optionsPanel.children)>0);
  if previewPanel.flags.visible then inspector:=previewPanel;
  if optionsPanel.flags.visible then inspector:=optionsPanel;
  footer:=104;
  if inspector<>nil then footer:=140;
  statusH:=0;
  messageLabel.flags.visible:=messageLabel.caption<>'';
  if messageLabel.flags.visible then statusH:=24;
  bottom:=h-footer-statusH;
  Place(pathEdit,left,8,right-left-112,28);
  Place(upButton,right-104,8,68,28);
  Place(pinButton,right-28,8,28,28);
  tableTop:=80;
  filterW:=Math.Max(180.0,(right-left)*0.32);
  if right-left>=600 then begin
   Place(typeBar,left,44,right-left-filterW-8,28);
   Place(filterEdit,right-filterW,44,filterW-32,28);
   Place(filterClearButton,right-28,44,28,28);
  end else begin
   Place(typeBar,left,44,right-left,28);
   Place(filterEdit,left,80,right-left-32,28);
   Place(filterClearButton,right-28,80,28,28);
   tableTop:=116;
  end;
  if allTypeButton<>nil then begin
   chipWidth:=typeBar.clientWidth/(length(typeButtons)+1);
   Place(allTypeButton,0,0,chipWidth-4,28);
   for i:=0 to high(typeButtons) do Place(typeButtons[i],(i+1)*chipWidth,0,chipWidth-4,28);
  end;
  // Empty slots occupy no space. Preview and options share the compact bottom area.
  if length(placesPanel.children)>0 then begin
   Place(placesPanel,left,tableTop,placesPanel.size.x,bottom-tableTop);
   left:=left+placesPanel.size.x+8;
  end;
  Place(table,left,tableTop,right-left,bottom-tableTop);
  nameY:=h-footer+8;
  Place(nameLabel,left,nameY,60,28);
  Place(nameEdit,left+60,nameY,right-left-164,28);
  Place(messageLabel,left,bottom+8,right-left,24);
  if inspector<>nil then Place(inspector,left,nameY+36,right-left-104,h-nameY-44);
  Place(acceptButton,w-96,h-72,88,28);
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
  filterEdit.text:='';
  filterClearButton.flags.enabled:=false;
  BuildDrives;
  ApplyPalette;
  if folder='' then SetFolder('') else SetFolder(FullPath(folder));
  LayoutControls;
 end;

 procedure TUIFileDialog.ShowError(const message:String8);
 begin
  messageLabel.caption:=message;
  LayoutControls;
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
   if fFolder='' then upButton.flags.enabled:=false
    else upButton.flags.enabled:=not SamePath(ParentFolder(fFolder),fFolder);
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

 procedure TUIFileDialog.Refresh(reload:boolean);
 var
  mask,query:String8;
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
   if reload then items:=Apus.Files.Folder.ListItems(fFolder,mask);
   query:=UTF8.ToLower(filterEdit.text);
   for i:=0 to high(items) do with items[i] do begin
    if info.isDirectory then continue;
    if hidden and not showHidden then continue;
    if (query<>'') and (Pos(query,UTF8.ToLower(name))=0) then continue;
    row:=table.AddRow(i);
    table.SetCell(row,0,name);
    table.SetCell(row,1,FileSizeText(info.size),info.size);
    table.SetCell(row,2,String8(FormatDateTime('yyyy-mm-dd hh:nn',info.timestamp)),info.timestamp);
   end;
  end;
 end;

 procedure TUIFileDialog.FilterChanged;
 begin
  filterClearButton.flags.enabled:=filterEdit.text<>'';
  Edited;
  Refresh(false);
 end;

 procedure TUIFileDialog.ClearFilter;
 begin
  filterEdit.text:='';
  FilterChanged;
  filterEdit.SetFocus;
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
  b.drawer:=DrawDialogButton;
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
   b.drawer:=DrawDialogButton;
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
   b.drawer:=DrawDialogButton;
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
  i,row,currentRow:integer;
 begin
  locationsList.ClearRows;
  currentRow:=-1;
  for i:=0 to high(favoriteFolders) do begin
   if PathIndex(favoriteFolders,favoriteFolders[i])<>i then continue;
   row:=locationsList.AddRow(i);
   locationsList.SetCell(row,0,favoriteFolders[i]);
   if SamePath(favoriteFolders[i],fFolder) then currentRow:=row;
  end;
  for i:=0 to high(recentFolders) do begin
   if (PathIndex(favoriteFolders,recentFolders[i])>=0) or (PathIndex(recentFolders,recentFolders[i])<>i) then continue;
   row:=locationsList.AddRow($10000+i);
   locationsList.SetCell(row,0,recentFolders[i]);
   if (currentRow<0) and SamePath(recentFolders[i],fFolder) then currentRow:=row;
  end;
  locationsList.selected:=currentRow;
  pinButton.flags.enabled:=fFolder<>'';
  if PathIndex(favoriteFolders,fFolder)>=0 then pinButton.hint:='Remove current folder from favorites'
   else pinButton.hint:='Add current folder to favorites';
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
   else begin
    RemovePath(favoriteFolders,tag);
    index:=PathIndex(recentFolders,path);
    if index>=0 then RemovePath(recentFolders,index);
   end;
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
  if not SamePath(path,fFolder) then SetFolder(path);
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
  if SamePath(parent,fFolder) then exit;
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
  frame.drawer:=DrawDialogFrame;
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
