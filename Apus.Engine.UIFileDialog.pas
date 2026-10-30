// Modal file selection on the real filesystem. Layout is deliberately kept in one method.
// Author: Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 (see license.txt).
// This file is a part of the Apus Game Engine (https://github.com/Cooler2/ApusGameEngine)
unit Apus.Engine.UIFileDialog;
interface
 uses Apus.Core, Apus.Files, Apus.Engine.Types, Apus.Engine.UITypes, Apus.Engine.UIWidgets,
  Apus.Engine.UITable, Apus.Engine.UIMenu, Apus.Engine.UIScene, Apus.Engine.Window;

 const
  FD_FILTER_SUPPORTED=-1; // the All chip: any type of the request
  FD_FILTER_ALL_FILES=-2; // any file: the chip of fdoAllFiles

 type
  TFileDialogMode=(fdOpen,fdSave);
  TFileType=record
   title:String8; // 'PNG image'
   masks:String8; // ';'-separated, case-insensitive: '*.jpg;*.jpeg'
   ext:String8;   // Save adds it to a name of no type of the list: '.jpg'; '' - the masks only filter
  end;
  TFileDialogOption=(
    fdoMultiSelect,        // Open: several files of one folder, the result lists them all
    fdoAllFiles,           // a chip for any file besides All, which is any type of the request
    fdoNoOverwritePrompt); // Save: an existing file is accepted without asking again
  TFileDialogOptions=set of TFileDialogOption;

  // One request: the dialog copies it in Setup, later changes of the record do not reach it
  TFileDialogRequest=record
   mode:TFileDialogMode;
   title:String8;         // the frame caption, '' - texts.openTitle / texts.saveTitle
   acceptCaption:String8; // '' - texts.open / texts.save
   folder:String8;        // '' or missing - the folder of the previous request, then the recent ones
   fileName:String8;      // Save: the name to start with
   types:array of TFileType; // none - any file, no type chips
   filter:integer;        // the chip shown first: a type index, FD_FILTER_SUPPORTED or FD_FILTER_ALL_FILES
   saveType:integer;      // Save: the format, an index in types
   options:TFileDialogOptions;
   class function Init(dialogMode:TFileDialogMode):TFileDialogRequest; static;
   procedure AddType(const title,masks:String8;const ext:String8='');
  end;

  TFileDialogResult=record
   accepted:boolean;
   path:String8;      // the first of paths, '' - cancelled
   paths:Strings8;    // the chosen files in the table order; one in Save
   typeIndex:integer; // Save: the format of the file, Open: -1
  end;

  // Every text the dialog shows. '%s' in a template is the value: a path or a caption.
  // Change them before Setup: the request applies them.
  TFileDialogTexts=record
   openTitle,saveTitle,open,save,cancel,nameLabel:String8;
   nameHint,parentHint,formatHint:String8;
   pinHint,unpinHint:String8;
   allTypes,allTypesHint,allFiles,allFilesHint,typeHint:String8; // typeHint: '%s' - the type with masks
   nameColumn,modifiedColumn,sizeColumn:String8;
   maskColumn:String8; // the name column under a mask: '%s' - the mask
   addFavoriteHint,removeFavoriteHint,unpinRecentHint,removeEntryHint:String8;
   enterName,chooseFolder,nameIsFolder,fileNotFound,folderNotFound,destinationNotFound:String8;
   confirmOverwrite:String8; // '%s' - the accept caption
  end;

  // Size of the frame, column widths and sort order: the application may keep it between runs
  TFileDialogLayout=record
   width,height:single;    // the frame, UI units; 0 - the default size
   columns:array of single; // widths of the file table columns, 0 - a flexible column takes the room
   sortColumn:integer;     // -1 - by name
   sortDescending:boolean;
  end;

  // Glyphs of the buttons, the tree and the places list
  TFileDialogGlyph=(fgAddFavorite,fgFavorite,fgRemove,fgExpand,fgCollapse,fgUp,fgRecent,fgClose);
  // Draw a glyph centered in r (screen pixels) in an ARGB color; scale - screen pixels per
  // UI unit. False - draw the built-in vector glyph. Clipping is already set by the caller.
  TFileDialogGlyphDrawer=function(glyph:TFileDialogGlyph;const r:TRect;color:cardinal;scale:single):boolean of object;
  TUIFileDialog=class;
  TFileDialogScene=class;
  TFileDialogPathEvent=procedure(dialog:TUIFileDialog;const path:String8) of object;
  TFileDialogTypeEvent=procedure(dialog:TUIFileDialog;typeIndex:integer) of object;
  TFileDialogValidate=function(dialog:TUIFileDialog;const value:TFileDialogResult):boolean of object;
  TFileDialogDone=procedure(dialog:TUIFileDialog;const value:TFileDialogResult) of object;

  // Setup runs in the owning window thread and starts a new request, also on an active dialog.
  // A standalone widget calls onDone directly; the scene host closes and restores focus before
  // delivering it. Callbacks must not free the widget inline.
  // The client's controls go to the slots: placesPanel at the left of the file table,
  // previewPanel and optionsPanel under the name, slotHeight high. A slot with no visible
  // child takes no room, so the client shows its controls for the requests it wants them in.
  TUIFileDialog=class(TUIElement)
   texts:TFileDialogTexts;
   showHidden:boolean;
   recentFolders,favoriteFolders:Strings8;
   onLocationsChanged:TObjProcedure; // the app may persist the two lists
   glyphDrawer:TFileDialogGlyphDrawer; // nil - the built-in glyphs
   table:TUITable;
   placesPanel,previewPanel,optionsPanel:TUIElement;
   slotHeight:single; // of previewPanel and optionsPanel, UI units
   onSelect:TFileDialogPathEvent; // the focused file, '' - none: for a preview
   onSaveTypeChanged:TFileDialogTypeEvent;
   onValidate:TFileDialogValidate;
   onDone:TFileDialogDone;
   constructor Create(width,height:single;parent:TUIElement;name:String8='');
   procedure Setup(const request:TFileDialogRequest);
   procedure SetFolder(const path:String8); // '' clears the listing; drive buttons select a root
   function Folder:String8;
   procedure SetSaveType(index:integer); // the extension of the name follows the format
   procedure Confirm;
   procedure Cancel;
   procedure Reload; // read the folder and the tree again, F5
   procedure ShowError(const message:String8);
   function onHotKey(keycode:byte;shiftstate:byte):boolean; override;
   procedure Resize(newWidth,newHeight:single); override;
  protected
   pathEdit,nameEdit:TUIEditBox;
   typeBar:TUIElement;
   allTypeButton,allFilesButton:TUIToggleButton;
   typeButtons:array of TUIToggleButton;
   upButton,acceptButton,cancelButton,formatButton:TUIButton;
   formatMenu:TUIPopupMenu;
   nameLabel,messageLabel:TUILabel;
   navigationPanel,driveBar:TUIElement;
   directoryOutline,locationsList:TUITable;
   pinButton:TUIButton;
   procedure CreateControls; virtual;
   procedure LayoutControls; virtual;
  private
   fRequest:TFileDialogRequest;
   fFolder,overwritePath:String8;
   pickedName:String8; // the name (or the quoted names) the table put into nameEdit
   nameMask:String8;   // the masks typed into nameEdit, '' - none
   listedFolder:String8; // the folder items were read from
   restoring:boolean;    // Refresh puts the selection back
   items:TFolderItems;
   finished:boolean;
   allTypes:boolean;  // the All chip: any type of the request
   allFiles:boolean;  // the chip of any file
   activeTypes:array of boolean;
   fSaveType:integer;
   host:TFileDialogScene;
   function StartFolder(const folder:String8):String8;
   function Mode:TFileDialogMode;
   function Template(const pattern,value:String8):String8;
   procedure ApplyTexts;
   procedure Refresh(reload:boolean=true);
   procedure NameTyped;
   procedure SetNameMask(const mask:String8);
   procedure EnterNameMask;
   procedure UpdateNameColumn;
   procedure BuildDrives;
   procedure BuildTypes;
   procedure BuildFormats;
   procedure ShowFormats;
   procedure TypeClicked(index:integer;active:boolean);
   procedure UpdateTypes;
   procedure DriveClicked;
   procedure BuildLocations(reset:boolean=false);
   procedure UpdatePinButton;
   procedure LocationSelected(sender:TUITable;row:integer);
   procedure LocationAction(tag:NativeInt;remove:boolean);
   function LocationPath(tag:NativeInt):String8;
   procedure PinFolder;
   procedure RememberFolder(const path:String8);
   procedure GoUp;
   procedure PathEntered;
   procedure Edited;
   function ItemPath(index:integer):String8;
   function RowItem(row:integer):integer; // -1 - not a file row
   function TypeOfName(const fileName:String8):integer;
   procedure RowSelected(sender:TUITable;row:integer);
   procedure SelectionChanged(sender:TUITable;row:integer);
   procedure RowActivated(sender:TUITable;row:integer);
   procedure Finish(const value:TFileDialogResult);
  public
   property request:TFileDialogRequest read fRequest;
   property saveType:integer read fSaveType;
  end;

  // A reusable scene owned by the application, one per caller/window if needed.
  // Open shows the request of the last dialog.Setup. onLayoutChanged comes when the dialog
  // closes with another layout than it opened with.
  TFileDialogScene=class(TUIScene)
   dialog:TUIFileDialog;
   frame:TUIWindow;
   onLayoutChanged:TObjProcedure;
   constructor Create(const sceneName:String8='FileDialog';wnd:TWindow=nil);
   destructor Destroy; override;
   procedure Open(modal:boolean=true);
   procedure onResize; override;
   function Layout:TFileDialogLayout;
   procedure SetLayout(const value:TFileDialogLayout);
  private
   prevFocus:TUIElement;
   closeButton:TUIButton;
   preferredW,preferredH:single; // the frame size to restore on the next request
   openedLayout:TFileDialogLayout;
   procedure Close;
  end;

 // The texts of a new dialog
 function DefaultFileDialogTexts:TFileDialogTexts;

implementation
 uses SysUtils, Math, Types, Apus.Conv, Apus.Strings, Apus.Geom2D, Apus.EventMan, Apus.Engine.Keys,
  Apus.Engine.API, Apus.Engine.DefaultStyle, Apus.Engine.Style,
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
   index:integer; // a type, FD_FILTER_SUPPORTED or FD_FILTER_ALL_FILES
   procedure DoClick; override;
  end;
  TFormatItem=class(TUIMenuItem)
   dialog:TUIFileDialog;
   index:integer;
  protected
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
   active:boolean;
   procedure onMouseMove; override;
  end;
  TLocationsList=class(TUITable)
   dialog:TUIFileDialog;
   paths:Strings8; // stable visible order for this request, independent of persisted list indexes
   pressedPath:String8;
   pressedRemove,pressedAction:boolean;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onMouseMove; override;
   procedure onLostFocus; override;
  end;

 const
  DRIVE_MIN_WIDTH=32;
  LOCATION_ACTION_WIDTH=26;

 function PathIndex(const paths:Strings8;const path:String8):integer; forward;
 function SamePath(const a,b:String8):boolean; forward;
 function SameLayout(const a,b:TFileDialogLayout):boolean; forward;

 // Colors of the window come from style tokens. The engine defines each 'file-dialog-*'
 // token as an alias of a theme token; an application sets them to its own colors.
 const
  DIALOG_STYLE='fill:&file-dialog-fill; color:&file-dialog-text; font-size:&file-dialog-font-size';
  FRAME_STYLE='fill:&file-dialog-fill; header-fill:&file-dialog-header; border-color:&file-dialog-border; '+
   'color:&file-dialog-text; font-size:&file-dialog-font-size';
  TABLE_STYLE='fill:&file-dialog-panel; color:&file-dialog-text; border-color:&file-dialog-border; '+
   'border-width:1; line-color:&file-dialog-border; header-fill:&file-dialog-header; '+
   'header-color:&file-dialog-text; header-hover-fill:&file-dialog-hover; row-hover-fill:&file-dialog-hover; '+
   'row-alt-fill:0; selection-fill:&file-dialog-selection; selection-color:&file-dialog-selection-text; '+
   'focus-color:&file-dialog-accent; favorite-color:&file-dialog-favorite; recent-color:&file-dialog-muted; '+
   'glyph-color:&file-dialog-muted; remove-color:&file-dialog-error';
  SCROLLBAR_STYLE='variant:flat; color:&file-dialog-muted; track-color:&file-dialog-panel; '+
   'active-color:&file-dialog-accent';
  EDIT_STYLE='fill:&file-dialog-panel; color:&file-dialog-text; border-color:&file-dialog-border; '+
   'border-width:1; radius:3';
  BUTTON_STYLE='fill:&file-dialog-header; hover-fill:&file-dialog-hover; pressed-fill:&file-dialog-selection; '+
   'pressed-color:&file-dialog-selection-text; border-color:&file-dialog-border; '+
   'focus-border-color:&file-dialog-accent; color:&file-dialog-text; disabled-color:&file-dialog-disabled; '+
   'glyph-color:&file-dialog-muted; favorite-color:&file-dialog-favorite';
  CLOSE_STYLE='hover-fill:&file-dialog-hover; glyph-color:&file-dialog-muted; hover-color:&file-dialog-text';
  DRIVEBAR_STYLE='fill:&file-dialog-fill; color:&file-dialog-muted';
  MESSAGE_STYLE='fill:&file-dialog-header; color:&file-dialog-error';

 // The dialog an element belongs to: its parent chain, or the dialog of its scene (the frame)
 function DialogOf(element:TUIElement):TUIFileDialog;
 var
  e:TUIElement;
 begin
  e:=element;
  while e<>nil do begin
   if e is TUIFileDialog then exit(TUIFileDialog(e));
   e:=e.parent;
  end;
  result:=nil;
  if element.GetScene is TFileDialogScene then result:=TFileDialogScene(element.GetScene).dialog;
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

 // The glyph alone, centered in r: the application's drawer or the built-in one
 procedure DrawBadgeGlyph(element:TUIElement;const r:TRect;scale:single;kind:TFileDialogGlyph;ink:cardinal);
 var
  x,y,a,d:single;
  points:array[0..9] of TVec2;
  i,j:integer;
  dialog:TUIFileDialog;
 begin
  // Triangle glyphs are custom geometry: commit the current clip after the
  // preceding row's text. A row background must not be needed to make them visible.
  if not gfx.clip.Prepare(r) then exit;
  dialog:=DialogOf(element);
  if (dialog<>nil) and Assigned(dialog.glyphDrawer) and dialog.glyphDrawer(kind,r,ink,scale) then exit;
  x:=(r.Left+r.Right)*0.5; y:=(r.Top+r.Bottom)*0.5;
  case kind of
   fgRecent:begin
    for i:=0 to 15 do begin
     a:=i*Pi/8; d:=(i+1)*Pi/8;
     ThickLine(x+4.8*scale*cos(a),y+4.8*scale*sin(a),
       x+4.8*scale*cos(d),y+4.8*scale*sin(d),1.1*scale,ink);
    end;
    ThickLine(x,y-2.8*scale,x,y,1.1*scale,ink);
    ThickLine(x,y,x+2.3*scale,y+1.2*scale,1.1*scale,ink);
   end;
   fgUp:begin
    ThickLine(x,y+4*scale,x,y-4*scale,1.5*scale,ink);
    ThickLine(x-3.5*scale,y-0.5*scale,x,y-4*scale,1.5*scale,ink);
    ThickLine(x+3.5*scale,y-0.5*scale,x,y-4*scale,1.5*scale,ink);
   end;
   fgRemove,fgClose:begin
    ThickLine(x-3.4*scale,y-3.4*scale,x+3.4*scale,y+3.4*scale,1.5*scale,ink);
    ThickLine(x-3.4*scale,y+3.4*scale,x+3.4*scale,y-3.4*scale,1.5*scale,ink);
   end;
   fgExpand,fgCollapse:begin
    ThickLine(x-4*scale,y,x+4*scale,y,1.5*scale,ink);
    if kind=fgExpand then ThickLine(x,y-4*scale,x,y+4*scale,1.5*scale,ink);
   end;
   else begin
    for i:=0 to 9 do begin
     a:=-Pi/2+i*Pi/5;
     if odd(i) then d:=2.5*scale else d:=5.8*scale;
     points[i]:=Vec2(x+cos(a)*d,y+sin(a)*d);
    end;
    for i:=0 to 9 do begin
     j:=(i+1) mod 10;
     if kind=fgFavorite then
      draw.FillTriangle(x,y,points[i].x,points[i].y,points[j].x,points[j].y,ink,ink,ink)
     else ThickLine(points[i].x,points[i].y,points[j].x,points[j].y,1.1*scale,ink);
    end;
   end;
  end;
 end;

 // A toolbar button keeps its shape, a list glyph has no chrome. Only the favorite star
 // of a button and the remove cross carry their own colors, the rest is muted.
 procedure DrawBadge(element:TUIElement;const r:TRect;scale:single;kind:TFileDialogGlyph;enabled:boolean=true);
 var
  fill,ink:cardinal;
  isButton:boolean;
 begin
  isButton:=element is TUIButton;
  ink:=element.GetStyleColor('glyph-color',$FF707070);
  if kind=fgRemove then ink:=element.GetStyleColor('remove-color',ink)
   else if (kind=fgFavorite) and isButton then ink:=element.GetStyleColor('favorite-color',ink);
  if not enabled then ink:=element.GetStyleColor('disabled-color',ink);
  if isButton then begin
   fill:=element.GetStyleColor('fill');
   if TUIButton(element).IsHovered then fill:=element.GetStyleColor('hover-fill',fill);
   draw.RoundRect(r.Left,r.Top,r.Right-1,r.Bottom-1,3*scale,scale,element.GetStyleColor('border-color'),fill);
  end;
  DrawBadgeGlyph(element,r,scale,kind,ink);
 end;

 procedure DrawPinButton(element:TUIElement);
 var
  dialog:TUIFileDialog;
  kind:TFileDialogGlyph;
 begin
  dialog:=TUIFileDialog(element.parent);
  if PathIndex(dialog.favoriteFolders,dialog.Folder)>=0 then kind:=fgFavorite else kind:=fgAddFavorite;
  DrawBadge(element,element.globalRect,element.globalScale,kind,element.IsEnabled);
 end;

 procedure DrawUpButton(element:TUIElement);
 begin
  DrawBadge(element,element.globalRect,element.globalScale,fgUp,element.IsEnabled);
 end;

 procedure DrawDialogButton(element:TUIElement);
 var
  b:TUIButton;
  r:TRect;
  fill,ink,border:cardinal;
  font:TFontHandle;
  toggled:boolean;
 begin
  b:=TUIButton(element); r:=element.globalRect;
  toggled:=(b is TUIToggleButton) and TUIToggleButton(b).toggled;
  if b is TDriveButton then toggled:=TDriveButton(b).active;
  fill:=b.GetStyleColor('fill'); ink:=b.GetStyleColor('color'); border:=b.GetStyleColor('border-color');
  if toggled or b.pressed then fill:=b.GetStyleColor('pressed-fill',fill)
   else if b.IsHovered then fill:=b.GetStyleColor('hover-fill',fill);
  if toggled then ink:=b.GetStyleColor('pressed-color',ink);
  if b.default or (FocusedElement=b) then border:=b.GetStyleColor('focus-border-color',border);
  if not b.IsEnabled then ink:=b.GetStyleColor('disabled-color',ink);
  draw.RoundRect(r.Left,r.Top,r.Right-1,r.Bottom-1,3*element.globalScale,element.globalScale,border,fill);
  font:=element.StyleFont;
  txt.Write(font,(r.Left+r.Right)*0.5,round((r.Top+r.Bottom-1)*0.5+txt.Height(font)*0.45),ink,b.caption,taCenter);
 end;

 // A dialog button with a caret at the right: it opens a list
 procedure DrawFormatButton(element:TUIElement);
 var
  b:TUIButton;
  r:TRect;
  fill,ink,border:cardinal;
  font:TFontHandle;
  s,x,y:single;
 begin
  b:=TUIButton(element); r:=element.globalRect; s:=element.globalScale;
  fill:=b.GetStyleColor('fill'); ink:=b.GetStyleColor('color'); border:=b.GetStyleColor('border-color');
  if b.pressed then fill:=b.GetStyleColor('pressed-fill',fill)
   else if b.IsHovered then fill:=b.GetStyleColor('hover-fill',fill);
  if FocusedElement=b then border:=b.GetStyleColor('focus-border-color',border);
  if not b.IsEnabled then ink:=b.GetStyleColor('disabled-color',ink);
  draw.RoundRect(r.Left,r.Top,r.Right-1,r.Bottom-1,3*s,s,border,fill);
  font:=element.StyleFont;
  x:=r.Right-10*s; y:=(r.Top+r.Bottom)*0.5;
  draw.FillTriangle(x-3.5*s,y-1.8*s,x+3.5*s,y-1.8*s,x,y+2.2*s,ink,ink,ink);
  txt.Write(font,(r.Left+r.Right)*0.5-7*s,round((r.Top+r.Bottom-1)*0.5+txt.Height(font)*0.45),ink,b.caption,taCenter);
 end;

 procedure DrawDialogFrame(element:TUIElement);
 var
  frame:TUIWindow;
  r,client:TRect;
  font:TFontHandle;
 begin
  frame:=TUIWindow(element);
  r:=frame.globalRect; client:=frame.GetClientPosOnScreen;
  draw.FillRect(r.Left,r.Top,r.Right-1,r.Bottom-1,frame.GetStyleColor('fill'));
  draw.FillRect(r.Left,r.Top,r.Right-1,client.Top-1,frame.GetStyleColor('header-fill'));
  draw.Rect(r.Left,r.Top,r.Right-1,r.Bottom-1,frame.GetStyleColor('border-color'));
  font:=frame.StyleFont;
  txt.Write(font,(r.Left+r.Right)*0.5,round((r.Top+client.Top-1)*0.5+txt.Height(font)*0.45),
    frame.GetStyleColor('color'),frame.caption,taCenter);
 end;

 procedure DrawCloseButton(element:TUIElement);
 var
  r:TRect;
  ink:cardinal;
 begin
  r:=element.globalRect;
  ink:=element.GetStyleColor('glyph-color');
  if TUIButton(element).IsHovered then begin
   draw.FillRect(r.Left,r.Top,r.Right-1,r.Bottom-1,element.GetStyleColor('hover-fill'));
   ink:=element.GetStyleColor('hover-color',ink);
  end;
  DrawBadgeGlyph(element,r,element.globalScale*0.9,fgClose,ink);
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
    if pinned then color:=list.GetStyleColor('favorite-color',$FF244C78)
     else color:=list.GetStyleColor('recent-color',$FF585860);
    icon:=cell;
    icon.Left:=icon.Right-round(LOCATION_ACTION_WIDTH*s);
    if row=list.selected then color:=list.GetStyleColor('selection-color',$FFFFFFFF);
    if remove then DrawBadge(list,icon,s*0.85,fgRemove)
    else if pinned then DrawBadge(list,icon,s*0.85,fgFavorite)
    else if (row=list.hoverRow) and (curMouseX>=icon.Left) then
     DrawBadge(list,icon,s*0.85,fgAddFavorite)
    else DrawBadge(list,icon,s*0.85,fgRecent);
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
  path:String8;
 begin
  if button=1 then begin
   p:=TransformFromScreen(Vec2(curMouseX,curMouseY));
   row:=RowAtPoint(p.x,p.y);
   if not state and (pressedPath<>'') then begin
    path:=pressedPath;
    pressedPath:='';
    if hooked=self then hooked:=nil;
    if (row>=0) and SamePath(path,dialog.LocationPath(RowTag(row))) and
       (pressedAction=(p.x>=RowsWidth-LOCATION_ACTION_WIDTH)) then begin
     if pressedAction then dialog.LocationAction(RowTag(row),pressedRemove)
     else begin
      selected:=row;
      dialog.LocationSelected(self,row);
     end;
    end;
    exit;
   end;
   if state and (row>=0) then begin
    pressedPath:=dialog.LocationPath(RowTag(row));
    pressedRemove:=(GetWindow.shiftState and sscCtrl)<>0;
    pressedAction:=p.x>=RowsWidth-LOCATION_ACTION_WIDTH;
    SetFocus;
    hooked:=self;
    exit;
   end;
  end;
  inherited;
 end;

 procedure TLocationsList.onMouseMove;
 var
  p:TVec2;
  tag:NativeInt;
 begin
  inherited;
  hint:='';
  if hoverRow<0 then exit;
  tag:=RowTag(hoverRow);
  hint:=dialog.LocationPath(tag);
  p:=TransformFromScreen(Vec2(curMouseX,curMouseY));
  if p.x>=RowsWidth-LOCATION_ACTION_WIDTH then begin
   if (GetWindow.shiftState and sscCtrl)<>0 then hint:=dialog.texts.removeEntryHint
   else if PathIndex(dialog.favoriteFolders,hint)>=0 then begin
    if PathIndex(dialog.recentFolders,hint)>=0 then hint:=dialog.texts.unpinRecentHint
     else hint:=dialog.texts.removeFavoriteHint;
   end else hint:=dialog.texts.addFavoriteHint;
  end;
 end;

 procedure TLocationsList.onLostFocus;
 begin
  pressedPath:='';
  if hooked=self then hooked:=nil;
  inherited;
 end;
 const
  OUTLINE_INDENT=14;      // per tree level
  OUTLINE_TOGGLE_LEFT=4;  // the disclosure button at the left of its level
  OUTLINE_TOGGLE_WIDTH=20;
  OUTLINE_NAVIGATE_DELAY=350; // ms the keyboard cursor rests before the folder opens

 type
  TDirectoryNode=record
   path:String8;
   depth:integer;
   opened:boolean; // its subfolders are the rows below it
   leaf:boolean;   // known to have no subfolders: no disclosure button
  end;
  TDirectoryListing=record
   path:String8;
   names:Strings8; // subfolders in the natural order
   hidden:array of boolean;
  end;
  // Local tree adapter: one row per visible directory, the row index is the node index.
  // The disclosure area expands independently of selection; the file table never contains
  // directory rows. Listings are cached until Reload, so rebuilding the rows reads only
  // folders not read before. A click opens the folder at once, the keyboard cursor after
  // a pause or Enter; Left and Right collapse and expand.
  TDirectoryOutline=class(TUITable)
   dialog:TUIFileDialog;
   nodes:array of TDirectoryNode;
   expanded:Strings8;   // open folders
   userOpened:Strings8; // opened by the user: navigation from outside keeps them open
   listings:array of TDirectoryListing;
   current:String8;
   building,selecting,clicking:boolean;
   constructor Create(parent:TUIElement;dialog:TUIFileDialog;const name:String8);
   procedure Build(const folder:String8);
   procedure Reload;
   function ListingOf(const path:String8):integer;
   function ToggleLeft(index:integer):single;
   procedure DirectorySelected(sender:TUITable;row:integer);
   procedure DirectoryActivated(sender:TUITable;row:integer);
   procedure Navigate(row:integer);
   procedure SelectQuietly(row:integer);
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onMouseMove; override;
   procedure onTimer; override;
   function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
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
  kind:TFileDialogGlyph;
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
   badge.Left:=cell.Left+round(table.ToggleLeft(index)*s);
   badge.Right:=badge.Left+round(OUTLINE_TOGGLE_WIDTH*s);
   if not table.nodes[index].leaf then begin
    if table.nodes[index].opened then kind:=fgCollapse else kind:=fgExpand;
    DrawBadge(table,badge,s*0.85,kind);
   end;
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
  result:=Files.GetFullName(JoinPath(path,'..'));
 end;

 // One decimal below 100 of a unit, whole numbers above: '5.0 KB', '16.5 KB', '150 KB'
 function FileSizeText(bytes:int64):String8;
 const
  UNITS:array[0..3] of String8=('B','KB','MB','GB');
 var
  v:double;
  u:integer;
  tenths:int64;
 begin
  if bytes<1024 then exit(Conv.ToStr(bytes)+' B');
  v:=bytes; u:=0;
  while (v>=1024) and (u<high(UNITS)) do begin
   v:=v/1024;
   inc(u);
  end;
  if v<100 then begin
   tenths:=round(v*10);
   result:=Conv.ToStr(tenths div 10)+'.'+Conv.ToStr(tenths mod 10);
  end else result:=Conv.ToStr(round(v));
  result:=result+' '+UNITS[u];
 end;

 // The index after the UTF-8 character at i
 function NextChar(const s:String8;i:integer):integer;
 begin
  result:=i+1;
  while (result<=length(s)) and ((byte(s[result]) and $C0)=$80) do inc(result);
 end;

 // '*' and '?' wildcards, '?' is one character; the name and the ';'-separated masks are
 // lowercased by the caller. Temporary until Files matches masks itself (PaintRaw E-29)
 function MatchesMask(const name,mask:String8):boolean;
 var
  n,m,starN,starM:integer;
 begin
  n:=1; m:=1; starN:=0; starM:=0;
  while n<=length(name) do
   if (m<=length(mask)) and (mask[m]='*') then begin
    starM:=m; starN:=n; inc(m);
   end else if (m<=length(mask)) and (mask[m]='?') then begin
    n:=NextChar(name,n); inc(m);
   end else if (m<=length(mask)) and (mask[m]=name[n]) then begin
    inc(n); inc(m);
   end else if starM>0 then begin
    m:=starM+1; starN:=NextChar(name,starN); n:=starN;
   end else exit(false);
  while (m<=length(mask)) and (mask[m]='*') do inc(m);
  result:=m>length(mask);
 end;

 function HasWildcards(const s:String8):boolean;
 begin
  result:=(Pos(String8('*'),s)>0) or (Pos(String8('?'),s)>0);
 end;

 // Masks of the name field: a mask with no dot also matches the name without its
 // extension, so '*_n' finds rock_n.png
 function MatchesNameMasks(const name,masks:String8):boolean;
 var
  i,start:integer;
  mask,stem:String8;
 begin
  stem:=Files.ChangeExt(name,'');
  start:=1;
  for i:=1 to length(masks)+1 do
   if (i>length(masks)) or (masks[i] in [';',',']) then begin
    mask:=copy(masks,start,i-start).Trim;
    if (mask<>'') and (MatchesMask(name,mask) or ((Pos(String8('.'),mask)=0) and MatchesMask(stem,mask))) then
     exit(true);
    start:=i+1;
   end;
  result:=false;
 end;

 function MatchesMasks(const name,masks:String8):boolean;
 var
  i,start:integer;
 begin
  start:=1;
  for i:=1 to length(masks)+1 do
   if (i>length(masks)) or (masks[i] in [';',',']) then begin
    if (i>start) and MatchesMask(name,copy(masks,start,i-start)) then exit(true);
    start:=i+1;
   end;
  result:=false;
 end;

 constructor TDirectoryOutline.Create(parent:TUIElement;dialog:TUIFileDialog;const name:String8);
 begin
  inherited Create(100,100,parent,name);
  self.dialog:=dialog;
  AddColumn('',0,taLeft,tsNone);
  headerHeight:=0;
  onSelect:=DirectorySelected;
  onActivate:=DirectoryActivated;
  drawer:=DrawDirectoryOutline;
 end;

 function TDirectoryOutline.ToggleLeft(index:integer):single;
 begin
  result:=OUTLINE_TOGGLE_LEFT+nodes[index].depth*OUTLINE_INDENT;
 end;

 procedure TDirectoryOutline.Reload;
 begin
  listings:=nil;
 end;

 // The cached listing of a folder; reads the folder if it is not cached yet
 function TDirectoryOutline.ListingOf(const path:String8):integer;
 var
  items:TFolderItems;
  keys:Strings8;
  item:TFolderItem;
  n,k:String8;
  h:boolean;
  i,j,count:integer;
 begin
  for i:=0 to high(listings) do
   if SamePath(listings[i].path,path) then exit(i);
  result:=length(listings);
  SetLength(listings,result+1);
  listings[result].path:=path;
  items:=Apus.Files.Folder.ListItems(path);
  count:=0;
  with listings[result] do begin
   SetLength(names,length(items));
   SetLength(hidden,length(items));
   SetLength(keys,length(items));
   for item in items do
    if item.info.isDirectory then begin
     names[count]:=item.name;
     hidden[count]:=item.hidden;
     keys[count]:=UTF8.ToLower(item.name);
     inc(count);
    end;
   SetLength(names,count);
   SetLength(hidden,count);
   for i:=1 to count-1 do begin
    n:=names[i]; h:=hidden[i]; k:=keys[i]; j:=i-1;
    while (j>=0) and (NaturalCompare(keys[j],k)>0) do begin
     names[j+1]:=names[j]; hidden[j+1]:=hidden[j]; keys[j+1]:=keys[j];
     dec(j);
    end;
    names[j+1]:=n; hidden[j+1]:=h; keys[j+1]:=k;
   end;
  end;
 end;

 procedure TDirectoryOutline.Build(const folder:String8);
 var
  root,p,parentPath,anchor:String8;
  selectedRow,topRow,i:integer;
  oldPos,offset:single;
  keepView,moved:boolean;
 function OnRoute(const path:String8):boolean;
 begin
  result:=SamePath(path,folder) or SamePath(path,copy(folder,1,length(path))) and
    (copy(folder,length(path)+1,1)=PathDelim);
 end;
 // A hidden folder on the route to the current one is shown: the route must not break
 function Visible(listing,i:integer):boolean;
 begin
  with listings[listing] do
   result:=dialog.showHidden or not hidden[i] or OnRoute(JoinPath(path,names[i]));
 end;
 procedure AddNode(const path:String8;depth:integer);
 var
  labelText:String8;
  i,listing,index,row,cached:integer;
 begin
  index:=length(nodes);
  SetLength(nodes,index+1);
  nodes[index].path:=path;
  nodes[index].depth:=depth;
  nodes[index].opened:=PathIndex(expanded,path)>=0;
  labelText:=Files.GetName(path);
  if labelText='' then labelText:=path;
  row:=AddRow(index);
  SetCell(row,0,labelText);
  if SamePath(path,folder) then selectedRow:=row;
  cached:=-1;
  for i:=0 to high(listings) do
   if SamePath(listings[i].path,path) then cached:=i;
  if not nodes[index].opened and (cached<0) then exit;
  listing:=ListingOf(path);
  nodes[index].leaf:=true;
  for i:=0 to high(listings[listing].names) do
   if Visible(listing,i) then begin
    nodes[index].leaf:=false;
    if not nodes[index].opened then break;
    AddNode(JoinPath(path,listings[listing].names[i]),depth+1);
   end;
 end;
 begin
  moved:=not SamePath(current,folder);
  keepView:=selecting or not moved;
  oldPos:=ScrollPos;
  offset:=Frac(oldPos/rowHeight)*rowHeight;
  anchor:='';
  topRow:=RowAt(trunc(oldPos/rowHeight));
  if (topRow>=0) and (topRow<length(nodes)) then anchor:=nodes[topRow].path;
  building:=true;
  try
   selectedRow:=-1;
   ClearRows;
   nodes:=nil;
   if folder='' then exit;
   // Navigation from outside the tree closes the route it opened before, the folders
   // the user opened stay open
   if moved and not selecting then expanded:=Copy(userOpened);
   // Reveal the route on navigation, but permit collapsing the selected node later
   root:=folder;
   p:=folder;
   repeat
    if moved and (PathIndex(expanded,p)<0) then expanded:=expanded+[p];
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
     oldPos:=i*rowHeight+offset;
     break;
    end;
    scrollerV.SetValue(oldPos);
   end else if selectedRow>=0 then
    // The tree follows navigation from outside it: the current folder in the upper third
    scrollerV.SetValue(selectedRow*rowHeight-RowsHeight/3);
  finally
   building:=false;
  end;
 end;

 procedure TDirectoryOutline.Navigate(row:integer);
 begin
  timer:=0;
  if (row<0) or (row>=length(nodes)) or SamePath(nodes[row].path,dialog.Folder) then exit;
  selecting:=true;
  try
   dialog.SetFolder(nodes[row].path);
  finally
   selecting:=false;
  end;
 end;

 procedure TDirectoryOutline.DirectorySelected(sender:TUITable;row:integer);
 begin
  if building or (row<0) then exit;
  if clicking then Navigate(row)
   else timer:=OUTLINE_NAVIGATE_DELAY;
 end;

 procedure TDirectoryOutline.DirectoryActivated(sender:TUITable;row:integer);
 begin
  Navigate(row);
 end;

 procedure TDirectoryOutline.onTimer;
 begin
  Navigate(selected);
 end;

 // Move the cursor without opening the folder
 procedure TDirectoryOutline.SelectQuietly(row:integer);
 begin
  building:=true;
  try
   selected:=row;
  finally
   building:=false;
  end;
 end;

 procedure TDirectoryOutline.ToggleNode(index:integer);
 var
  i:integer;
  path,cursor:String8;
 begin
  if (index<0) or (index>=length(nodes)) then exit;
  path:=nodes[index].path;
  cursor:='';
  if selected>=0 then cursor:=nodes[selected].path;
  i:=PathIndex(expanded,path);
  if i<0 then begin
   expanded:=expanded+[path];
   if PathIndex(userOpened,path)<0 then userOpened:=userOpened+[path];
  end else begin
   RemovePath(expanded,i);
   i:=PathIndex(userOpened,path);
   if i>=0 then RemovePath(userOpened,i);
  end;
  Build(dialog.Folder);
  // the keyboard cursor stays on its folder when it is still in the tree
  for i:=0 to high(nodes) do
   if (cursor<>'') and SamePath(nodes[i].path,cursor) then SelectQuietly(i);
 end;

 function TDirectoryOutline.onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean;
 var
  index,i:integer;
 begin
  if pressed and (shiftstate=0) and (selected>=0) and
     ((TKey(keycode)=TKey.Left) or (TKey(keycode)=TKey.Right)) then begin
   index:=selected;
   if TKey(keycode)=TKey.Right then begin
    if not nodes[index].opened then begin
     if not nodes[index].leaf then ToggleNode(index);
    end else if (index<high(nodes)) and (nodes[index+1].depth>nodes[index].depth) then
     SelectQuietly(index+1);
   end else begin
    if nodes[index].opened and not nodes[index].leaf then ToggleNode(index)
    else
     for i:=index-1 downto 0 do
      if nodes[i].depth<nodes[index].depth then begin
       SelectQuietly(i);
       break;
      end;
   end;
   timer:=OUTLINE_NAVIGATE_DELAY;
   exit(false);
  end;
  result:=inherited onKey(keycode,pressed,shiftstate);
 end;

 procedure TDirectoryOutline.onMouseButtons(button:byte;state:boolean);
 var
  p:TVec2;
  row:integer;
  left:single;
 begin
  if (button=1) and state then begin
   p:=TransformFromScreen(Vec2(curMouseX,curMouseY));
   row:=RowAtPoint(p.x,p.y);
   if (row>=0) and (row<length(nodes)) and not nodes[row].leaf then begin
    left:=ToggleLeft(row);
    if (p.x>=left) and (p.x<left+OUTLINE_TOGGLE_WIDTH) then begin
     ToggleNode(row);
     exit;
    end;
   end;
  end;
  clicking:=true;
  try
   inherited;
  finally
   clicking:=false;
  end;
 end;

 procedure TDirectoryOutline.onMouseMove;
 begin
  inherited;
  hint:='';
  if (hoverRow>=0) and (hoverRow<length(nodes)) then hint:=nodes[hoverRow].path;
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
  if text<>old then
   if isPath then dialog.Edited else dialog.NameTyped;
 end;

 procedure TDialogEdit.onUniChar(ch:Char32;scancode:byte);
 var
  old:String8;
 begin
  old:=text;
  inherited;
  if text<>old then
   if isPath then dialog.Edited else dialog.NameTyped;
 end;

 procedure TTypeChip.DoClick;
 begin
  inherited;
  if dialog<>nil then dialog.TypeClicked(index,toggled);
 end;

 procedure TFormatItem.DoClick;
 begin
  inherited;
  dialog.SetSaveType(index);
 end;

 class function TFileDialogRequest.Init(dialogMode:TFileDialogMode):TFileDialogRequest;
 begin
  result:=Default(TFileDialogRequest);
  result.mode:=dialogMode;
  result.filter:=FD_FILTER_SUPPORTED;
 end;

 procedure TFileDialogRequest.AddType(const title,masks,ext:String8);
 var
  n:integer;
 begin
  n:=length(types);
  SetLength(types,n+1);
  types[n].title:=title;
  types[n].masks:=masks;
  types[n].ext:=ext;
 end;

 function DefaultFileDialogTexts:TFileDialogTexts;
 begin
  with result do begin
   openTitle:='Open'; saveTitle:='Save As';
   open:='Open'; save:='Save'; cancel:='Cancel'; nameLabel:='Name:';
   nameHint:='A file name; * and ? make a mask that filters the list: *.png, *_n';
   parentHint:='Parent folder';
   formatHint:='File format';
   pinHint:='Add current folder to favorites';
   unpinHint:='Remove current folder from favorites';
   allTypes:='All'; allTypesHint:='All supported files';
   allFiles:='*.*'; allFilesHint:='All files';
   typeHint:='%s. Ctrl+click changes only this filter.';
   nameColumn:='Name'; modifiedColumn:='Modified'; sizeColumn:='Size';
   maskColumn:='Name: %s';
   addFavoriteHint:='Add folder to favorites';
   removeFavoriteHint:='Remove folder from favorites';
   unpinRecentHint:='Unpin folder (keep in Recent)';
   removeEntryHint:='Remove entry';
   enterName:='Enter a file name';
   chooseFolder:='Choose a folder first';
   nameIsFolder:='The name belongs to a folder';
   fileNotFound:='File not found: %s';
   folderNotFound:='Folder not found: %s';
   destinationNotFound:='Destination folder not found';
   confirmOverwrite:='File exists. Press %s again to replace it.';
  end;
 end;

 constructor TUIFileDialog.Create(width,height:single;parent:TUIElement;name:String8);
 begin
  inherited;
  styleInfo:=DIALOG_STYLE;
  shape:=shapeFull;
  finished:=true;
  texts:=DefaultFileDialogTexts;
  slotHeight:=88;
  fRequest:=TFileDialogRequest.Init(fdOpen);
  CreateControls;
  ApplyTexts;
  LayoutControls;
 end;

 function TUIFileDialog.Mode:TFileDialogMode;
 begin
  result:=fRequest.mode;
 end;

 // The template with '%s' replaced by the value
 function TUIFileDialog.Template(const pattern,value:String8):String8;
 var
  p:integer;
 begin
  result:=pattern;
  p:=Pos(String8('%s'),result);
  if p>0 then result:=copy(result,1,p-1)+value+copy(result,p+2,length(result));
 end;

 procedure TUIFileDialog.ApplyTexts;
 begin
  upButton.hint:=texts.parentHint;
  UpdateNameColumn;
  table.columns[1].caption:=texts.modifiedColumn;
  table.columns[2].caption:=texts.sizeColumn;
  nameLabel.caption:=texts.nameLabel;
  nameEdit.hint:=texts.nameHint;
  formatButton.hint:=texts.formatHint;
  cancelButton.caption:=texts.cancel;
  if fRequest.acceptCaption<>'' then acceptButton.caption:=fRequest.acceptCaption
   else if Mode=fdOpen then acceptButton.caption:=texts.open
   else acceptButton.caption:=texts.save;
  UpdatePinButton;
 end;

 procedure TUIFileDialog.CreateControls;
 function Button(const suffix,caption:String8;handler:TObjProcedure):TUIButton;
 var
  b:TDialogButton;
 begin
  b:=TDialogButton.Create(88,28,self,name+'\'+suffix);
  b.styleInfo:=BUTTON_STYLE;
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
  e.styleInfo:=EDIT_STYLE;
  e.dialog:=self;
  e.isPath:=isPath;
  e.maxlength:=32767;
  result:=e;
 end;
 procedure StyleTable(t:TUITable);
 begin
  t.styleInfo:=TABLE_STYLE;
  t.scrollerV.GetElement.styleInfo:=SCROLLBAR_STYLE;
  t.scrollerH.GetElement.styleInfo:=SCROLLBAR_STYLE;
 end;
 begin
  pathEdit:=Edit('Path',true);
  upButton:=Button('Up','',GoUp);
  upButton.drawer:=DrawUpButton;
  table:=TUITable.Create(100,100,self,name+'\Table');
  table.AddColumn('',0);
  table.AddColumn('',140,taLeft,tsKey);
  table.AddColumn('',80,taRight,tsKey);
  table.SortBy(0);
  table.onSelect:=RowSelected;
  table.onSelectionChanged:=SelectionChanged;
  table.onActivate:=RowActivated;
  nameLabel:=TUILabel.Create(60,28,self);
  nameEdit:=Edit('Name',false);
  formatButton:=Button('Format','',ShowFormats);
  formatButton.drawer:=DrawFormatButton;
  formatMenu:=TUIPopupMenu.Create(self,name+'\Formats');
  typeBar:=TUIElement.Create(100,28,self,name+'\Types');
  messageLabel:=TUILabel.Create(100,24,self,name+'\Message');
  messageLabel.SetPaddings(6,0,6,0);
  messageLabel.styleInfo:=MESSAGE_STYLE;
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
  driveBar.styleInfo:=DRIVEBAR_STYLE;
  directoryOutline:=TDirectoryOutline.Create(navigationPanel,self,name+'\Directories');
  locationsList:=TLocationsList.Create(340,120,navigationPanel,name+'\Locations');
  TLocationsList(locationsList).dialog:=self;
  locationsList.drawer:=DrawLocations;
  locationsList.AddColumn('',0,taLeft,tsNone);
  locationsList.headerHeight:=0;
  // Selection alone never navigates: rebuilding or moving the keyboard cursor
  // must not rebuild the outline. A completed click or Enter activates the path.
  locationsList.onActivate:=LocationSelected;
  StyleTable(table);
  StyleTable(directoryOutline);
  StyleTable(locationsList);
  pinButton:=Button('PinFolder','',PinFolder);
  pinButton.drawer:=DrawPinButton;
 end;

 procedure TUIFileDialog.LayoutControls;
 var
  w,h,left,right,bottom,navH,navW,locationsH,chipWidth,tableTop,footer,nameY,slotW:single;
  i:integer;
 procedure Place(e:TUIElement;x,y,w,h:single);
 begin
  e.SetPos(x,y);
  e.Resize(Math.Max(0.0,w),Math.Max(0.0,h));
 end;
 function HasVisibleChild(e:TUIElement):boolean;
 var
  c:TUIElement;
 begin
  for c in e.children do
   if c.flags.visible then exit(true);
  result:=false;
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
  previewPanel.flags.visible:=HasVisibleChild(previewPanel);
  optionsPanel.flags.visible:=HasVisibleChild(optionsPanel);
  footer:=104;
  if previewPanel.flags.visible or optionsPanel.flags.visible then footer:=52+slotHeight;
  messageLabel.flags.visible:=messageLabel.caption<>'';
  bottom:=h-footer;
  Place(pathEdit,left,8,right-left-72,28);
  Place(upButton,right-64,8,28,28);
  Place(pinButton,right-28,8,28,28);
  // a request without types has no chips and no row for them
  typeBar.flags.visible:=length(typeBar.children)>0;
  tableTop:=44;
  if typeBar.flags.visible then begin
   Place(typeBar,left,44,right-left,28);
   tableTop:=80;
   // equal chips from the left, never wider than a short caption needs
   chipWidth:=Math.Min(68.0,typeBar.clientWidth/length(typeBar.children));
   for i:=0 to high(typeBar.children) do Place(typeBar.children[i],i*chipWidth,0,chipWidth-4,28);
  end;
  // Empty slots occupy no space. Preview and options share the compact bottom area.
  if HasVisibleChild(placesPanel) then begin
   placesPanel.flags.visible:=true;
   Place(placesPanel,left,tableTop,placesPanel.size.x,bottom-tableTop);
   left:=left+placesPanel.size.x+8;
  end else placesPanel.flags.visible:=false;
  Place(table,left,tableTop,right-left,bottom-tableTop);
  nameY:=h-footer+8;
  Place(nameLabel,left,nameY,60,28);
  formatButton.flags.visible:=(Mode=fdSave) and (length(fRequest.types)>0);
  if formatButton.flags.visible then begin
   Place(nameEdit,left+60,nameY,right-left-164-104,28);
   Place(formatButton,right-200,nameY,96,28);
  end else Place(nameEdit,left+60,nameY,right-left-164,28);
  // The message covers the bottom rows of the table instead of moving the layout
  Place(messageLabel,left+1,bottom-25,right-left-2,24);
  slotW:=right-left-104;
  if previewPanel.flags.visible and optionsPanel.flags.visible then begin
   Place(previewPanel,left,nameY+36,slotW/2-4,slotHeight);
   Place(optionsPanel,left+slotW/2+4,nameY+36,slotW/2-4,slotHeight);
  end else if previewPanel.flags.visible then Place(previewPanel,left,nameY+36,slotW,slotHeight)
  else if optionsPanel.flags.visible then Place(optionsPanel,left,nameY+36,slotW,slotHeight);
  Place(acceptButton,w-96,h-72,88,28);
  Place(cancelButton,w-96,h-36,88,28);
 end;

 procedure TUIFileDialog.Resize(newWidth,newHeight:single);
 begin
  inherited;
  LayoutControls;
 end;

 procedure TUIFileDialog.Setup(const request:TFileDialogRequest);
 var
  filter:integer;
 begin
  fRequest:=request;
  fRequest.types:=Copy(request.types);
  // Scenes may be constructed by the application thread. UI hotkeys belong to the
  // window thread, where Setup and input run, rather than to that constructor's thread.
  SetHotKey(ord(TKey.Escape));
  SetHotKey(ord(TKey.F5));
  table.keyScope:=self;
  table.multiSelect:=(Mode=fdOpen) and (fdoMultiSelect in fRequest.options);
  finished:=false;
  Edited;
  if (Mode=fdSave) and (length(fRequest.types)>0) then
   fSaveType:=Clamp(fRequest.saveType,0,length(fRequest.types)-1)
  else fSaveType:=-1;
  activeTypes:=nil;
  SetLength(activeTypes,length(fRequest.types));
  filter:=fRequest.filter;
  if (filter=FD_FILTER_ALL_FILES) and not (fdoAllFiles in fRequest.options) then filter:=FD_FILTER_SUPPORTED;
  if filter>high(activeTypes) then filter:=FD_FILTER_SUPPORTED;
  allFiles:=filter=FD_FILTER_ALL_FILES;
  allTypes:=filter=FD_FILTER_SUPPORTED;
  if filter>=0 then activeTypes[filter]:=true;
  BuildTypes;
  BuildFormats;
  // a mask for a name starts the request filtered
  nameMask:='';
  if HasWildcards(fRequest.fileName) and (Files.GetName(fRequest.fileName)=fRequest.fileName) then
   nameMask:=fRequest.fileName;
  ApplyTexts;
  nameEdit.text:=fRequest.fileName;
  pickedName:='';
  BuildDrives;
  TDirectoryOutline(directoryOutline).Reload;
  listedFolder:=''; // a new request reads the folder again and selects nothing
  SetFolder(StartFolder(fRequest.folder));
  BuildLocations(true);
  LayoutControls;
 end;

 // The first existing one of: the requested folder, the folder of the previous request,
 // the recent folders, the current folder
 function TUIFileDialog.StartFolder(const folder:String8):String8;
 var
  path:String8;
 function Usable(const path:String8;out full:String8):boolean;
 begin
  result:=false;
  if path='' then exit;
  full:=Files.GetFullName(path);
  result:=Apus.Files.Folder.Exists(full);
 end;
 begin
  if Usable(folder,result) or Usable(fFolder,result) then exit;
  for path in recentFolders do
   if Usable(path,result) then exit;
  result:=Files.GetFullName('.');
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
  next,root:String8;
  child:TUIElement;
 begin
  try
   next:=path;
   if next<>'' then begin
    if Files.IsPathRelative(next) and (fFolder<>'') then next:=JoinPath(fFolder,next);
    next:=Files.GetFullName(JoinPath(next,'.'));
    if not Apus.Files.Folder.Exists(next) then begin
     ShowError(Template(texts.folderNotFound,next));
     exit;
    end;
   end;
   fFolder:=next;
   // A name picked from the old listing means nothing in Open; a typed or Save name stays
   if (Mode=fdOpen) and (pickedName<>'') and (nameEdit.text=pickedName) then nameEdit.text:='';
   pickedName:='';
   for child in driveBar.children do if child is TDriveButton then begin
    root:=child.attributes.Item['path'];
    TDriveButton(child).active:=(fFolder<>'') and
      (Pos(UTF8.ToLower(root),UTF8.ToLower(JoinPath(fFolder,'')))=1);
   end;
   if fFolder='' then upButton.flags.enabled:=false
    else upButton.flags.enabled:=not SamePath(ParentFolder(fFolder),fFolder);
   pathEdit.text:=fFolder;
   pathEdit.cursorPos:=length(pathEdit.realText); // a long path shows its tail
   Edited;
   Refresh;
   TDirectoryOutline(directoryOutline).Build(fFolder);
   if (locationsList.selected>=0) and
      not SamePath(LocationPath(locationsList.RowTag(locationsList.selected)),fFolder) then
    locationsList.selected:=-1;
   UpdatePinButton;
  except
   on e:Exception do ShowError(String8(e.Message));
  end;
 end;

 // The folder is read once: type chips and the name mask only filter that listing.
 // The selected file stays selected while it passes the filters of the same folder.
 procedure TUIFileDialog.Refresh(reload:boolean);
 var
  masks,query,lowName,focusName:String8;
  keep:Strings8;
  keepRows:IntArray;
  i,row,focusRow:integer;
 begin
  keep:=nil;
  focusName:='';
  if SamePath(listedFolder,fFolder) then begin
   for row in table.SelectedRows do
    keep:=keep+[items[table.RowTag(row)].name];
   if table.selected>=0 then focusName:=items[table.RowTag(table.selected)].name;
  end;
  table.ClearRows;
  if reload or not SamePath(listedFolder,fFolder) then begin
   if fFolder='' then items:=nil else items:=Apus.Files.Folder.ListItems(fFolder);
   listedFolder:=fFolder;
  end;
  masks:='';
  if not allFiles then
   for i:=0 to high(activeTypes) do
    if allTypes or activeTypes[i] then masks:=masks+';'+UTF8.ToLower(fRequest.types[i].masks);
  query:=UTF8.ToLower(nameMask);
  keepRows:=nil;
  focusRow:=-1;
  for i:=0 to high(items) do with items[i] do begin
   if info.isDirectory then continue;
   if hidden and not showHidden then continue;
   lowName:=UTF8.ToLower(name);
   if (masks<>'') and not MatchesMasks(lowName,masks) then continue;
   if (query<>'') and not MatchesNameMasks(lowName,query) then continue;
   row:=table.AddRow(i);
   table.SetCell(row,0,name);
   table.SetCell(row,1,String8(FormatDateTime('yyyy-mm-dd hh:nn',info.timestamp)),info.timestamp);
   table.SetCell(row,2,FileSizeText(info.size),info.size);
   if PathIndex(keep,name)>=0 then keepRows:=keepRows+[row];
   if (focusName<>'') and (name=focusName) then focusRow:=row;
  end;
  // the name field and the preview already show the files that pass the filters
  restoring:=true;
  try
   for row in keepRows do table.SetRowSelected(row,true);
   if focusRow>=0 then table.FocusRow(focusRow);
  finally
   restoring:=false;
  end;
  if length(keepRows)<length(keep) then SelectionChanged(table,table.selected);
  if (focusRow<0) and Assigned(onSelect) then onSelect(self,'');
 end;

 procedure TUIFileDialog.Reload;
 begin
  TDirectoryOutline(directoryOutline).Reload;
  Refresh(true);
  TDirectoryOutline(directoryOutline).Build(fFolder);
 end;

 // A typed mask filters the listing at once, a mask with a folder waits for Enter; any other
 // typed text removes the mask. A name the table puts into the field keeps the mask.
 procedure TUIFileDialog.NameTyped;
 var
  value:String8;
 begin
  Edited;
  value:=nameEdit.text;
  if not HasWildcards(value) then SetNameMask('')
   else if Files.GetName(value)=value then SetNameMask(value);
 end;

 procedure TUIFileDialog.SetNameMask(const mask:String8);
 begin
  if mask=nameMask then exit;
  nameMask:=mask;
  UpdateNameColumn;
  // the typed text no longer names the selected files: Refresh must not put them back
  restoring:=true;
  try
   table.selected:=-1;
  finally
   restoring:=false;
  end;
  Refresh(false);
 end;

 // Enter on a mask opens its folder, if it has one, and goes to the first file it lists
 procedure TUIFileDialog.EnterNameMask;
 var
  value,mask,dir:String8;
 begin
  value:=nameEdit.text;
  mask:=Files.GetName(value);
  if mask<>value then begin
   dir:=Files.GetDir(value);
   if Files.IsPathRelative(dir) and (fFolder<>'') then dir:=JoinPath(fFolder,dir);
   dir:=Files.GetFullName(JoinPath(dir,'.'));
   if HasWildcards(dir) or not Apus.Files.Folder.Exists(dir) then begin
    ShowError(Template(texts.folderNotFound,dir));
    exit;
   end;
   SetFolder(dir);
   nameEdit.text:=mask;
  end;
  SetNameMask(mask);
  if table.RowCount=0 then exit;
  table.SetFocus;
  table.selected:=table.RowAt(0);
 end;

 // The caption of the name column shows the mask: the name field may hold a file name
 procedure TUIFileDialog.UpdateNameColumn;
 begin
  if nameMask='' then table.columns[0].caption:=texts.nameColumn
   else table.columns[0].caption:=Template(texts.maskColumn,nameMask);
 end;

 // The short caption of a type: its extension in capitals, or the title
 function TypeCaption(const fileType:TFileType):String8;
 begin
  result:=fileType.ext;
  if result<>'' then result:=UTF8.ToUpper(copy(result,2,length(result))) else result:=fileType.title;
 end;

 // No chips for a request without types: it lists any file
 procedure TUIFileDialog.BuildTypes;
 var
  i:integer;
 function Chip(const suffix,caption,hint:String8;index:integer;toggled:boolean):TUIToggleButton;
 var
  b:TTypeChip;
 begin
  b:=TTypeChip.Create(48,28,typeBar,name+'\Type'+suffix);
  b.drawer:=DrawDialogButton;
  b.styleInfo:=BUTTON_STYLE;
  b.Setup(caption,toggled);
  b.dialog:=self; b.index:=index;
  b.flags.canHaveFocus:=false;
  b.hint:=hint;
  result:=b;
 end;
 begin
  typeBar.DeleteChildren;
  typeButtons:=nil;
  allTypeButton:=nil;
  allFilesButton:=nil;
  if length(fRequest.types)=0 then exit;
  allTypeButton:=Chip('All',texts.allTypes,texts.allTypesHint,FD_FILTER_SUPPORTED,allTypes);
  SetLength(typeButtons,length(fRequest.types));
  for i:=0 to high(fRequest.types) do
   with fRequest.types[i] do
    typeButtons[i]:=Chip(Conv.ToStr(i),TypeCaption(fRequest.types[i]),Template(texts.typeHint,title+' ('+masks+')'),
      i,activeTypes[i]);
  if fdoAllFiles in fRequest.options then
   allFilesButton:=Chip('AllFiles',texts.allFiles,texts.allFilesHint,FD_FILTER_ALL_FILES,allFiles);
 end;

 procedure TUIFileDialog.UpdateTypes;
 var
  i:integer;
 begin
  if allTypeButton<>nil then allTypeButton.toggled:=allTypes;
  if allFilesButton<>nil then allFilesButton.toggled:=allFiles;
  for i:=0 to high(typeButtons) do typeButtons[i].toggled:=activeTypes[i];
 end;

 // A plain click selects only this chip, Ctrl+click adds or removes a type. All and the chip
 // of any file exclude the types, and a choice left empty falls back to All: the filter is
 // never empty. The chips only filter the listing: the format of Save is chosen separately.
 procedure TUIFileDialog.TypeClicked(index:integer;active:boolean);
 var
  i:integer;
  ctrl,any:boolean;
 begin
  ctrl:=(GetWindow.shiftState and sscCtrl)<>0;
  if (index<0) or not ctrl then
   for i:=0 to high(activeTypes) do activeTypes[i]:=false;
  if index>=0 then activeTypes[index]:=active or not ctrl;
  any:=false;
  for i:=0 to high(activeTypes) do any:=any or activeTypes[i];
  allFiles:=not any and (index=FD_FILTER_ALL_FILES);
  allTypes:=not any and not allFiles;
  UpdateTypes;
  Edited;
  Refresh(false);
 end;

 procedure TUIFileDialog.BuildFormats;
 var
  i:integer;
  item:TFormatItem;
 begin
  formatMenu.Clear;
  if Mode<>fdSave then exit;
  for i:=0 to high(fRequest.types) do begin
   item:=TFormatItem.Create(formatMenu,fRequest.types[i].title,'',formatMenu.name+'\'+Conv.ToStr(i));
   item.dialog:=self;
   item.index:=i;
  end;
  if fSaveType>=0 then formatButton.caption:=TypeCaption(fRequest.types[fSaveType]);
 end;

 procedure TUIFileDialog.ShowFormats;
 begin
  if formatMenu.IsOpen then exit;
  formatMenu.OpenBelow(formatButton);
  // the keyboard starts from the format in use
  if fSaveType>=0 then formatMenu.current:=TUIMenuItem(formatMenu.children[fSaveType]);
 end;

 // The index of the first type whose masks match the name, the save format first; -1 - none
 function TUIFileDialog.TypeOfName(const fileName:String8):integer;
 var
  lowName:String8;
  i:integer;
 begin
  lowName:=UTF8.ToLower(Files.GetName(fileName));
  if (fSaveType>=0) and MatchesMasks(lowName,UTF8.ToLower(fRequest.types[fSaveType].masks)) then
   exit(fSaveType);
  for i:=0 to high(fRequest.types) do
   if MatchesMasks(lowName,UTF8.ToLower(fRequest.types[i].masks)) then exit(i);
  result:=-1;
 end;

 // A name of the old format gets the extension of the new one; a name of no listed type
 // gets it on Confirm
 procedure TUIFileDialog.SetSaveType(index:integer);
 var
  fileName,ext:String8;
 begin
  if (Mode<>fdSave) or (index<0) or (index>high(fRequest.types)) or (index=fSaveType) then exit;
  fileName:=nameEdit.text;
  ext:=fRequest.types[index].ext;
  if (ext<>'') and (ext[1]<>'.') then ext:='.'+ext;
  if (ext<>'') and not HasWildcards(fileName) and (Files.GetExt(fileName)<>'') and
     (TypeOfName(fileName)=fSaveType) then
   nameEdit.text:=Files.ChangeExt(fileName,ext);
  fSaveType:=index;
  formatButton.caption:=TypeCaption(fRequest.types[index]);
  Edited;
  if Assigned(onSaveTypeChanged) then onSaveTypeChanged(self,index);
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
   b.styleInfo:=BUTTON_STYLE;
   b.caption:=roots[i];
   b.attributes.Item['path']:=JoinPath(roots[i],'');
   b.handler:=DriveClicked;
  end;
 end;

 procedure TUIFileDialog.DriveClicked;
 begin
  SetFolder(TUIButton.Sender.attributes.Item['path']);
 end;

 procedure TUIFileDialog.RememberFolder(const path:String8);
 var
  index,i:integer;
 begin
  // Only a successful file operation records a directory. Walking the tree, clicking
  // a drive or entering a path leaves both lists untouched; drive roots stay on the drive buttons.
  if (path='') or SamePath(ParentFolder(path),path) then exit;
  index:=PathIndex(recentFolders,path);
  if index=0 then exit;
  if index>0 then RemovePath(recentFolders,index);
  SetLength(recentFolders,Math.Min(12,length(recentFolders)+1));
  for i:=high(recentFolders) downto 1 do recentFolders[i]:=recentFolders[i-1];
  recentFolders[0]:=path;
  if Assigned(onLocationsChanged) then onLocationsChanged;
 end;

 procedure TUIFileDialog.BuildLocations(reset:boolean);
 var
  list:TLocationsList;
  i,row,selectedRow:integer;
  oldScroll:single;
  selectedPath:String8;
 begin
  list:=TLocationsList(locationsList);
  selectedPath:=LocationPath(list.RowTag(list.selected));
  oldScroll:=list.ScrollPos;
  if reset then begin
   list.paths:=nil;
   selectedPath:='';
   oldScroll:=0;
  end;
  // Explicit edits may remove or append a row, but changing a star never moves
  // existing paths. Favorites-first ordering is applied only for a new request.
  for i:=high(list.paths) downto 0 do
   if (PathIndex(favoriteFolders,list.paths[i])<0) and (PathIndex(recentFolders,list.paths[i])<0) then
    RemovePath(list.paths,i);
  for i:=0 to high(favoriteFolders) do
   if PathIndex(list.paths,favoriteFolders[i])<0 then list.paths:=list.paths+[favoriteFolders[i]];
  for i:=0 to high(recentFolders) do
   if PathIndex(list.paths,recentFolders[i])<0 then list.paths:=list.paths+[recentFolders[i]];
  list.ClearRows;
  selectedRow:=-1;
  for i:=0 to high(list.paths) do begin
   row:=list.AddRow(i);
   list.SetCell(row,0,list.paths[i]);
   if SamePath(list.paths[i],selectedPath) then selectedRow:=row;
  end;
  list.selected:=selectedRow;
  list.scrollerV.SetValue(oldScroll);
  UpdatePinButton;
 end;

 procedure TUIFileDialog.UpdatePinButton;
 begin
  pinButton.flags.enabled:=fFolder<>'';
  if PathIndex(favoriteFolders,fFolder)>=0 then pinButton.hint:=texts.unpinHint
   else pinButton.hint:=texts.pinHint;
 end;

 function TUIFileDialog.LocationPath(tag:NativeInt):String8;
 var
  list:TLocationsList;
 begin
  result:='';
  list:=TLocationsList(locationsList);
  if (tag>=0) and (tag<length(list.paths)) then result:=list.paths[tag];
 end;

 procedure TUIFileDialog.LocationAction(tag:NativeInt;remove:boolean);
 var
  path:String8;
  index:integer;
  oldScroll:single;
 begin
  oldScroll:=locationsList.ScrollPos;
  path:=LocationPath(tag);
  if path='' then exit;
  if remove then begin
   index:=PathIndex(favoriteFolders,path);
   if index>=0 then RemovePath(favoriteFolders,index);
   index:=PathIndex(recentFolders,path);
   if index>=0 then RemovePath(recentFolders,index);
  end else begin
   index:=PathIndex(favoriteFolders,path);
   if index<0 then favoriteFolders:=favoriteFolders+[path]
    else RemovePath(favoriteFolders,index);
  end;
  BuildLocations;
  locationsList.scrollerV.SetValue(oldScroll);
  if Assigned(onLocationsChanged) then onLocationsChanged;
 end;

 procedure TUIFileDialog.LocationSelected(sender:TUITable;row:integer);
 var
  path:String8;
 begin
  if row<0 then exit;
  path:=LocationPath(sender.RowTag(row));
  if (path<>'') and not SamePath(path,fFolder) then SetFolder(path);
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
  parent:=Files.GetFullName(JoinPath(fFolder,'..'));
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

 function TUIFileDialog.RowItem(row:integer):integer;
 begin
  result:=table.RowTag(row);
  if (result<0) or (result>=length(items)) or items[result].info.isDirectory then result:=-1;
 end;

 // The focused file goes to the preview; the name field follows the set of selected files
 procedure TUIFileDialog.RowSelected(sender:TUITable;row:integer);
 var
  index:integer;
  path:String8;
 begin
  if restoring then exit;
  path:='';
  index:=RowItem(row);
  if index>=0 then path:=ItemPath(index);
  if Assigned(onSelect) then onSelect(self,path);
 end;

 // One file - its name, several - their names in quotes. Nothing selected keeps the name.
 procedure TUIFileDialog.SelectionChanged(sender:TUITable;row:integer);
 var
  rows:IntArray;
  index,r:integer;
  names:String8;
 begin
  if restoring then exit;
  rows:=table.SelectedRows;
  if length(rows)=0 then exit;
  Edited;
  if length(rows)=1 then begin
   index:=RowItem(rows[0]);
   if index<0 then exit;
   names:=items[index].name;
  end else begin
   names:='';
   for r in rows do begin
    index:=RowItem(r);
    if index<0 then continue;
    if names<>'' then names:=names+' ';
    names:=names+'"'+items[index].name+'"';
   end;
  end;
  nameEdit.text:=names;
  pickedName:=names;
 end;

 procedure TUIFileDialog.RowActivated(sender:TUITable;row:integer);
 var
  index:integer;
 begin
  index:=RowItem(row);
  if index<0 then exit;
  // Enter on one of several selected files opens them all; a double click has selected
  // its row alone with the first click
  if not table.IsSelected(row) or (table.SelectedCount<=1) then begin
   table.selected:=row;
   nameEdit.text:=items[index].name;
   pickedName:=nameEdit.text;
  end;
  Confirm;
 end;

 procedure TUIFileDialog.Confirm;
 var
  value:TFileDialogResult;
  path,ext:String8;
  row,index:integer;
  exists:boolean;
 begin
  if finished then exit;
  try
   // A typed mask filters, it never names a file; a name the table put in is a name
   if (nameEdit.text<>pickedName) and HasWildcards(nameEdit.text) then begin
    EnterNameMask;
    exit;
   end;
   value:=Default(TFileDialogResult);
   value.typeIndex:=-1;
   // Several files: the selection itself, the quoted names only show it
   if (table.SelectedCount>1) and (nameEdit.text=pickedName) then begin
    for row in table.SelectedRows do begin
     index:=RowItem(row);
     if index<0 then continue;
     path:=ItemPath(index);
     if not NativeFileExists(path) then begin ShowError(Template(texts.fileNotFound,path)); exit; end;
     value.paths:=value.paths+[path];
    end;
    if length(value.paths)=0 then exit;
   end else begin
    path:=nameEdit.text;
    if path='' then begin ShowError(texts.enterName); exit; end;
    if Files.IsPathRelative(path) then begin
     if fFolder='' then begin ShowError(texts.chooseFolder); exit; end;
     path:=JoinPath(fFolder,path);
    end;
    path:=Files.GetFullName(path);
    if Apus.Files.Folder.Exists(path) then begin
     SetFolder(path);
     nameEdit.text:='';
     exit;
    end;
    if (Mode=fdSave) and (fSaveType>=0) then begin
     // a name of another listed type switches the format, a name of none gets the extension
     index:=TypeOfName(path);
     if index>=0 then SetSaveType(index)
     else begin
      ext:=fRequest.types[fSaveType].ext;
      if (ext<>'') and (ext[1]<>'.') then ext:='.'+ext;
      path:=path+ext;
     end;
     value.typeIndex:=fSaveType;
    end;
    if Apus.Files.Folder.Exists(path) then begin ShowError(texts.nameIsFolder); exit; end;
    exists:=NativeFileExists(path);
    if (Mode=fdOpen) and not exists then begin ShowError(Template(texts.fileNotFound,path)); exit; end;
    if not Apus.Files.Folder.Exists(Files.GetDir(path)) then begin
     ShowError(texts.destinationNotFound); exit;
    end;
    if (Mode=fdSave) and exists and (overwritePath<>path) and
       not (fdoNoOverwritePrompt in fRequest.options) then begin
     overwritePath:=path;
     ShowError(Template(texts.confirmOverwrite,acceptButton.caption));
     exit;
    end;
    value.paths:=[path];
   end;
   value.accepted:=true;
   value.path:=value.paths[0];
   if Assigned(onValidate) and not onValidate(self,value) then exit;
   RememberFolder(Files.GetDir(value.path));
   Finish(value);
  except
   on e:Exception do ShowError(String8(e.Message));
  end;
 end;

 procedure TUIFileDialog.Cancel;
 var
  value:TFileDialogResult;
 begin
  value:=Default(TFileDialogResult);
  value.typeIndex:=-1;
  if Mode=fdSave then value.typeIndex:=fSaveType;
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
  result:=shiftstate=0;
  if not result then exit;
  case TKey(keycode) of
   TKey.Escape:Cancel;
   TKey.F5:Reload;
   else result:=false;
  end;
 end;

 constructor TFileDialogScene.Create(const sceneName:String8;wnd:TWindow);
 begin
  inherited Create(string(sceneName)+'Scene',false,wnd);
  zOrder:=100;
  UI.order:=zOrder;
  frame:=TUIWindow.Create(1004,580,true,UI,sceneName+'\Frame','Open');
  frame.minW:=680; frame.minH:=420;
  dialog:=TUIFileDialog.Create(frame.clientWidth,frame.clientHeight,frame,sceneName);
  dialog.SetAnchors(anchorAll);
  dialog.host:=self;
  frame.drawer:=DrawDialogFrame;
  frame.styleInfo:=FRAME_STYLE;
  closeButton:=TDialogButton.Create(30,22,frame,sceneName+'\Close');
  TDialogButton(closeButton).handler:=dialog.Cancel;
  closeButton.drawer:=DrawCloseButton;
  closeButton.styleInfo:=CLOSE_STYLE;
  closeButton.flags.noParentClip:=true;
  closeButton.flags.canHaveFocus:=false;
  closeButton.hint:='Cancel';
  preferredW:=1020; preferredH:=610;
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
  frame.Resize(Math.Min(preferredW,UI.clientWidth-16),Math.Min(preferredH,UI.clientHeight-16));
  // TUIWindow's edge dragging uses a top-left pivot. Centering with pivotCenter
  // makes both edges move when only the width changes.
  frame.SetPos((UI.clientWidth-frame.size.x)/2,(UI.clientHeight-frame.size.y)/2,pivotTopLeft);
  frame.SetAnchors(0.5,0.5,0.5,0.5);
  closeButton.SetPos(frame.clientWidth+frame.padding.Right-2,-frame.padding.Top+(frame.padding.Top-22)/2,pivotTopRight);
  closeButton.SetAnchors(1,0,1,0);
  dialog.LayoutControls;
 end;

 procedure TFileDialogScene.Open(modal:boolean);
 var
  f:TUIElement;
 begin
  if IsActive then exit;
  onResize;
  if dialog.request.title<>'' then frame.caption:=dialog.request.title
   else if dialog.request.mode=fdOpen then frame.caption:=dialog.texts.openTitle
   else frame.caption:=dialog.texts.saveTitle;
  closeButton.hint:=dialog.texts.cancel;
  openedLayout:=Layout;
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
  // the size the user gave the frame is kept for the next request
  preferredW:=frame.size.x; preferredH:=frame.size.y;
  TShowWindowEffect.Create(self,0,sweHide,0);
  FreeAndNil(effect);
  f:=prevFocus;
  prevFocus:=nil;
  if f<>nil then begin
   if not f.deleted and f.IsVisible and f.IsEnabled then f.SetFocus;
   f.Release;
  end;
  if Assigned(onLayoutChanged) and not SameLayout(Layout,openedLayout) then onLayoutChanged;
 end;

 function SameLayout(const a,b:TFileDialogLayout):boolean;
 var
  i:integer;
 begin
  result:=(round(a.width)=round(b.width)) and (round(a.height)=round(b.height)) and
    (a.sortColumn=b.sortColumn) and (a.sortDescending=b.sortDescending) and
    (length(a.columns)=length(b.columns));
  if result then
   for i:=0 to high(a.columns) do
    if round(a.columns[i])<>round(b.columns[i]) then exit(false);
 end;

 // A flexible column is saved as 0: it takes the room the others leave
 function TFileDialogScene.Layout:TFileDialogLayout;
 var
  table:TUITable;
  i:integer;
 begin
  table:=dialog.table;
  result.width:=preferredW;
  result.height:=preferredH;
  if IsActive then begin
   result.width:=frame.size.x;
   result.height:=frame.size.y;
  end;
  SetLength(result.columns,length(table.columns));
  for i:=0 to high(table.columns) do
   if table.columns[i].flexible then result.columns[i]:=0
    else result.columns[i]:=table.ColumnWidth(i);
  result.sortColumn:=table.sortColumn;
  result.sortDescending:=table.sortDescending;
 end;

 procedure TFileDialogScene.SetLayout(const value:TFileDialogLayout);
 var
  table:TUITable;
  i:integer;
 begin
  table:=dialog.table;
  if value.width>0 then preferredW:=Math.Max(value.width,frame.minW);
  if value.height>0 then preferredH:=Math.Max(value.height,frame.minH);
  for i:=0 to Math.Min(high(value.columns),high(table.columns)) do
   if table.columns[i].flexible then table.SetColumnWidth(i,0)
    else if value.columns[i]>0 then table.SetColumnWidth(i,value.columns[i]);
  if (value.sortColumn>=0) and (value.sortColumn<=high(table.columns)) and
     (table.columns[value.sortColumn].sort<>tsNone) then
   table.SortBy(value.sortColumn,value.sortDescending)
  else table.SortBy(0);
  if IsActive then onResize;
 end;

 procedure DefineToken(const name,value:String8);
 begin
  if not HasToken(name) then SetToken(name,value);
 end;

initialization
 DefineToken('file-dialog-fill','&surface');
 DefineToken('file-dialog-panel','&surface-alt');
 DefineToken('file-dialog-header','&overlay');
 DefineToken('file-dialog-hover','&control');
 DefineToken('file-dialog-border','&border-dark');
 DefineToken('file-dialog-text','&text');
 DefineToken('file-dialog-muted','&text-muted');
 DefineToken('file-dialog-disabled','&text-muted');
 DefineToken('file-dialog-selection','&accent');
 DefineToken('file-dialog-selection-text','&accent-text');
 DefineToken('file-dialog-accent','&accent');
 DefineToken('file-dialog-favorite','&warning');
 DefineToken('file-dialog-error','&danger');
 DefineToken('file-dialog-font-size','9');
end.
