// UI inspector (like F12 in a browser): a separate engine window that shows the UI tree
// of another window and the published fields of the selected element, live.
//
// Linked by GameApp under {$IFDEF DEBUG}; opened with Ctrl+Shift+I in the window to
// inspect or with the console command `inspector`. Fields are the console publication
// (Apus.Engine.UIScript): values are read and written through the same TVarClass.
//
// Threads: the inspector works in its own window's thread. Under its own window lock it
// takes the lock of the inspected window (TWindow.Lock), reads into its own data and
// writes the edits; the inspected window never takes the inspector's lock.
// Design: Work/ui_inspector.md
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.UIInspector;
interface
uses Apus.Core, Apus.Publics, Apus.Engine.UITypes;

type
 {$SCOPEDENUMS ON}
 // How a field value is edited
 TFieldEdit=(Text,     // edit box
             Bool,     // check box
             Enum,     // list of values (TVarTypeEnum.ListValues)
             Ref,      // reference to an element: a click selects it
             ReadOnly);
 {$SCOPEDENUMS OFF}

 // Line of the element tree
 TTreeRow=record
  element:TUIElement; // not held: compare only, or find in the tree under the window lock
  depth:integer;
  hasChildren,expanded:boolean;
  text:String8;
 end;
 TTreeRows=array of TTreeRow;

 // Line of the field table
 TFieldRow=record
  name,value:String8;
  edit:TFieldEdit;
  ref:TUIElement; // Ref: the element the field points to (not held)
 end;
 TFieldRows=array of TFieldRow;

 // Register the hotkey, the console command and the window handlers (control thread)
 procedure InitInspector;

 // --- Core: the caller holds the lock of the elements' window ---
 // Rows of the trees under the roots: children of an expanded element follow it
 function BuildTree(const roots:array of TUIElement):TTreeRows;
 function FindInTree(const roots:array of TUIElement;e:TUIElement):boolean;
 procedure SetExpanded(e:TUIElement;expanded:boolean);
 function IsExpanded(e:TUIElement):boolean;
 // Published fields of the element with their current values
 function ReadFields(e:TUIElement):TFieldRows;
 // Write a field as the console does; raises EWarning on a bad name or value
 procedure WriteField(e:TUIElement;const name,value:String8);

 // --- Selection ---
 // Select an element (nil - nothing): the inspector holds it (Acquire) until another one
 // is selected. Inspector's thread, under the lock of the element's window
 procedure SetSelected(e:TUIElement);
 // The selected element; nil if nothing is selected or it was removed. Inspector's thread
 function SelectedElement:TUIElement;
 // The selected element held for another thread (Release it); nil - nothing or removed
 function HoldSelected:TUIElement;

implementation
uses SysUtils, Types, Apus.EventMan, Apus.Strings, Apus.Log, Apus.Threads, Apus.Engine.API,
  Apus.Engine.Window, Apus.Engine.Scene, Apus.Engine.UIScene, Apus.Engine.UIWidgets,
  Apus.Engine.UIScript, Apus.Engine.CmdProc;

const
 OPEN_EVENT='Engine\Inspector\Open';
 INSPECTOR_NAME='Inspector'; // window name
 TREE_REFRESH_MS=500; // the tree is rebuilt this often (the fields - every frame)
 // own sizes in the root's units (the root has the scale of the window's DPI): the
 // inspected app's theme and UI scale must not change the inspector
 FONT_SIZE='7.5'; // style value: a fraction gives 1 pixel steps at the scale 2
 ROW_HEIGHT=18;
 HEADER_HEIGHT=18;
 // own literal colors: the inspected app's theme must not change the inspector
 COLOR_BACK=$FF1E2228;
 COLOR_PANEL=$FF262B33;
 COLOR_TEXT=$FFD8DCE0;
 COLOR_DIM=$FF7C848C;      // hidden elements, read-only values
 COLOR_DISABLED=$FFB08070;
 COLOR_NAME=$FF8FB4D8;     // field names
 COLOR_REF=$FF9CD49C;      // references to elements
 COLOR_SELECTED=$FF34506C;
 COLOR_HOVER=$FF2E3540;
 COLOR_ERROR=$FFFF8080;

type
 TEnumClass=class of TVarTypeEnum;

 // Element tree: draws the rows itself (indents, expand marks), a click on the mark
 // expands or collapses, a click elsewhere selects the element
 TInspectorTree=class(TUIListBox)
  rows:TTreeRows;
  constructor Create(width,height:single;parent:TUIElement);
  procedure onMouseButtons(button:byte;state:boolean); override;
  procedure SelectLine(line:integer); override;
  function Indent:single;
 end;

 // Field table: "name - value" lines drawn by the table itself; editors appear over a
 // value only when it is clicked
 TInspectorTable=class(TUIListBox)
  fields:TFieldRows;
  nameWidth:single;
  constructor Create(width,height:single;parent:TUIElement);
  procedure onMouseButtons(button:byte;state:boolean); override;
 end;

 // List of enum values, opened under the edited value
 TInspectorEnumList=class(TUIListBox)
  procedure SelectLine(line:integer); override;
 end;

 TInspectorScene=class(TUIScene)
  header:TUILabel;
  tree:TInspectorTree;
  table:TInspectorTable;
  editor:TUIEditBox;          // text editor over a value
  enumList:TInspectorEnumList;
  boxes:array of TUICheckBox; // check boxes of the bool fields (nil for other fields)
  boxShown:array of boolean;  // what each check box showed: a difference = the user's click
  editField:String8;          // the field being edited ('' - none)
  shownElement:TUIElement;    // the element the field rows were built for (not held)
  lastError:String8;
  nextTreeTime:int64;
  constructor Create(wnd:TWindow);
  function OwnScale:single;
  function Process:boolean; override;
  procedure Render; override;
  procedure Refresh;
  procedure RebuildBoxes;
  procedure PlaceEditors;
  procedure BeginEdit(row:integer);
  procedure EndEdit;
  procedure Commit(const name,value:String8);
  procedure SelectElement(e:TUIElement); // under no lock: finds e in the inspected tree first
 end;

var
 selLock:TLock;
 selected:TUIElement;     // held by Acquire
 expandedList:array of pointer;
 inspWindow:TWindow;      // nil once it starts closing (ENGINE\WINDOW\CLOSED)
 inspScene:TInspectorScene; // freed with the window
 target:TWindow;          // the inspected window (held by Acquire); inspector's thread only

{ Core }

function ElementVarClass:TVarClassStruct;
 begin
  result:=TVarClassStruct(GetVarTypeFor('TUIElement'));
 end;

procedure SetExpanded(e:TUIElement;expanded:boolean);
 var
  i,n:integer;
 begin
  n:=length(expandedList);
  for i:=0 to n-1 do
   if expandedList[i]=pointer(e) then begin
    if not expanded then begin
     expandedList[i]:=expandedList[n-1];
     SetLength(expandedList,n-1);
    end;
    exit;
   end;
  if expanded then begin
   SetLength(expandedList,n+1);
   expandedList[n]:=e;
  end;
 end;

function IsExpanded(e:TUIElement):boolean;
 var
  i:integer;
 begin
  for i:=0 to high(expandedList) do
   if expandedList[i]=pointer(e) then exit(true);
  result:=false;
 end;

function ElementText(e:TUIElement):String8;
 begin
  result:=String8(e.ClassName);
  if e.name<>'' then result:=result+' '''+e.name+'''';
  if not e.flags.visible then result:=result+' [hidden]';
  if not e.flags.enabled then result:=result+' [disabled]';
 end;

function BuildTree(const roots:array of TUIElement):TTreeRows;
 var
  n:integer;
  rows:TTreeRows;
 procedure Add(e:TUIElement;depth:integer);
  var
   i:integer;
  begin
   if n>=length(rows) then SetLength(rows,n*2+16);
   rows[n].element:=e;
   rows[n].depth:=depth;
   rows[n].hasChildren:=length(e.children)>0;
   rows[n].expanded:=rows[n].hasChildren and IsExpanded(e);
   rows[n].text:=ElementText(e);
   inc(n);
   if rows[n-1].expanded then
    for i:=0 to high(e.children) do Add(e.children[i],depth+1);
  end;
 var
  i:integer;
 begin
  n:=0;
  rows:=nil;
  for i:=0 to high(roots) do Add(roots[i],0);
  SetLength(rows,n);
  result:=rows;
 end;

function FindInTree(const roots:array of TUIElement;e:TUIElement):boolean;
 function Find(c:TUIElement):boolean;
  var
   i:integer;
  begin
   if c=e then exit(true);
   for i:=0 to high(c.children) do
    if Find(c.children[i]) then exit(true);
   result:=false;
  end;
 var
  i:integer;
 begin
  if e=nil then exit(false);
  for i:=0 to high(roots) do
   if Find(roots[i]) then exit(true);
  result:=false;
 end;

function EditOf(varClass:TVarClass):TFieldEdit;
 begin
  if varClass.InheritsFrom(TVarTypeBool) then result:=TFieldEdit.Bool
  else if varClass.InheritsFrom(TVarTypeEnum) then result:=TFieldEdit.Enum
  else if varClass.InheritsFrom(TVarTypeElementRef) then result:=TFieldEdit.Ref
  else if varClass.InheritsFrom(TVarTypeElements) or varClass.InheritsFrom(TVarTypeRect) then
   result:=TFieldEdit.ReadOnly
  else result:=TFieldEdit.Text;
 end;

function ReadFields(e:TUIElement):TFieldRows;
 var
  vc:TVarClassStruct;
  fc:TVarClass;
  names:Strings8;
  p:pointer;
  i:integer;
 begin
  result:=nil;
  if e=nil then exit;
  vc:=ElementVarClass;
  names:=vc.ListFieldsOf(e).Split(',');
  SetLength(result,length(names));
  for i:=0 to high(names) do begin
   result[i].name:=names[i];
   result[i].edit:=TFieldEdit.ReadOnly;
   result[i].ref:=nil;
   p:=vc.GetField(e,names[i],fc);
   if (p=nil) or (fc=nil) then begin
    result[i].value:='<unknown>';
    continue;
   end;
   result[i].edit:=EditOf(fc);
   try
    result[i].value:=fc.GetValue(p);
   except
    on ex:Exception do result[i].value:='<'+String8(ex.Message)+'>';
   end;
   if result[i].edit=TFieldEdit.Ref then result[i].ref:=TUIElement(p^);
  end;
 end;

procedure WriteField(e:TUIElement;const name,value:String8);
 var
  fc:TVarClass;
  p:pointer;
 begin
  p:=ElementVarClass.GetField(e,name,fc);
  if (p=nil) or (fc=nil) then raise EWarning.Create('No field '+string(name));
  fc.SetValue(p,value);
 end;

// Values of an enum field; under the lock of the element's window
function EnumValues(e:TUIElement;const name:String8):String8;
 var
  fc:TVarClass;
 begin
  result:='';
  if e=nil then exit;
  if (ElementVarClass.GetField(e,name,fc)<>nil) and (fc<>nil) and fc.InheritsFrom(TVarTypeEnum) then
   result:=TEnumClass(fc).ListValues;
 end;

procedure SetSelected(e:TUIElement);
 var
  old:TUIElement;
 begin
  if (e<>nil) and not e.Acquire then e:=nil;
  if e<>nil then Log.Msg('UI inspector: selected %s',[e.ObjInfo]);
  selLock.Enter;
  old:=selected;
  selected:=e;
  selLock.Leave;
  if old<>nil then old.Release;
 end;

function SelectedElement:TUIElement;
 begin
  result:=selected;
  if (result<>nil) and result.deleted then result:=nil;
 end;

function HoldSelected:TUIElement;
 begin
  selLock.Enter;
  result:=selected;
  if (result<>nil) and not result.Acquire then result:=nil;
  selLock.Leave;
 end;

{ Inspected window }

// UI roots of the window's scenes; under its lock
function TargetRoots(wnd:TWindow):TUIElements;
 var
  i,n:integer;
 begin
  result:=nil;
  n:=0;
  for i:=0 to high(wnd.scenes) do
   if (wnd.scenes[i] is TUIScene) and (TUIScene(wnd.scenes[i]).UI<>nil) then begin
    SetLength(result,n+1);
    result[n]:=TUIScene(wnd.scenes[i]).UI;
    inc(n);
   end;
 end;

// Inspector's thread: inspect another window (wnd is held; nil - none)
procedure SetTarget(wnd:TWindow);
 var
  roots:TUIElements;
  i:integer;
 begin
  SetSelected(nil);
  if target<>nil then target.Release;
  target:=wnd;
  if target<>nil then Log.Msg('UI inspector: inspecting window %s',[target.name]);
  expandedList:=nil;
  if (target<>nil) and target.Lock then
   try
    roots:=TargetRoots(target);
    for i:=0 to high(roots) do SetExpanded(roots[i],true);
   finally
    target.Unlock;
   end;
  if inspScene<>nil then begin
   inspScene.EndEdit;
   inspScene.nextTreeTime:=0;
  end;
 end;

// Inspector's thread at every frame start (it queues itself again): lets go of the
// inspected window once it starts closing - otherwise the held window would make its
// close wait. `window` is the inspector's one: inspWindow is nil while it closes
procedure WatchCall(param:pointer);
 begin
  if (target<>nil) and (target.closing or window.closing) then SetTarget(nil);
  if not window.closing then window.QueueCall(WatchCall);
 end;

// Inspector's thread (TWindow.QueueCall): inspect the window passed in param (held)
procedure ShowCall(param:pointer);
 begin
  if window.closing then begin
   TWindow(param).Release;
   exit;
  end;
  SetTarget(TWindow(param));
 end;

{ TInspectorTree }

procedure DrawTree(elem:TUIElement);
 var
  tree:TInspectorTree;
  font:TFontHandle;
  i,y,x1,y1,x2,y2:integer;
  lineH,indent,scrollPos:single;
  x,mx,my,s:single;
  color:cardinal;
 begin
  tree:=elem as TInspectorTree;
  font:=tree.StyleFont;
  with tree.globalRect do begin x1:=left; y1:=top; x2:=right-1; y2:=bottom-1; end;
  draw.FillRect(x1,y1,x2,y2,COLOR_PANEL);
  lineH:=tree.lineHeight*tree.globalScale;
  indent:=tree.Indent*tree.globalScale;
  scrollPos:=tree.scrollerV.GetValue*tree.globalScale;
  gfx.clip.Rect(Rect(x1,y1,x2+1,y2+1));
  for i:=0 to high(tree.rows) do begin
   y:=y1+round(i*lineH-scrollPos);
   if y+lineH<y1 then continue;
   if y>y2 then break;
   if i=tree.selectedLine then draw.FillRect(x1,y,x2,round(y+lineH),COLOR_SELECTED)
   else if i=tree.hoverLine then draw.FillRect(x1,y,x2,round(y+lineH),COLOR_HOVER);
   with tree.rows[i] do begin
    x:=x1+4+depth*indent;
    // expand mark: a small triangle, right (collapsed) or down (expanded)
    if hasChildren then begin
     mx:=x+indent*0.5; my:=y+lineH*0.5; s:=lineH*0.18;
     if expanded then
      draw.FillTriangle(mx-s,my-s*0.6,mx+s,my-s*0.6,mx,my+s*0.8,COLOR_DIM,COLOR_DIM,COLOR_DIM)
     else
      draw.FillTriangle(mx-s*0.6,my-s,mx-s*0.6,my+s,mx+s*0.8,my,COLOR_DIM,COLOR_DIM,COLOR_DIM);
    end;
    if not element.flags.visible then color:=COLOR_DIM
    else if not element.flags.enabled then color:=COLOR_DISABLED
    else color:=COLOR_TEXT;
    txt.Write(font,x+indent,y+round(lineH*0.73),color,text);
   end;
  end;
  gfx.clip.Restore;
 end;

constructor TInspectorTree.Create(width,height:single;parent:TUIElement);
 begin
  inherited Create(width,height,parent,'_InspectorTree',ROW_HEIGHT);
  drawer:=DrawTree;
 end;

function TInspectorTree.Indent:single;
 begin
  result:=lineHeight*0.8;
 end;

procedure TInspectorTree.onMouseButtons(button:byte;state:boolean);
 var
  x:single;
  line:integer;
 begin
  line:=hoverLine;
  if (button=1) and state and (line>=0) and (line<=high(rows)) and rows[line].hasChildren then begin
   x:=(curMouseX-globalRect.left)/globalScale-4;
   if (x>=rows[line].depth*Indent) and (x<(rows[line].depth+1)*Indent) then begin
    SetExpanded(rows[line].element,not rows[line].expanded);
    inspScene.nextTreeTime:=0;
    exit;
   end;
  end;
  inherited;
 end;

procedure TInspectorTree.SelectLine(line:integer);
 begin
  inherited;
  if (line>=0) and (line<=high(rows)) then inspScene.SelectElement(rows[line].element);
 end;

{ TInspectorTable }

procedure DrawTable(elem:TUIElement);
 var
  table:TInspectorTable;
  font:TFontHandle;
  i,y,x1,y1,x2,y2,xv:integer;
  lineH,scrollPos:single;
  color:cardinal;
 begin
  table:=elem as TInspectorTable;
  font:=table.StyleFont;
  with table.globalRect do begin x1:=left; y1:=top; x2:=right-1; y2:=bottom-1; end;
  draw.FillRect(x1,y1,x2,y2,COLOR_PANEL);
  lineH:=table.lineHeight*table.globalScale;
  scrollPos:=table.scrollerV.GetValue*table.globalScale;
  xv:=x1+round(table.nameWidth*table.globalScale);
  gfx.clip.Rect(Rect(x1,y1,x2+1,y2+1));
  for i:=0 to high(table.fields) do begin
   y:=y1+round(i*lineH-scrollPos);
   if y+lineH<y1 then continue;
   if y>y2 then break;
   if i=table.hoverLine then draw.FillRect(x1,y,x2,round(y+lineH),COLOR_HOVER);
   with table.fields[i] do begin
    txt.Write(font,x1+6,y+round(lineH*0.73),COLOR_NAME,name);
    if edit=TFieldEdit.Bool then continue; // a check box shows it
    if name=inspScene.editField then continue; // the editor covers it
    case edit of
     TFieldEdit.Ref:color:=COLOR_REF;
     TFieldEdit.ReadOnly:color:=COLOR_DIM;
     else color:=COLOR_TEXT;
    end;
    txt.Write(font,xv,y+round(lineH*0.73),color,value);
   end;
  end;
  draw.Line(xv-4,y1,xv-4,y2,COLOR_HOVER);
  gfx.clip.Restore;
 end;

constructor TInspectorTable.Create(width,height:single;parent:TUIElement);
 begin
  inherited Create(width,height,parent,'_InspectorTable',ROW_HEIGHT);
  drawer:=DrawTable;
  nameWidth:=100;
 end;

procedure TInspectorTable.onMouseButtons(button:byte;state:boolean);
 var
  x:single;
  line:integer;
 begin
  inherited;
  line:=hoverLine;
  if (button<>1) or not state or (line<0) or (line>high(fields)) then exit;
  x:=(curMouseX-globalRect.left)/globalScale;
  if x<nameWidth then exit;
  case fields[line].edit of
   TFieldEdit.Ref:inspScene.SelectElement(fields[line].ref);
   TFieldEdit.Text,TFieldEdit.Enum:inspScene.BeginEdit(line);
  end;
 end;

{ TInspectorEnumList }

procedure TInspectorEnumList.SelectLine(line:integer);
 begin
  inherited;
  if (line<0) or (line>high(lines)) or (inspScene.editField='') then exit;
  inspScene.Commit(inspScene.editField,lines[line]);
  inspScene.EndEdit;
 end;

{ TInspectorScene }

procedure EditorEnter(event:TEventStr;tag:TTag);
 begin
  with inspScene do
   if editField<>'' then Commit(editField,editor.text);
  inspScene.EndEdit;
 end;

procedure EditorEscape(event:TEventStr;tag:TTag);
 begin
  inspScene.EndEdit;
 end;

constructor TInspectorScene.Create(wnd:TWindow);
 var
  w,h,headerH:single;
 begin
  inherited Create('_Inspector',true,wnd);
  UI.SetScale(OwnScale);
  UI.styleinfo:=UTF8.Format('%x',[COLOR_BACK]);
  UI.style.Assign('font-size:'+FONT_SIZE+';');
  w:=UI.clientWidth; h:=UI.clientHeight; // children are placed in the root's own (scaled) units
  headerH:=HEADER_HEIGHT;
  header:=TUILabel.Create(w-8,headerH,UI,'_InspectorHeader');
  header.SetPos(4,0).SetAnchors(0,0,1,0);
  header.style.Assign(UTF8.Format('color:$%x;',[COLOR_TEXT]));
  tree:=TInspectorTree.Create(w*0.45-6,h-headerH-4,UI);
  tree.SetPos(4,headerH).SetAnchors(0,0,0.45,1);
  table:=TInspectorTable.Create(w*0.55-6,h-headerH-4,UI);
  table.SetPos(w*0.45+2,headerH).SetAnchors(0.45,0,1,1);

  editor:=TUIEditBox.Create(100,table.lineHeight,table,'_InspectorEditor');
  editor.sendSignals:=ssMajor;
  editor.flags.visible:=false;
  SetEventHandler('UI\_InspectorEditor\Enter',EditorEnter,emInstant);
  SetEventHandler('UI\_InspectorEditor\Escape',EditorEscape,emInstant);

  enumList:=TInspectorEnumList.Create(100,100,UI,'_InspectorEnum',ROW_HEIGHT);
  enumList.bgColor:=COLOR_BACK;
  enumList.autoSelectMode:=false;
  enumList.order:=$10000; // stay on top
  enumList.flags.visible:=false;
 end;

// UI scale of the inspector's own window. The app's UI scale follows the main window,
// and the app applies it to this window too after a DPI change: Process puts it back
function TInspectorScene.OwnScale:single;
 begin
  result:=TWindow(ownerWindow).canvasDPI/96;
 end;

function TInspectorScene.Process:boolean;
 var
  s:single;
 begin
  result:=inherited Process;
  s:=OwnScale;
  if abs(UI.scale-s)>0.001 then UI.SetScale(s);
  Refresh;
 end;

procedure TInspectorScene.Render;
 begin
  gfx.target.Clear(COLOR_BACK);
  inherited;
 end;

procedure TInspectorScene.Refresh;
 var
  roots:TUIElements;
  rows:TTreeRows;
  fields:TFieldRows;
  sel:TUIElement;
  newTree,lost:boolean;
  i:integer;
  title:String8;
 begin
  if target=nil then begin
   header.caption:='No window to inspect: press Ctrl+Shift+I in it';
   EndEdit;
   shownElement:=nil;
   tree.rows:=nil; tree.ClearLines;
   table.fields:=nil; table.ClearLines;
   RebuildBoxes;
   exit;
  end;
  newTree:=CoreTime.Ticks>=nextTreeTime;
  sel:=SelectedElement;
  lost:=false;
  if not target.Lock then begin
   SetTarget(nil);
   exit;
  end;
  try
   roots:=TargetRoots(target);
   if newTree then rows:=BuildTree(roots);
   if sel<>nil then begin
    // a click on a check box since the last frame: write the new state
    if sel=shownElement then
     for i:=0 to high(boxes) do
      if (boxes[i]<>nil) and (boxes[i].checked<>boxShown[i]) and (i<=high(table.fields)) then
       try
        WriteField(sel,table.fields[i].name,String8(BoolToStr(boxes[i].checked,true)));
       except
        on e:Exception do lastError:=String8(e.Message);
       end;
    fields:=ReadFields(sel);
   end else
    fields:=nil;
   title:=target.name;
  finally
   target.Unlock;
  end;
  if (sel=nil) and (selected<>nil) then lost:=true; // removed from the inspected UI
  if lost then SetSelected(nil);

  // the tree
  if newTree then begin
   nextTreeTime:=CoreTime.Ticks+TREE_REFRESH_MS;
   tree.rows:=rows;
   tree.lines:=nil;
   SetLength(tree.lines,length(rows));
   for i:=0 to high(rows) do tree.lines[i]:=rows[i].text;
   tree.UpdateScroller;
  end;
  tree.selectedLine:=-1;
  for i:=0 to high(tree.rows) do
   if tree.rows[i].element=sel then tree.selectedLine:=i;

  // the edit box lost the focus: keep what was typed
  if (editField<>'') and editor.flags.visible and (FocusedElement<>editor) then begin
   Commit(editField,editor.text);
   EndEdit;
  end;

  // the fields
  if sel<>shownElement then begin
   EndEdit;
   shownElement:=sel;
   table.fields:=fields;
   RebuildBoxes;
   table.scrollerV.SetValue(0);
  end else
   table.fields:=fields;
  if length(table.lines)<>length(fields) then begin
   SetLength(table.lines,length(fields));
   for i:=0 to high(fields) do table.lines[i]:=fields[i].name;
   table.UpdateScroller;
  end;
  for i:=0 to high(boxes) do
   if (boxes[i]<>nil) and (i<=high(fields)) then begin
    boxShown[i]:=fields[i].value='true';
    boxes[i].checked:=boxShown[i];
   end;
  PlaceEditors;

  if sel<>nil then title:=title+'  >  '+ElementText(sel)
   else title:=title+'  >  (click an element in the tree)';
  if lastError<>'' then title:=title+'   ! '+lastError;
  header.caption:=title;
 end;

// Check boxes for the bool fields of the shown element
procedure TInspectorScene.RebuildBoxes;
 var
  i:integer;
 begin
  for i:=0 to high(boxes) do
   if boxes[i]<>nil then boxes[i].Remove;
  boxes:=nil; boxShown:=nil;
  SetLength(boxes,length(table.fields));
  SetLength(boxShown,length(table.fields));
  for i:=0 to high(table.fields) do
   if table.fields[i].edit=TFieldEdit.Bool then begin
    boxes[i]:=TUICheckBox.Create(table.lineHeight-4,table.lineHeight-4,table,'');
    boxes[i].Setup('',table.fields[i].value='true');
    boxShown[i]:=boxes[i].checked;
   end;
 end;

// Check boxes and the editor follow the scrolled lines of the table
procedure TInspectorScene.PlaceEditors;
 var
  i:integer;
  y,lineH,scrollPos:single;
 begin
  lineH:=table.lineHeight;
  scrollPos:=table.scrollerV.GetValue;
  for i:=0 to high(boxes) do
   if boxes[i]<>nil then begin
    y:=i*lineH-scrollPos;
    boxes[i].SetPos(table.nameWidth,y+2);
    boxes[i].flags.visible:=(y>-lineH) and (y<table.clientHeight);
   end;
  if editField<>'' then
   for i:=0 to high(table.fields) do
    if table.fields[i].name=editField then begin
     y:=i*lineH-scrollPos;
     editor.SetPos(table.nameWidth-4,y);
     editor.Resize(table.clientWidth-table.nameWidth-8,lineH);
    end;
 end;

procedure TInspectorScene.BeginEdit(row:integer);
 var
  values:String8;
 begin
  EndEdit;
  editField:=table.fields[row].name;
  if table.fields[row].edit=TFieldEdit.Enum then begin
   values:='';
   if target.Lock then
    try
     values:=EnumValues(shownElement,editField);
    finally
     target.Unlock;
    end;
   enumList.SetLines(values.Split(','));
   enumList.selectedLine:=-1;
   enumList.Resize(table.clientWidth-table.nameWidth,length(enumList.lines)*enumList.lineHeight);
   enumList.SetPos(table.position.x+table.nameWidth,
     table.position.y+(row+1)*table.lineHeight-table.scrollerV.GetValue); // the table is a child of the root
   enumList.flags.visible:=true;
   enumList.SetFocus;
   exit;
  end;
  editor.text:=table.fields[row].value;
  editor.flags.visible:=true;
  PlaceEditors;
  editor.SetFocus;
  editor.SelectAll;
 end;

procedure TInspectorScene.EndEdit;
 begin
  editField:='';
  if editor<>nil then editor.flags.visible:=false;
  if enumList<>nil then enumList.flags.visible:=false;
 end;

procedure TInspectorScene.Commit(const name,value:String8);
 var
  sel:TUIElement;
 begin
  sel:=SelectedElement;
  if (sel=nil) or (target=nil) then exit;
  if not target.Lock then exit;
  try
   lastError:='';
   try
    WriteField(sel,name,value);
   except
    on e:Exception do lastError:=name+': '+String8(e.Message);
   end;
  finally
   target.Unlock;
  end;
 end;

procedure TInspectorScene.SelectElement(e:TUIElement);
 var
  roots:TUIElements;
 begin
  if (target=nil) or (e=nil) then exit;
  if not target.Lock then exit;
  try
   roots:=TargetRoots(target);
   if FindInTree(roots,e) then SetSelected(e); // alive: still in the inspected tree
  finally
   target.Unlock;
  end;
 end;

{ Opening and closing }

// Any window's thread: open the inspector for this window
procedure OpenFor(wnd:TWindow);
 begin
  if (wnd=nil) or (wnd=inspWindow) then exit;
  if wnd.Acquire then Signal(OPEN_EVENT,TTag(wnd));
 end;

// A window with this name exists (a closed inspector keeps the name for a moment)
function WindowExists(const name:String8):boolean;
 var
  item:TWindow;
 begin
  for item in ListWindows do
   if SameText(item.name,name) then exit(true);
  result:=false;
 end;

// Control thread (queued): create the window if there is none, then inspect the window
// in tag (held) there
procedure OpenHandler(event:TEventStr;tag:TTag);
 var
  wnd,insp:TWindow;
  w,h,sw,sh:integer;
  scale:single;
  t:int64;
 begin
  wnd:=TWindow(tag);
  insp:=inspWindow; // the inspector's thread clears it when the window closes
  try
   if insp=nil then begin
    t:=CoreTime.Ticks+1000;
    while WindowExists(INSPECTOR_NAME) and (CoreTime.Ticks<t) do
     CoreTime.Sleep(10);
    // the size is given in real pixels: scale it by DPI, the content is scaled too
    scale:=systemPlatform.GetScreenDPI/96;
    systemPlatform.GetRealScreenSize(sw,sh);
    w:=Min(round(640*scale),round(sw*0.9));
    h:=Min(round(800*scale),round(sh*0.85));
    insp:=game.AddWindow('UI Inspector',w,h,INSPECTOR_NAME);
    inspScene:=TInspectorScene.Create(insp);
    inspScene.SetStatus(TSceneStatus.ssActive);
    insp.QueueCall(WatchCall);
    inspWindow:=insp;
   end;
  except
   on e:Exception do begin
    Log.Error('UI inspector: '+String8(e.Message));
    wnd.Release;
    exit;
   end;
  end;
  if not insp.QueueCall(ShowCall,wnd) then wnd.Release; // it is closing: open again later
 end;

// Window's thread: Ctrl+Shift+I opens the inspector for this window; in the inspector - closes it
procedure KbdHandler(event:TEventStr;tag:TTag);
 begin
  if (TKey(tag and $FF)<>TKey.I) or ((window.shiftState and sscBaseMask)<>sscCtrl+sscShift) then exit;
  if window=inspWindow then window.Terminate
   else OpenFor(window);
  game.SuppressKbdEvent;
 end;

// Inspector window's thread, it starts closing: let go of everything, the engine frees
// the window and the scene a moment later
procedure ClosedHandler(event:TEventStr;tag:TTag);
 begin
  if (inspWindow=nil) or (TWindow(tag)<>inspWindow) then exit;
  SetTarget(nil);
  inspScene:=nil;
  inspWindow:=nil;
  Log.Msg('UI inspector: closed');
 end;

procedure InspectorCmd(cmd:string8);
 begin
  OpenFor(window);
 end;

procedure InitInspector;
 begin
  SetEventHandler('KBD\KeyDown',KbdHandler,emInstant);
  SetEventHandler(OPEN_EVENT,OpenHandler,emQueued);
  SetEventHandler('ENGINE\WINDOW\CLOSED',ClosedHandler,emInstant);
  SetCmdFunc('INSPECTOR',opFirst,InspectorCmd);
 end;

initialization
 selLock.Init('UIInspector',30); // entered under a window lock (20)
end.
