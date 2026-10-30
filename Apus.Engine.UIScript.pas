// This unit published all UI elements so makes them accessible from scripts
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@astralheroes.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (https://github.com/Cooler2/ApusGameEngine)
unit Apus.Engine.UIScript;
interface
uses Apus.Core, Apus.Publics;

type
 // UI element published by name: its fields are listed in one table (see InitFields)
 TVarTypeUIElement=class(TVarTypeStruct)
  class function GetValue(variable:pointer):string8; override;
  class function GetField(variable:pointer;fieldName:string8;out varClass:TVarClass):pointer; override;
  class function ListFields:string8; override;
  class function ListFieldsOf(variable:pointer):string8; override;
 end;

 // reference to an element (parent, children[i]): the variable is ^TUIElement, its value is the short name
 TVarTypeElementRef=class(TVarTypeStruct)
  class procedure SetValue(variable:pointer;v:string8); override;
  class function GetValue(variable:pointer):string8; override;
  class function GetField(variable:pointer;fieldName:string8;out varClass:TVarClass):pointer; override;
  class function ListFieldsOf(variable:pointer):string8; override;
 end;

 // children of an element (read-only)
 TVarTypeElements=class(TVarType)
  class procedure SetValue(variable:pointer;v:string8); override;
  class function GetValue(variable:pointer):string8; override;
 end;

 function GetVarTypeFor(typeName:string8):TVarClass;

implementation
uses SysUtils, Apus.EventMan, Apus.Engine.CmdProc, Apus.Engine.Types,
   Apus.Engine.API, Apus.Engine.UI, Apus.Engine.UIWidgets, Apus.Engine.UITypes,
   Apus.Engine.UIShapes, Apus.Engine.UIRender, Apus.Geom2d,
  Apus.Conv,
  Apus.Strings,
  Apus.Threads;

type
 TDefaults=record
  parentObj:TUIElement; // parent element used for creating new elements
  x,y,width,height,hintDelay,hintDuration:integer;
  color,backgnd:cardinal;
  font,style,cursor:integer;
  caption:string8;
  align:TTextAlignment;
 end;
// TVarType=(vtNone,vtInt,vtByte,vtStr,vtBool,vtSendSignals,vtAlignment,vtBtnStyle,vtTranspMode);

 TVarTypeAlignment=class(TVarTypeEnum)
  class procedure SetValue(variable:pointer;v:string8); override;
  class function GetValue(variable:pointer):string8; override;
  class function ListValues:string8; override;
 end;

 TVarTypeStyleInfo=class(TVarType)
  class procedure SetValue(variable:pointer;v:string8); override;
  class function GetValue(variable:pointer):string8; override;
 end;

 // boolean flag published with the opposite meaning (clipchildren -> dontClipChildren)
 TVarTypeNotBool=class(TVarTypeBool)
  class procedure SetValue(variable:pointer;v:string8); override;
  class function GetValue(variable:pointer):string8; override;
 end;

 TVarTypeClientWidth=class(TVarType)
  class procedure SetValue(variable:pointer;v:string8); override;
  class function GetValue(variable:pointer):string8; override;
 end;

 TVarTypeClientHeight=class(TVarType)
  class procedure SetValue(variable:pointer;v:string8); override;
  class function GetValue(variable:pointer):string8; override;
 end;

 TVarTypeElementColor=class(TVarType)
  class procedure SetValue(variable:pointer;v:string8); override;
  class function GetValue(variable:pointer):string8; override;
 end;

 TVarTypeElementFont=class(TVarType)
  class procedure SetValue(variable:pointer;v:string8); override;
  class function GetValue(variable:pointer):string8; override;
 end;

 TVarTypeElementScale=class(TVarType)
  class procedure SetValue(variable:pointer;v:string8); override;
  class function GetValue(variable:pointer):string8; override;
 end;

 TVarTypeElementName=class(TVarType)
  class procedure SetValue(variable:pointer;v:string8); override;
  class function GetValue(variable:pointer):string8; override;
 end;

 TVarTypeTranspMode=class(TVarTypeEnum)
  class procedure SetValue(variable:pointer;v:string8); override;
  class function GetValue(variable:pointer):string8; override;
  class function ListValues:string8; override;
 end;

 TVarTypeSendSignals=class(TVarTypeEnum)
  class procedure SetValue(variable:pointer;v:string8); override;
  class function GetValue(variable:pointer):string8; override;
  class function ListValues:string8; override;
 end;

 TVarTypePivot=class(TVarTypeEnum)
  class procedure SetValue(variable:pointer;v:string8); override;
  class function GetValue(variable:pointer):string8; override;
  class function ListValues:string8; override;
 end;

{$SCOPEDENUMS ON}
 // How a published field is reached from the element
 TFieldKind=(Member,    // a member of the element: element address + offset
             Element,   // the element itself: the var class reads/writes through its methods
             Children); // children, or children[i] with an index
{$SCOPEDENUMS OFF}

 TUIField=record
  name:string8;
  owner:TClass;       // the field exists in this class and its descendants
  varClass:TVarClass;
  kind:TFieldKind;
  offset:UIntPtr;     // Member: offset in the instance
 end;

var
 defaults:TDefaults; // default values used when new element is created
 fields:array of TUIField; // published fields of UI elements, in display order
 curobjname:string8; // current element name in upper case

procedure onItemCreated(event:TEventStr;tag:TTag);
var
 c:TUIElement;
begin
 c:=TUIElement(tag);
 if (c.name<>'') and (c.name[1]<>'_') then // elements named '_XXX' aren't published, their names don't have to be unique
  PublishVar(c,c.name,TVarTypeUIElement);
end;

procedure onItemRenamed(event:TEventStr;tag:TTag);
var
 c:TUIElement;
begin
 c:=TUIElement(tag);
 UnpublishVar(c);
 if c.name<>'' then
  PublishVar(c,c.name,TVarTypeUIElement);
end;

procedure UseParentCmd(cmd:string8);
 var
  c:TUIElement;
 begin
  window.LockState;
  try
  delete(cmd,1,10);
  cmd:=UpperCase {TODO: use st.ToUpper}(cmd);
  if (defaults.parentObj<>nil) and (UpperCase {TODO: use st.ToUpper}(defaults.parentObj.name)=cmd) then exit;
  c:=FindElement(cmd,false);
  if c=nil then
   raise EWarning.Create('Object not found - '+cmd);
  defaults.parentObj:=c;
  finally
   window.UnlockState;
  end;
 end;

procedure SetFocusCmd(cmd:string8);
 var
  c:TUIElement;
 begin
  window.LockState;
  try
   if length(cmd)=8 then c:=curobj
   else begin
    if cmd[length(cmd)-8]<>'.' then
     raise EError.Create('Syntax error, object not specified!');
    setLength(cmd,length(cmd)-9);
    c:=FindElement(cmd,false);
   end;
   if c=nil then raise EError.Create('No object!');
   if not c.flags.canHaveFocus then raise EError.Create('This object can''t have focus!');
   c.SetFocus;
  finally
   window.UnlockState;
  end;
 end;

procedure CreateCmd(cmd:string8);
 var
  sa:Strings8;
  c:TUIElement;
 begin
  window.LockState;
  try
   if defaults.parentObj=nil then raise EError.Create('No object selected, use "UseParent" to select parent object first!');
   delete(cmd,1,7);
   sa:=cmd.Split(' ','"');
   if length(sa)<>2 then raise EError.Create('Must have 2 parameters');
   sa[0]:=sa[0].Trim.ToUpper;
   c:=FindElement(sa[1],false);
   if c<>nil then begin
    curObj:=c;
    curObjClass:=TVarTypeUIElement;
    curObjName:=UpperCase {TODO: use st.ToUpper}(c.name);
    exit;
   end;
   with defaults do begin
    if sa[0]='UIBUTTON' then c:=TUIButton.Create(width,height,parentobj,sa[1]).Setup(caption) else
    if sa[0]='UITOGGLEBUTTON' then c:=TUIToggleButton.Create(width,height,parentobj,sa[1]).Setup(caption) else
    if sa[0]='UIIMAGE' then c:=TUIImage.Create(width,height,parentobj,sa[1]) else
    if sa[0]='UIEDITBOX' then c:=TUIEditBox.Create(width,height,parentobj,sa[1]) else
    if sa[0]='UILABEL' then begin
     c:=TUILabel.Create(width,height,parentobj,sa[1]).Setup(caption);
     (c as TUILabel).align:=align;
     c.shape:=shapeEmpty;
    end else
    if sa[0]='UICONTROL' then begin
     c:=TUIElement.Create(width,height,parentobj,sa[1]);
    end else
    if sa[0]='UILISTBOX' then c:=TUIListBox.Create(width,height,parentobj,sa[1],20) else
    if sa[0]='UICOMBOBOX' then c:=TUIComboBox.Create(width,height,parentobj,sa[1]);


    if c=nil then raise EError.Create('Unknown class - '+sa[0]);
    // ���. ��-��
    if style<>0 then c.drawer:=GetUIStyle(style);
    if cursor<>0 then c.cursor:=cursor;
    if HintDelay<>0 then c.attributes.Item['hintDelay']:=Conv.ToStr(hintDelay);
    if HintDuration<>0 then c.attributes.Item['hintDuration']:=Conv.ToStr(hintDuration);
   end;
   curobj:=c;
   curObjClass:=TVarTypeUIElement;
   curobjname:=c.name;
  finally
   window.UnlockState;
  end;
 end;

function StrToAlign(s:string8):TTextAlignment;
 begin
  s:=s.ToUpper;
  result:=taLeft;
  if s='RIGHT' then result:=taRight;
  if s='CENTER' then result:=taCenter;
  if s='JUSTIFY' then result:=taJustify;
 end;

function EvalInt(st:string8):int64;
 begin
  result:=round(EvalFloat(st,nil,curObj,curObjClass));
 end;

{$IFDEF FPC}{$PUSH}{$R-}{$ENDIF}
procedure DefaultCmd(cmd:string8);
 var
  sa:Strings8;
 begin
   delete(cmd,1,7);
   sa:=cmd.Split(' ','"');
   sa[0]:=UpperCase {TODO: use st.ToUpper}(sa[0]);
   if sa[0]='X' then defaults.X:=EvalInt(sa[1]) else
   if sa[0]='Y' then defaults.Y:=EvalInt(sa[1]) else
   if sa[0]='WIDTH' then defaults.Width:=EvalInt(sa[1]) else
   if sa[0]='HEIGHT' then defaults.Height:=EvalInt(sa[1]) else
   if sa[0]='HINTDELAY' then defaults.hintDelay:=EvalInt(sa[1]) else
   if sa[0]='HINTDURATION' then defaults.hintDuration:=EvalInt(sa[1]) else
   if sa[0]='COLOR' then defaults.Color:=EvalInt(sa[1]) else
   if sa[0]='BACKGND' then defaults.Backgnd:=EvalInt(sa[1]) else
   if sa[0]='FONT' then defaults.Font:=EvalInt(sa[1]) else
   if sa[0]='CURSOR' then defaults.Cursor:=EvalInt(sa[1]) else
   if sa[0]='STYLE' then defaults.Style:=EvalInt(sa[1]) else
   if sa[0]='CAPTION' then defaults.caption:=sa[1] else
   if sa[0]='ALIGN' then defaults.align:=StrToAlign(sa[1]) else
    raise EWarning.Create('Incorrect command - '+cmd);
 end;
{$IFDEF FPC}{$POP}{$ENDIF}

procedure SetHotKeyCmd(cmd:string8);
 var
  key,shift:byte;
  v,i,d:integer;
  sa:Strings8;
  obj:TUIElement;
 begin
  window.LockState;
  try
   delete(cmd,1,10);
   cmd:=UpperCase {TODO: use st.ToUpper}(cmd);
   obj:=curobj;
   if (obj=nil) or not (obj is TUIElement) then raise EWarning.Create('No UI object selected');
   sa:=cmd.Split('+',#0);
   v:=0;
   for i:=0 to length(sa)-1 do begin
    if sa[i]='ENTER' then d:=13 else
    if sa[i]='SPACE' then d:=32 else
    if sa[i]='ESC' then d:=27 else
    if sa[i]='SHIFT' then d:=$100 else
    if sa[i]='CTRL' then d:=$200 else
    if sa[i]='ALT' then d:=$400 else
     d:=StrToInt(sa[i]);
    v:=v+d;
   end;
   if v=0 then obj.RemoveHotKey(0,0)
   else begin
    key:=v and 255;
    shift:=v shr 8;
    obj.SetHotKey(key,shift);
   end;
  finally
   window.UnlockState;
  end;
 end;


{ TVarTypeUIControl }

// Field table: one place for the published field names, used by GetField and ListFieldsOf

procedure AddField(const name:string8;owner:TClass;varClass:TVarClass;kind:TFieldKind;offset:UIntPtr=0);
 var
  n:integer;
 begin
  n:=length(fields);
  SetLength(fields,n+1);
  fields[n].name:=name;
  fields[n].owner:=owner;
  fields[n].varClass:=varClass;
  fields[n].kind:=kind;
  fields[n].offset:=offset;
 end;

// fieldAddr - address of the member in a nil instance, that is, its offset
procedure AddMember(const name:string8;owner:TClass;varClass:TVarClass;fieldAddr:pointer);
 begin
  AddField(name,owner,varClass,TFieldKind.Member,UIntPtr(fieldAddr));
 end;

procedure AddProperty(const name:string8;owner:TClass;varClass:TVarClass);
 begin
  AddField(name,owner,varClass,TFieldKind.Element);
 end;

procedure InitFields;
 var
  e:TUIElement;
  lbl:TUILabel;
  btn:TUIButton;
  edit:TUIEditBox;
  img:TUIImage;
  list:TUIListBox;
  bar:TUIScrollBar;
 begin
  e:=nil; lbl:=nil; btn:=nil; edit:=nil; img:=nil; list:=nil; bar:=nil;
  // identity and geometry
  AddProperty('name',TUIElement,TVarTypeElementName);
  AddMember('x',TUIElement,TVarTypeSingle,@e.position.x);
  AddMember('y',TUIElement,TVarTypeSingle,@e.position.y);
  AddMember('width',TUIElement,TVarTypeSingle,@e.size.x);
  AddMember('height',TUIElement,TVarTypeSingle,@e.size.y);
  AddMember('scale',TUIElement,TVarTypeSingle,@e.scale);
  AddMember('pivot',TUIElement,TVarTypePivot,@e.pivot);
  AddMember('anchors',TUIElement,TVarTypeRect2s,@e.anchors);
  AddMember('paddingleft',TUIElement,TVarTypeSingle,@e.padding.left);
  AddMember('paddingright',TUIElement,TVarTypeSingle,@e.padding.right);
  AddMember('paddingtop',TUIElement,TVarTypeSingle,@e.padding.top);
  AddMember('paddingbottom',TUIElement,TVarTypeSingle,@e.padding.bottom);
  AddProperty('clientwidth',TUIElement,TVarTypeClientWidth);
  AddProperty('clientheight',TUIElement,TVarTypeClientHeight);
  AddMember('globalrect',TUIElement,TVarTypeRect,@e.globalRect);
  AddProperty('globalscale',TUIElement,TVarTypeElementScale);
  // state and behavior
  AddMember('visible',TUIElement,TVarTypeBool,@e.flags.visible);
  AddMember('enabled',TUIElement,TVarTypeBool,@e.flags.enabled);
  AddMember('canhavefocus',TUIElement,TVarTypeBool,@e.flags.canHaveFocus);
  AddMember('clipchildren',TUIElement,TVarTypeNotBool,@e.flags.dontClipChildren);
  AddMember('parentclip',TUIElement,TVarTypeNotBool,@e.flags.noParentClip);
  AddMember('customdraw',TUIElement,TVarTypeBool,@e.flags.manualDraw);
  AddMember('order',TUIElement,TVarTypeInteger,@e.order);
  AddMember('transpmode',TUIElement,TVarTypeTranspMode,@e.shape);
  AddMember('signals',TUIElement,TVarTypeSendSignals,@e.sendSignals);
  AddMember('cursor',TUIElement,TVarTypeNativeInt,@e.cursor);
  // content and look
  AddMember('caption',TUIElement,TVarTypeString8,@e.caption);
  AddMember('hint',TUIElement,TVarTypeString8,@e.hint);
  AddProperty('color',TUIElement,TVarTypeElementColor);
  AddProperty('font',TUIElement,TVarTypeElementFont);
  AddProperty('styleinfo',TUIElement,TVarTypeStyleinfo);
  // tree
  AddMember('parent',TUIElement,TVarTypeElementRef,@e.parent);
  AddField('children',TUIElement,TVarTypeElements,TFieldKind.Children);
  // widgets
  AddMember('align',TUILabel,TVarTypeAlignment,@lbl.align);
  AddMember('topofs',TUILabel,TVarTypeInteger,@lbl.verticalOffset);
  AddMember('default',TUIButton,TVarTypeBool,@btn.default);
  AddMember('pressed',TUIButton,TVarTypeBool,@btn.pressed);
  AddMember('pending',TUIButton,TVarTypeBool,@btn.pending);
  AddMember('autopendingtime',TUIButton,TVarTypeInteger,@btn.autoPendingTime);
  AddMember('text',TUIEditBox,TVarTypeString32,@edit.realText);
  AddMember('maxlength',TUIEditBox,TVarTypeInteger,@edit.maxLength);
  AddMember('password',TUIEditBox,TVarTypeBool,@edit.password);
  AddMember('src',TUIImage,TVarTypeString8,@img.src);
  AddMember('lineheight',TUIListBox,TVarTypeSingle,@list.lineHeight);
  AddMember('min',TUIScrollBar,TVarTypeSingle,@bar.min);
  AddMember('max',TUIScrollBar,TVarTypeSingle,@bar.max);
  AddMember('pagesize',TUIScrollBar,TVarTypeSingle,@bar.pagesize);
 end;

function FindField(obj:TUIElement;const name:string8):integer;
 var
  i:integer;
 begin
  for i:=0 to high(fields) do
   if (fields[i].name=name) and obj.InheritsFrom(fields[i].owner) then exit(i);
  result:=-1;
 end;

class function TVarTypeUIElement.GetField(variable: pointer; fieldName: string8;
  out varClass: TVarClass): pointer;
var
 obj:TUIElement;
 p,index,i:integer;
begin
 obj:=variable;
 ASSERT(fieldName<>'');
 result:=nil;
 varClass:=nil;
 index:=-1; // not indexed
 if fieldname[high(fieldname)]=']' then begin // indexed element?
  p:=pos('[',fieldname);
  if p>0 then begin
   index:=Conv.ToInt(copy(fieldname,p+1,100));
   SetLength(fieldname,p-1);
  end;
 end;

 i:=FindField(obj,fieldName);
 if i<0 then exit;
 case fields[i].kind of
  TFieldKind.Member:begin
   result:=pointer(UIntPtr(obj)+fields[i].offset);
   varClass:=fields[i].varClass;
  end;
  TFieldKind.Element:begin
   result:=obj;
   varClass:=fields[i].varClass;
  end;
  TFieldKind.Children:
   if index>=0 then begin
    if index>high(obj.children) then
     raise EWarning.Create(Format('Index %d out of range %d',[index,high(obj.children)]));
    result:=@obj.children[index];
    varClass:=TVarTypeElementRef;
   end else begin
    result:=@obj.children;
    varClass:=TVarTypeElements;
   end;
 end;
end;

class function TVarTypeUIElement.GetValue(variable: pointer): string8;
begin
 result:=TUIElement(variable).ClassName+inherited;
end;

class function TVarTypeUIElement.ListFields: string8;
var
 i:integer;
begin
 result:='';
 for i:=0 to high(fields) do
  if fields[i].owner=TUIElement then begin
   if result<>'' then result:=result+',';
   result:=result+fields[i].name;
  end;
end;

class function TVarTypeUIElement.ListFieldsOf(variable:pointer):string8;
var
 obj:TUIElement;
 i:integer;
begin
 obj:=variable;
 result:='';
 for i:=0 to high(fields) do
  if obj.InheritsFrom(fields[i].owner) then begin
   if result<>'' then result:=result+',';
   result:=result+fields[i].name;
  end;
end;

{ TVarTypeElementRef }

class procedure TVarTypeElementRef.SetValue(variable:pointer;v:string8);
 begin
  raise EWarning.Create('Element reference is read-only');
 end;

class function TVarTypeElementRef.GetValue(variable:pointer):string8;
 var
  e:TUIElement;
 begin
  e:=TUIElement(variable^);
  if e=nil then result:='nil'
   else result:=Format('%s(''%s'')',[e.ClassName,e.name]);
 end;

class function TVarTypeElementRef.GetField(variable:pointer;fieldName:string8;out varClass:TVarClass):pointer;
 var
  e:TUIElement;
 begin
  e:=TUIElement(variable^);
  if e=nil then begin
   varClass:=nil;
   exit(nil);
  end;
  result:=TVarTypeUIElement.GetField(e,fieldName,varClass);
 end;

class function TVarTypeElementRef.ListFieldsOf(variable:pointer):string8;
 var
  e:TUIElement;
 begin
  e:=TUIElement(variable^);
  if e=nil then exit('');
  result:=TVarTypeUIElement.ListFieldsOf(e);
 end;

class procedure TVarTypeTranspMode.SetValue(variable:pointer;v:string8);
 begin
  v:=lowercase {TODO: use st.ToLower}(v);
  if v='transparent' then TUIShape(variable^):=shapeEmpty else
  if v='opaque' then TUIShape(variable^):=shapeFull else
  raise EWarning.Create('Unknown transparency mode: '+v);
 end;
class function TVarTypeTranspMode.GetValue(variable:pointer):string8;
 var sh:TUIShape;
 begin
  sh:=TUIShape(variable^);
  if sh=shapeEmpty then result:='transparent' else
  if sh=shapeFull then result:='opaque' else
  result:='custom';
 end;

class function TVarTypeTranspMode.ListValues:string8;
 begin
  result:='transparent,opaque';
 end;

class procedure TVarTypeSendSignals.SetValue(variable:pointer;v:string8);
 begin
  v:=lowercase {TODO: use st.ToLower}(v);
  if v='major' then TSendSignals(variable^):=ssMajor else
  if v='all' then TSendSignals(variable^):=ssAll else
  if v='none' then TSendSignals(variable^):=ssNone else
  raise EWarning.Create('Unknown SendSignals mode: '+v);
 end;
class function TVarTypeSendSignals.GetValue(variable:pointer):string8;
 begin
  case TSendSignals(variable^) of
   ssMajor:result:='major';
   ssAll:result:='all';
   ssNone:result:='none';
  end;
 end;

class function TVarTypeSendSignals.ListValues:string8;
 begin
  result:='none,major,all';
 end;

{ TVarTypePivot }

class function TVarTypePivot.ListValues:string8;
 begin
  result:='Center,TopLeft,TopRight,BottomLeft,BottomRight';
 end;

class function TVarTypePivot.GetValue(variable: pointer): string8;
 var
  p:TVec2;
 begin
  p:=TVec2(variable^);
  result:=Format('(%.2f,%.2f)',[p.x,p.y]);
 end;

class procedure TVarTypePivot.SetValue(variable: pointer; v: string8);
 begin
  if SameText(v,'Center') then TVec2(variable^):=pivotCenter else
  if SameText(v,'TopLeft') then TVec2(variable^):=pivotTopLeft else
  if SameText(v,'TopRight') then TVec2(variable^):=pivotTopRight else
  if SameText(v,'BottomLeft') then TVec2(variable^):=pivotBottomLeft else
  if SameText(v,'BottomRight') then TVec2(variable^):=pivotBottomRight else
  raise EWarning.Create('Invalid pivot value: '+v);
 end;

{ TVarTypeNotBool }

class function TVarTypeNotBool.GetValue(variable:pointer):string8;
 var
  b:boolean;
 begin
  b:=not PBoolean(variable)^;
  result:=inherited GetValue(@b);
 end;

class procedure TVarTypeNotBool.SetValue(variable:pointer;v:string8);
 var
  b:boolean;
 begin
  inherited SetValue(@b,v);
  PBoolean(variable)^:=not b;
 end;

{ TVarTypeStyleinfo }

class function TVarTypeStyleinfo.GetValue(variable:pointer):string8;
 begin
  result:=TUIElement(variable).styleInfo;
 end;

class procedure TVarTypeStyleinfo.SetValue(variable:pointer; v:string8);
 begin
  TUIElement(variable).styleInfo:=v;
 end;

{ TVarTypeElementFont }

class function TVarTypeElementFont.GetValue(variable:pointer):string8;
 begin
  result:=TUIElement(variable).GetStyleValue('font','');
 end;

class procedure TVarTypeElementFont.SetValue(variable:pointer; v:string8);
 begin
  TUIElement(variable).style.SetAttr('font',v); // the font is a style attribute
 end;

{ TVarTypeAlignment }

class function TVarTypeAlignment.GetValue(variable:pointer):string8;
 var
  a:TTextAlignment;
 begin
  a:=TTextAlignment(variable^);
  case a of
   taLeft:result:='Left';
   taRight:result:='Right';
   taCenter:result:='Center';
   taJustify:result:='Justify';
  end;
 end;

class function TVarTypeAlignment.ListValues:string8;
 begin
  result:='Left,Right,Center,Justify';
 end;

class procedure TVarTypeAlignment.SetValue(variable:pointer; v:string8);
 var
  a:^TTextAlignment;
 begin
  a:=variable;
  a^:=StrToAlign(v);
 end;

function GetVarTypeFor(typeName:string8):TVarClass;
 begin
   result:=nil;
   if SameText(typeName,'TTextAlignment') then result:=TVarTypeAlignment
   else
   if SameText(typeName,'TUIElement') then result:=TVarTypeUIElement;
 end;

{ TVarTypeElementName }

class function TVarTypeElementName.GetValue(variable:pointer):string8;
 begin
  result:=''''+TUIElement(variable).name+'''';
 end;

class procedure TVarTypeElementName.SetValue(variable:pointer;v:string8);
 begin
  TUIElement(variable).name:=v;
 end;

{ TVarTypeObjColor }

class function TVarTypeElementColor.GetValue(variable:pointer):string8;
 begin
  result:='$'+IntToHex(TUIElement(variable).GetStyleColor('color',0),8);
 end;

class procedure TVarTypeElementColor.SetValue(variable:pointer;v:string8);
 begin
  // bare hex digits get '$'; '$AARRGGBB', '#RGB' and tokens ('&name') are stored as is
  if (v<>'') and (v[1] in ['0'..'9','A'..'F','a'..'f']) then v:='$'+v;
  TUIElement(variable).style.SetAttr('color',v);
 end;

{ TVarTypeElementScale }

class function TVarTypeElementScale.GetValue(variable: pointer): string8;
 begin
  result:=FloatToStr(TUIElement(variable).globalScale);
 end;

class procedure TVarTypeElementScale.SetValue(variable: pointer; v: string8);
 begin
  raise EWarning.Create('GlobalScale is a read-only property');
 end;

{ TVarTypeClientWidth }

class function TVarTypeClientWidth.GetValue(variable: pointer): string8;
 begin
  result:=FloatToStr(TUIElement(variable).clientWidth);
 end;

class procedure TVarTypeClientWidth.SetValue(variable: pointer; v: string8);
 begin
  raise EWarning.Create('ClientWidth is a read-only property');
 end;

{ TVarTypeClientHeight }

class function TVarTypeClientHeight.GetValue(variable: pointer):string8;
 begin
  result:=FloatToStr(TUIElement(variable).clientHeight);
 end;

class procedure TVarTypeClientHeight.SetValue(variable: pointer; v: string8);
 begin
  raise EWarning.Create('ClientHeight is a read-only property');
 end;

{ TVarTypeElements }

class function TVarTypeElements.GetValue(variable: pointer):string8;
 var
  list:^TUIElements;
  i:integer;
 begin
  result:='';
  list:=variable;
  for i:=0 to high(list^) do begin
   if result<>'' then result:=result+', ';
   result:=result+Format('%d:%s(''%s'')',[i,list^[i].className,list^[i].name]);
  end;
  result:='['+result+']';
 end;

class procedure TVarTypeElements.SetValue(variable: pointer; v: string8);
 begin
  raise EWarning.Create('TUIElements is a read-only type');
 end;

initialization
 InitFields;
 SetEventHandler('UI\ItemCreated',onItemCreated,emInstant);
 SetEventHandler('UI\ItemRenamed',onItemRenamed,emInstant);
 SetCmdFunc('USEPARENT ',opFirst,UseParentCmd);
 SetCmdFunc('CREATE ',opFirst,CreateCmd);
 SetCmdFunc('DEFAULT',opFirst,DefaultCmd);
 SetCmdFunc('SETFOCUS',opLast,SetFocusCmd);
 SetCmdFunc('SETHOTKEY',opFirst,setHotKeyCmd);
 with defaults do begin
  x:=0; y:=0; width:=100; height:=20;
  color:=$FFFFFFFF; backgnd:=$80000000;
  style:=0; cursor:=CursorID.Default; font:=1;
  caption:='';
  hintDelay:=0; hintDuration:=0;
 end;

finalization

end.
