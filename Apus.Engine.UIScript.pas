// This unit published all UI elements so makes them accessible from scripts
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.UIScript;
interface
uses Apus.Publics;

 function GetVarTypeFor(typeName:string):TVarClass;

implementation
uses Apus.Common, SysUtils, Apus.EventMan, Apus.Engine.CmdProc, Apus.Engine.Types,
   Apus.Engine.API, Apus.Engine.UI, Apus.Engine.UIWidgets, Apus.Engine.UITypes, Apus.Geom2d;

type
 TDefaults=record
  parentObj:TUIElement; // parent element used for creating new elements
  x,y,width,height,hintDelay,hintDuration:integer;
  color,backgnd:cardinal;
  font,style,cursor:integer;
  caption:string;
  align:TTextAlignment;
 end;
// TVarType=(vtNone,vtInt,vtByte,vtStr,vtBool,vtSendSignals,vtAlignment,vtBtnStyle,vtTranspMode);

 TVarTypeAlignment=class(TVarType)
  class procedure SetValue(variable:pointer;v:string); override;
  class function GetValue(variable:pointer):string; override;
 end;

 TVarTypeUIElement=class(TVarTypeStruct)
  class function GetValue(variable:pointer):string; override;
  class function GetField(variable:pointer;fieldName:string;out varClass:TVarClass):pointer; override;
  class function ListFields:String; override;
 end;

 TVarTypeStyleInfo=class(TVarType)
  class procedure SetValue(variable:pointer;v:string); override;
  class function GetValue(variable:pointer):string; override;
 end;

 TVarTypeClientWidth=class(TVarType)
  class procedure SetValue(variable:pointer;v:string); override;
  class function GetValue(variable:pointer):string; override;
 end;

 TVarTypeElements=class(TVarType) // array of TUIElement
  class procedure SetValue(variable:pointer;v:string); override;
  class function GetValue(variable:pointer):string; override;
 end;

 TVarTypeClientHeight=class(TVarType)
  class procedure SetValue(variable:pointer;v:string); override;
  class function GetValue(variable:pointer):string; override;
 end;

 TVarTypeElementColor=class(TVarType)
  class procedure SetValue(variable:pointer;v:string); override;
  class function GetValue(variable:pointer):string; override;
 end;

 TVarTypeElementFont=class(TVarType)
  class procedure SetValue(variable:pointer;v:string); override;
  class function GetValue(variable:pointer):string; override;
 end;

 TVarTypeElementScale=class(TVarType)
  class procedure SetValue(variable:pointer;v:string); override;
  class function GetValue(variable:pointer):string; override;
 end;

 TVarTypeElementName=class(TVarType)
  class procedure SetValue(variable:pointer;v:string); override;
  class function GetValue(variable:pointer):string; override;
 end;

 TVarTypeTranspMode=class(TVarTypeEnum)
  class procedure SetValue(variable:pointer;v:string); override;
  class function GetValue(variable:pointer):string; override;
 end;

 TVarTypeSendSignals=class(TVarTypeEnum)
  class procedure SetValue(variable:pointer;v:string); override;
  class function GetValue(variable:pointer):string; override;
 end;

 TVarTypeBtnStyle=class(TVarTypeEnum)
  class procedure SetValue(variable:pointer;v:string); override;
  class function GetValue(variable:pointer):string; override;
 end;

 TVarTypePivot=class(TVarTypeEnum)
  class procedure SetValue(variable:pointer;v:string); override;
  class function GetValue(variable:pointer):string; override;
 end;


var
 defaults:TDefaults; // default values used when new element is created
 curobjname:string; // current element name in upper case

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

procedure UseParentCmd(cmd:string);
 var
  c:TUIElement;
 begin
  EnterCriticalSection(UICritSect);
  try
  delete(cmd,1,10);
  cmd:=UpperCase(cmd);
  if (defaults.parentObj<>nil) and (UpperCase(defaults.parentObj.name)=cmd) then exit;
  c:=FindControl(cmd,false);
  if c=nil then
   raise EWarning.Create('Object not found - '+cmd);
  defaults.parentObj:=c;
  finally
   LeaveCriticalSection(UICritSect);
  end;
 end;

procedure SetFocusCmd(cmd:string);
 var
  c:TUIElement;
 begin
  EnterCriticalSection(UICritSect);
  try
   if length(cmd)=8 then c:=curobj
   else begin
    if cmd[length(cmd)-8]<>'.' then
     raise EError.Create('Syntax error, object not specified!');
    setLength(cmd,length(cmd)-9);
    c:=FindControl(cmd,false);
   end;
   if c=nil then raise EError.Create('No object!');
   if not c.canHaveFocus then raise EError.Create('This object can''t have focus!');
   c.SetFocus;
  finally
   LeaveCriticalSection(UICritSect);
  end;
 end;

procedure CreateCmd(cmd:string);
 var
  sa:StringArr;
  c:TUIElement;
 begin
  EnterCriticalSection(UICritSect);
  try
   if defaults.parentObj=nil then raise EError.Create('No object selected, use "UseParent" to select parent object first!');
   delete(cmd,1,7);
   sa:=Split(' ',cmd,'"');
   if length(sa)<>2 then raise EError.Create('Must have 2 parameters');
   sa[0]:=uppercase(chop(sa[0]));
   c:=FindControl(sa[1],false);
   if c<>nil then begin
    curObj:=c;
    curObjClass:=TVarTypeUIElement;
    curObjName:=UpperCase(c.name);
    exit;
   end;
   with defaults do begin
    if sa[0]='UIBUTTON' then c:=TUIButton.Create(width,height,sa[1],caption,font,parentobj) else
    if sa[0]='UIIMAGE' then c:=TUIImage.Create(width,height,sa[1],parentobj) else
    if sa[0]='UIEDITBOX' then c:=TUIEditBox.Create(width,height,sa[1],font,color,parentobj) else
    if sa[0]='UILABEL' then begin
     c:=TUILabel.Create(width,height,sa[1],caption,color,font,parentobj);
     (c as TUILabel).align:=align;
     c.shape:=shapeEmpty;
    end else
    if sa[0]='UICONTROL' then begin
     c:=TUIElement.Create(width,height,parentobj,sa[1]);
    end else
    if sa[0]='UILISTBOX' then c:=TUIListBox.Create(width,height,20,sa[1],font,parentobj) else
    if sa[0]='UICOMBOBOX' then c:=TUIComboBox.Create(width,height,font,nil,parentobj,sa[1]);


    if c=nil then raise EError.Create('Unknown class - '+sa[0]);
    // ���. ��-��
    if style<>0 then c.styleClass:=style;
    if cursor<>0 then c.cursor:=cursor;
    if HintDelay<>0 then c.hintDelay:=hintDelay;
    if HintDuration<>0 then c.hintDuration:=hintDuration;
   end;
   curobj:=c;
   curObjClass:=TVarTypeUIElement;
   curobjname:=c.name;
  finally
   LeaveCriticalSection(UICritSect);
  end;
 end;

function StrToAlign(s:string):TTextAlignment;
 begin
  s:=uppercase(s);
  result:=taLeft;
  if s='RIGHT' then result:=taRight;
  if s='CENTER' then result:=taCenter;
  if s='JUSTIFY' then result:=taJustify;
 end;

function EvalInt(st:string):int64;
 begin
  result:=round(EvalFloat(st,nil,curObj,curObjClass));
 end;

{$IFDEF FPC}{$PUSH}{$R-}{$ENDIF}
procedure DefaultCmd(cmd:string);
 var
  sa:StringArr;
 begin
   delete(cmd,1,7);
   sa:=Split(' ',cmd,'"');
   sa[0]:=UpperCase(sa[0]);
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

procedure SetHotKeyCmd(cmd:string);
 var
  key,shift:byte;
  v,i,d:integer;
  sa:stringArr;
  obj:TUIElement;
 begin
  EnterCriticalSection(UICritSect);
  try
   delete(cmd,1,10);
   cmd:=UpperCase(cmd);
   obj:=curobj;
   if (obj=nil) or not (obj is TUIElement) then raise EWarning.Create('No UI object selected');
   sa:=Split('+',cmd,#0);
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
   LeaveCriticalSection(UICritSect);
  end;
 end;


{ TVarTypeUIControl }

class function TVarTypeUIElement.GetField(variable: pointer; fieldName: string;
  out varClass: TVarClass): pointer;
var
 obj:TUIElement;
 p,index:integer;
begin
 obj:=variable;
 ASSERT(fieldName<>'');
 result:=nil;
 varClass:=nil;
 index:=-1; // not indexed
 if fieldname[high(fieldname)]=']' then begin // indexed element?
  p:=pos('[',fieldname);
  if p>0 then begin
   index:=ParseInt(copy(fieldname,p+1,100));
   SetLength(fieldname,p-1);
  end;
 end;

 case fieldname[1] of
  'a':if (fieldname='align') and (obj is TUILabel) then begin
       result:=@TUILabel(obj).align; varClass:=TVarTypeAlignment;
      end else
      if (fieldname='anchors') then begin
       result:=@obj.anchors; varClass:=TVarTypeRect2s;
      end else
      if (fieldname='autopendingtime') and (obj is TUIButton) then begin
       result:=@TUIButton(obj).autopendingtime; varClass:=TVarTypeInteger;
      end;
  'b':if (fieldname='btnstyle') and (obj is TUIButton) then begin
       result:=@TUIButton(obj).btnstyle; varClass:=TVarTypeBtnStyle;
      end;
  'c':if fieldname='canhavefocus' then begin
       result:=@obj.canHaveFocus;
       varClass:=TVarTypeBool;
      end else
      if fieldname='color' then begin
       result:=obj;
       varClass:=TVarTypeElementColor;
      end else
      if fieldname='caption' then begin
       result:=@obj.caption;
       varClass:=TVarTypeString;
      end else
      if fieldname='cursor' then begin
       result:=@obj.cursor; varClass:=TVarTypeInteger;
      end else
      if fieldname='clipchildren' then begin
       result:=@obj.clipchildren; varClass:=TVarTypeBool;
      end else
      if fieldname='customdraw' then begin
       result:=@obj.manualDraw; varClass:=TVarTypeBool;
      end else
      if fieldname='clientwidth' then begin
       result:=obj;
       varClass:=TVarTypeClientWidth;
      end else
      if fieldname='clientheight' then begin
       result:=obj;
       varClass:=TVarTypeClientHeight;
      end else
      if fieldname='children' then begin
       if index>=0 then begin
        if index>high(obj.children) then
         raise EWarning.Create(Format('Index %d out of range %d',[index,high(obj.children)]));
        result:=obj.children[index];
        varClass:=TVarTypeUIElement;
       end else begin
        result:=@obj.children;
        varClass:=TVarTypeElements;
       end;
      end;
  'd':if (fieldname='default') and (obj is TUIButton) then begin
       result:=@TUIButton(obj).default; varClass:=TVarTypeBool;
      end;
  'e':if fieldname='enabled' then begin
       result:=@obj.enabled; varClass:=TVarTypeBool;
      end;
  'f':if fieldname='font' then begin
       result:=obj;
       varClass:=TVarTypeElementFont;
      end;
  'g':if (fieldname='group') and (obj is TUIButton) then begin
       result:=@TUIButton(obj).group; varClass:=TVarTypeInteger;
      end else
      if fieldname='globalrect' then begin
       result:=@obj.globalRect; varClass:=TVarTypeRect;
      end else
      if fieldname='globalscale' then begin
       result:=obj; varClass:=TVarTypeElementScale;
      end;
  'h':if fieldname='height' then begin
       result:=@obj.size.y; varClass:=TVarTypeSingle;
      end else
      if fieldname='hint' then begin
       result:=@obj.hint; varClass:=TVarTypeString;
      end else
      if fieldname='hintifdisabled' then begin
       result:=@obj.hintifdisabled; varClass:=TVarTypeString;
      end else
      if fieldname='hintdelay' then begin
       result:=@obj.hintdelay; varClass:=TVarTypeInteger;
      end else
      if fieldname='hintduration' then begin
       result:=@obj.hintduration; varClass:=TVarTypeInteger;
      end;
  'l':if (fieldname='lineheight') and (obj is TUIListBox) then begin
       varClass:=TVarTypeInteger; result:=@TUIListBox(obj).lineHeight;
      end;
  'm':if (fieldname='maxlength') and (obj is TUIEditBox) then begin
       varClass:=TVarTypeInteger; result:=@TUIEditBox(obj).maxlength;
      end else
      if (fieldname='min') and (obj is TUIScrollBar) then begin
       varClass:=TVarTypeInteger; result:=@TUIScrollBar(obj).min;
      end else
      if (fieldname='max') and (obj is TUIScrollBar) then begin
       varClass:=TVarTypeInteger; result:=@TUIScrollBar(obj).max;
      end;
  'n':if fieldname='name' then begin
       result:=obj; varClass:=TVarTypeElementName;
      end else
      if (fieldname='noborder') and (obj is TUIEditBox) then begin
       result:=@TUIEditBox(obj).noborder; varClass:=TVarTypeBool;
      end;
  'o':if fieldname='order' then begin
       result:=@obj.order; varClass:=TVarTypeInteger;
      end;
  'p':if fieldname='parentclip' then begin
       result:=@obj.parentClip; varClass:=TVarTypeBool;
      end else
      if fieldname='parent' then begin
       result:=obj.parent; varClass:=TVarTypeUIElement;
      end else
      if fieldname='pivot' then begin
       result:=@obj.pivot; varClass:=TVarTypePivot;
      end else
      if (fieldname='pressed') and (obj is TUIButton) then begin
       result:=@TUIButton(obj).pressed; varClass:=TVarTypeBool;
      end else
      if (fieldname='pending') and (obj is TUIButton) then begin
       result:=@TUIButton(obj).pending; varClass:=TVarTypeBool;
      end else
      if (fieldname='password') and (obj is TUIEditBox) then begin
       result:=@TUIEditBox(obj).password; varClass:=TVarTypeBool;
      end else
      if fieldname='paddingleft' then begin
       result:=@obj.padding.Left; varClass:=TVarTypeSingle;
      end else
      if fieldname='paddingright' then begin
       result:=@obj.padding.right; varClass:=TVarTypeSingle;
      end else
      if fieldname='paddingtop' then begin
       result:=@obj.padding.top; varClass:=TVarTypeSingle;
      end else
      if fieldname='paddingbottom' then begin
       result:=@obj.padding.bottom; varClass:=TVarTypeSingle;
      end else
      if (fieldname='pagesize') and (obj is TUIScrollBar) then begin
       varClass:=TVarTypeInteger; result:=@TUIScrollBar(obj).pagesize;
      end;
  's':if fieldname='style' then begin
       result:=@obj.styleClass; varClass:=TVarTypeInteger;
      end else
      if fieldname='styleinfo' then begin
       result:=obj; varClass:=TVarTypeStyleinfo;
      end else
      if fieldname='scale' then begin
       result:=@obj.scale; varClass:=TVarTypeSingle;
      end else
      if fieldname='signals' then begin
       result:=@obj.sendsignals; varClass:=TVarTypeSendSignals;
      end else
      if (fieldname='src') and (obj is TUIImage) then begin
       result:=@TUIImage(obj).src; varClass:=TVarTypeString;
      end;
  't':if fieldname='transpmode' then begin
       result:=@obj.shape; varClass:=TVarTypeTranspMode;
      end else
      if (fieldname='text') and (obj is TUIEditBox) then begin
       varClass:=TVarTypeWideString; result:=@TUIEditBox(obj).realtext;
      end else
      if (fieldname='topofs') and (obj is TUILabel) then begin
       varClass:=TVarTypeInteger; result:=@TUILabel(obj).verticalOffset;
      end;
  'v':if fieldname='visible' then begin
       result:=@obj.visible; varClass:=TVarTypeBool;
{      end else
      if (fieldname='value') and (obj is TUIScrollBar) then begin
       varClass:=TVarTypeInteger; result:=@TUIScrollBar(obj).value;}
      end;
  'w':if fieldname='width' then begin
       result:=@obj.size.x; varClass:=TVarTypeSingle;
      end;
  'x':if fieldname='x' then begin
       result:=@obj.position.x; varClass:=TVarTypeSingle;
      end;
  'y':if fieldname='y' then begin
       result:=@obj.position.y; varClass:=TVarTypeSingle;
      end;
 end;
end;

class function TVarTypeUIElement.GetValue(variable: pointer): string;
begin
 result:=TUIElement(variable).ClassName+inherited;
end;

class function TVarTypeUIElement.ListFields: String;
begin
 result:='name,x,y,width,height,scale,visible,enabled';
end;

class procedure TVarTypeTranspMode.SetValue(variable:pointer;v:string);
 begin
  v:=lowercase(v);
  if v='transparent' then TElementShape(variable^):=shapeEmpty else
  if v='custom' then TElementShape(variable^):=shapeCustom else
  if v='opaque' then TElementShape(variable^):=shapeFull else
  raise EWarning.Create('Unknown transparency mode: '+v);
 end;
class function TVarTypeTranspMode.GetValue(variable:pointer):string;
 begin
  case TElementShape(variable^) of
   shapeEmpty:result:='transparent';
   shapeFull:result:='opaque';
   shapeCustom:result:='custom';
  end;
 end;

class procedure TVarTypeSendSignals.SetValue(variable:pointer;v:string);
 begin
  v:=lowercase(v);
  if v='major' then TSendSignals(variable^):=ssMajor else
  if v='all' then TSendSignals(variable^):=ssAll else
  if v='none' then TSendSignals(variable^):=ssNone else
  raise EWarning.Create('Unknown SendSignals mode: '+v);
 end;
class function TVarTypeSendSignals.GetValue(variable:pointer):string;
 begin
  case TSendSignals(variable^) of
   ssMajor:result:='major';
   ssAll:result:='all';
   ssNone:result:='none';
  end;
 end;

class procedure TVarTypeBtnStyle.SetValue(variable:pointer;v:string);
 begin
  v:=lowercase(v);
  if v='normal' then TButtonStyle(variable^):=bsNormal else
  if v='switch' then TButtonStyle(variable^):=bsSwitch else
  if (v='item') or (v='checkbox') then TButtonStyle(variable^):=bsCheckbox else
  raise EWarning.Create('Unknown BtnStyle: '+v);
 end;
class function TVarTypeBtnStyle.GetValue(variable:pointer):string;
 begin
  case TButtonStyle(variable^) of
   bsNormal:result:='normal';
   bsSwitch:result:='switch';
   bsCheckbox:result:='checkbox';
  end;
 end;

{ TVarTypePivot }

class function TVarTypePivot.GetValue(variable: pointer): string;
 var
  p:TPoint2s;
 begin
  p:=TPoint2s(variable^);
  result:=Format('(%.2f,%.2f)',[p.x,p.y]);
 end;

class procedure TVarTypePivot.SetValue(variable: pointer; v: string);
 begin
  if SameText(v,'Center') then TPoint2s(variable^):=pivotCenter else
  if SameText(v,'TopLeft') then TPoint2s(variable^):=pivotTopLeft else
  if SameText(v,'TopRight') then TPoint2s(variable^):=pivotTopRight else
  if SameText(v,'BottomLeft') then TPoint2s(variable^):=pivotBottomLeft else
  if SameText(v,'BottomRight') then TPoint2s(variable^):=pivotBottomRight else
  raise EWarning.Create('Invalid pivot value: '+v);
 end;

{ TVarTypeStyleinfo }

class function TVarTypeStyleinfo.GetValue(variable:pointer):string;
 begin
  result:=TUIElement(variable).styleInfo;
 end;

class procedure TVarTypeStyleinfo.SetValue(variable:pointer; v:string);
 begin
  TUIElement(variable).styleInfo:=v;
 end;

{ TVarTypeElementFont }

class function TVarTypeElementFont.GetValue(variable:pointer):string;
 begin
  result:='$'+IntToHex(TUIElement(variable).font,sizeof(TFontHandle) div 2);
 end;

class procedure TVarTypeElementFont.SetValue(variable:pointer; v:string);
 begin
  TUIElement(variable).font:=TFontHandle(ParseInt(v));
 end;

{ TVarTypeAlignment }

class function TVarTypeAlignment.GetValue(variable:pointer):string;
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

class procedure TVarTypeAlignment.SetValue(variable:pointer; v:string);
 var
  a:^TTextAlignment;
 begin
  a:=variable;
  a^:=StrToAlign(v);
 end;

function GetVarTypeFor(typeName:string):TVarClass;
 begin
  if SameText(typeName,'TTextAlignment') then result:=TVarTypeAlignment;
 end;

{ TVarTypeElementName }

class function TVarTypeElementName.GetValue(variable:pointer):string;
 begin
  result:=''''+TUIElement(variable).name+'''';
 end;

class procedure TVarTypeElementName.SetValue(variable:pointer;v:string);
 begin
  TUIElement(variable).name:=v;
 end;

{ TVarTypeObjColor }

class function TVarTypeElementColor.GetValue(variable:pointer):string;
 begin
  result:='$'+IntToHex(TUIElement(variable).color,8);
 end;

class procedure TVarTypeElementColor.SetValue(variable:pointer;v:string);
 begin
  TUIElement(variable).color:=ParseInt('$'+v);
 end;

{ TVarTypeElementScale }

class function TVarTypeElementScale.GetValue(variable: pointer): string;
 begin
  result:=FloatToStr(TUIElement(variable).globalScale);
 end;

class procedure TVarTypeElementScale.SetValue(variable: pointer; v: string);
 begin
  raise EWarning.Create('GlobalScale is a read-only property');
 end;

{ TVarTypeClientWidth }

class function TVarTypeClientWidth.GetValue(variable: pointer): string;
 begin
  result:=FloatToStr(TUIElement(variable).clientWidth);
 end;

class procedure TVarTypeClientWidth.SetValue(variable: pointer; v: string);
 begin
  raise EWarning.Create('ClientWidth is a read-only property');
 end;

{ TVarTypeClientHeight }

class function TVarTypeClientHeight.GetValue(variable: pointer):string;
 begin
  result:=FloatToStr(TUIElement(variable).clientWidth);
 end;

class procedure TVarTypeClientHeight.SetValue(variable: pointer; v: string);
 begin
  raise EWarning.Create('ClientHeight is a read-only property');
 end;

{ TVarTypeElements }

class function TVarTypeElements.GetValue(variable: pointer):string;
 var
  list:^TUIElements;
  i:integer;
 begin
  list:=variable;
  for i:=0 to high(list^) do begin
   if result<>'' then result:=result+', ';
   result:=result+Format('%d:%s(''%s'')',[i,list^[i].className,list^[i].name]);
  end;
  result:='['+result+']';
 end;

class procedure TVarTypeElements.SetValue(variable: pointer; v: string);
 begin
  raise EWarning.Create('TUIElements is a read-only type');
 end;

initialization
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
