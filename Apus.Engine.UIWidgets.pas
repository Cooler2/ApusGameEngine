// -----------------------------------------------------
// Standard widget classes
//
// Author: Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// ------------------------------------------------------
unit Apus.Engine.UIWidgets;
interface
 uses Apus.MyServis, Apus.CrossPlatform, Apus.AnimatedValues,
   Apus.Engine.API, Apus.Engine.UITypes;

 {$WRITEABLECONST ON}
 {$IFDEF CPUARM} {$R-} {$ENDIF}

 const
  // ��������� ���� (��������� ���������, ����� ������)
  wcFrameBorder:integer=5;   // ������ ����� ����
  wcTitleHeight:integer=24;  // ������ ��������� ����

  // Window area flags
  wcLeftFrame   =  1;
  wcTopFrame    =  2;
  wcRightFrame  =  4;
  wcBottomFrame =  8;
  wcHeader      = 16; // area that can be used to drag and move the window
  wcClient      = 32; // client part of the window

 type
  // ������� � ������������� �������
  TUIFlexControl=class(TUIElement)
   minWidth,minHeight:integer;
   maxWidth,maxHeight:integer;
  end;

  // ������� "�����������". �������� ������� ����������� �����������
  TUIImage=class(TUIElement)
   color:cardinal;  // drawing color (default is $FF808080)
   src:string; // ����� ����� ���� ��� ����� ��� ������ "event:xxx", "proc:XXXXXXXX" etc...
   constructor Create(width,height:single;imgname:string;parent_:TUIElement);
   procedure SetRenderProc(proc:pointer); // sugar for use "proc:XXX" src for the default style
  end;

  // �������� ��� ��������� - ����������� ���������� ���� ������ ������� ��������, ������� �� � ��������
  // It captures mouse drag events, but passes clicks through
  TUIScrollArea=class(TUIElement)
   fullWidth,fullHeight:single; // full content area
   direction:TUIScrollDirection;
   constructor Create(width,height,fullW,fullH:single;dir:TUIScrollDirection;parent_:TUIElement);
   procedure onMouseMove; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onTimer; override;
  protected
   speedX,speedY:single;
   lastTime:cardinal;
   isHooked:boolean;
  end;

  // ������ �����
  // ������ ��������� ������������� ��� ����������� �����������,
  // ��������� ��� ���� ���������� ����� ��������� ��� ������������ �������� �� ���������
  TUIHint=class(TUIImage)
   simpleText:string; // ����� �������
   active:boolean; // ���� true - ������ ���� ��������, �� ���������� � �������� ��������� ��-��
   created:int64; // ������ �������� (� ��.)
   adjusted:boolean; // ���������� ����� ������������ ��� ��� ������������� ���������� �����

   constructor Create(x,y:single;text:string;act:boolean;parent_:TUIElement);
   destructor Destroy; override;
   procedure Hide;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onTimer; override;
  end;

  TUILabel=class(TUIElement)
   caption:string;
   color:cardinal;
   align:TTextAlignment;
   topOffset:integer; // ����� ������ �����
   constructor Create(width,height:single;labelname,text:string;color_:cardinal;bFont:TFontHandle;parent_:TUIElement);
  end;

  // ��� ������
  TButtonStyle=(bsNormal,   // ������� ������
                bsSwitch,   // ������-������������� (������������� � ������� ���������)
                bsCheckbox);    // ������-������� (�������)
  TUIButton=class(TUIImage)
   caption:string; // button's label
   default:boolean; // ������ �� ��������� (������ ������ �� ���������, �� �� �� ���������!!!)
   pressed:boolean; // ������ ��������
   pending:boolean; // ��������� ��������� ������������� (�� ��������� �� �������)
   autoPendingTime:integer; // ����� (� ��) �� ������� ������ ����������� � ��������� pending ��� ������� (0 - �� �����������)

   btnStyle:TButtonStyle; // ��� ������ (������ ��� �� ���������, ��� � �� ���������)
   group:integer;   // ������ ��������������
   onClick:TProcedure;
   constructor Create(width,height:single;btnName,btnCaption:string;btnFont:TFontHandle;parent_:TUIElement);

   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onMouseMove; override;
   function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
   procedure onHotKey(keycode:byte;shiftstate:byte); override;
   procedure onTimer; override; // �������� ������ �� �������
   procedure SetPressed(pr:boolean); virtual;
   procedure MakeSwitches(sameGroup:boolean=true); // make all sibling buttons with the same size - switches
   procedure Click; virtual; // simulate click
  protected
   procedure DoClick;
  private
   lastPressed,pendingUntil:int64;
   lastOver:boolean; // was under mouse when onMouseMove was called last time
  end;

  // �����
  TUIFrame=class(TUIElement)
   constructor Create(width,height:single;depth,style_:integer;parent_:TUIElement);
   procedure SetBorderWidth(w:integer); virtual;
  protected
   borderWidth:integer; // ������ �����
  end;

  // Basic window
  TUIWindow=class(TUIImage)
   caption:string;
   header:integer; // ������ ���������
   autoBringToFront:boolean; // ������������� ���������� ���� �� �������� ���� ��� ����� �� ���� ��� ������ ���������� ��-��
   moveable:boolean;    // ���� ����� ����������
   resizeable:boolean;  // ���� ����� �����������
   minW,minH,maxW,maxH:integer; // ������������ � ����������� ������� (��� ��������������� ����)

   constructor Create(innerWidth,innerHeight:single;sizeable:boolean;wndName,wndCaption:string;wndFont:TFontHandle;parent_:TUIElement);

   // ���������� ����� ���� ������� � ��������� ����� (�-�� �������� (� ��������)
   // � ����� ������, ������� ����� ������� ��� ���� �������
   // ��� �-��� ����� �������������� ��� �������� ���� ����������� ����� ��� ���������
   function GetAreaType(x,y:integer;out cur:integer):integer; virtual;

   procedure onMouseMove; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onLostFocus; override;
   procedure Resize(newWidth,newHeight:single); override;
   class function IsWindow:boolean; override;
  private
   hooked:boolean;
   area:integer;   // ��� ������� ��� ��������
  end;

  // ������������� ����: ���� �� ������
  // �������� �����������: ����� ������������� ������ � �������� ��������������� �����,
  // � ����� ��� � ���� ��������
  // ����� ���� ��������� � ���������� ����������� � ������ ����� ������������� �����
  TUISkinnedWindow=class(TUIWindow)
   dragRegion:TRegion; // �������, �� ������� ����� ������� ���� (���� �� ������ - �� �� ����� �����)
   background:pointer; // ����� ��������� �� ��� ���� (�.�. ������� ��������� � ���� ������ �� �������������)
   constructor Create(wndName,wndCaption:string;wndFont:TFontHandle;parent_:TUIElement;canmove:boolean=true);
   destructor Destroy; override;
   function GetAreaType(x,y:integer;out cur:integer):integer; override; // x,y - screen space coordinates
  end;

  TUIEditBox=class(TUIElement)
   realText:WideString; // �������� ����� (����� ������������ ��� ����, � �� text)
   completion:WideString; // grayed background text, if it is not empty and enter is pressed, then it is set to realText
   defaultText:WideString; // grayed background text, displayed if realText is empty
   color,backgnd:cardinal;
   cursorpos:integer;      // ��������� ������� (����� �������, ����� �������� ��������� ������)
   maxlength:integer;      // ������������ ����� ������������� ������
   password:boolean;    // ���� ��� ����� ������
   noborder:boolean;    // �������� �� ����� ��� ������ ������������� ����� (��� ����������� � ������ ��-��)
   selstart,selcount:integer; // ���������� �������� ������
   cursortimer:int64;    // ��������� ������ ��� ��������� �������
   needpos:integer;    // �������� ��������� ������� � �������� (��� �����������)
   msselect:boolean;  // ��������� �����
   protection:byte;   // xor ���� �������� � ���� ������
   offset:integer; // ����� ������ ����������� �� ������� ��������

   constructor Create(width,height:single;boxName:string;boxFont:TFontHandle;color_:cardinal;parent_:TUIElement);
   procedure onChar(ch:char;scancode:byte); override;
   procedure onUniChar(ch:WideChar;scancode:byte); override;
   function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onMouseMove; override;

   procedure SetFocus; override;
   procedure onLostFocus; override;
   procedure SelectAll; virtual;
  private
   savedText:WideString;
   lastClickTime:int64;
   msSelStart:integer; // ����� ������� � ���� ������� ��������� ����� ������ ��������� �����
   procedure AdjustState;
   function GetText:String8;
   procedure SetText(s:String8);
  public
   property text:String8 read GetText write SetText;         // ������������� ����� (� �������� ���������)
  end;

  // ������ ���������
  TUIScrollBar=class(TUIElement)
  private
   rValue:TAnimatedValue;
   function GetValue:single;
   procedure SetValue(v:single);
   function GetAnimating:boolean;
   procedure SetPageSize(pageSize:single);
   function GetStep:single;
  public
   min,max:single; // ������� ���������
   pagesize:single; // ������ �������� (� �������� ���������)
   step:single; // add/subtract this amount with mouse scroll or similar events
   color:cardinal;
   horizontal:boolean;
   over:boolean;
   constructor Create(width,height:single;barName:string;parent_:TUIElement);
   function GetScroller:IScroller;
   function SetRange(newMin,newMax,newPageSize:single):TUIScrollBar;
   // ����������� �������� � ��������� �������
   procedure MoveTo(val:single;smooth:boolean=false); virtual;
   procedure MoveRel(delta:single;smooth:boolean=false); virtual;
   // ������� �������� � ������� ����������
   procedure Link(elem:TUIElement); virtual;
   // ������� �� ���� ������ ����� �������������� ��� ����������� ��������
   procedure UseButtons(lessBtn,moreBtn:string);

   procedure onMouseMove; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onLostFocus; override;
   property value:single read GetValue write SetValue;
   property isAnimating:boolean read GetAnimating;
  protected
   linkedControl:TUIElement;
   delta:integer; // �������� ����� ������� ������������ ����� ������ �������� (���� hooked)
   needval:integer; // ��������, � �������� ����� ������ ������
   moving:boolean;
   scroller:TObject;
  end;

  TUIListBox=class(TUIElement)
   lines:StringArr;
   tags:array of cardinal;
   hints:StringArr; // � ������� �������� ����� ���� ���� ���� (������������ ��� ��������� �� ����)
   lineHeight:single; // in self CS
   selectedLine,hoverLine:integer; // ���������� ������, ������ ��� ����� (0..count-1), -1 == �����������
   autoSelectMode:boolean; // �����, ��� ������� ������ ���������� ������ ��� ����� (��� �������)
   bgColor,bgHoverColor,bgSelColor,textColor,hoverTextColor,selTextColor:cardinal; // ����� ���������
   constructor Create(width,height:single;lHeight:single;listName:string;font_:TFontHandle;parent:TUIElement);
   destructor Destroy; override;
   procedure AddLine(line:string;tag:cardinal=0;hint:string=''); virtual;
   procedure SetLine(index:integer;line:string;tag:cardinal=0;hint:string=''); virtual;
   procedure ClearLines;
   procedure SetLines(newLines:StringArr); virtual;
   procedure onMouseMove; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure UpdateScroller;
  end;

  // ���������� ������
  TUIComboBox=class(TUIButton)
   items,hints:WStringArr;
   tags:IntArray;
   defaultText:WideString;
   fCurItem,fCurTag:integer;
   // pop up elements
   frame:TUIFrame;
   popup:TUIListBox;
   maxlines:integer; // max lines to show without scrolling
   constructor Create(width,height:single;bFont:TFontHandle;list:WStringArr;parent_:TUIElement;name:string);
   procedure AddItem(item:WideString;tag:cardinal=0;hint:WideString=''); virtual;
   procedure SetItem(index:integer;item:WideString;tag:cardinal=0;hint:string=''); virtual;
   procedure ClearItems;
   procedure onDropDown; virtual;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onTimer; override; // ����: ������������ ��� �������� �� ����������� �������, ����� �� �������������� � ���������
   procedure SetCurItem(item:integer); virtual;
   procedure SetCurItemByTag(tag:integer); virtual;
   property curItem:integer read fCurItem write SetCurItem;
   property curTag:integer read fCurTag write SetCurItemByTag;
  end;

implementation
 uses SysUtils, Types, Apus.EventMan, Apus.Geom2D, Apus.Clipboard;

 type
  TScrollBarInterface=class(TInterfacedObject, IScroller)
   owner:TUIScrollBar;
   constructor Create(owner:TUIScrollbar);
   function GetElement:TUIElement;
   procedure SetRange(min,max:single);
   procedure SetValue(v:single);
   procedure SetStep(step:single);
   procedure SetPageSize(pageSize:single);
   procedure MoveRel(delta:single;smooth:boolean);
   function GetValue:single;
   function GetStep:single;
   function GetPageSize:single;
  end;

 var
  comboPop:TUIComboBox;      // ���� ���������� �������� ��������� (� �� ����� ���� ������ ����) - �� ���

 { TUIimage }

 constructor TUIimage.Create(width,height:single;imgname:string;parent_:TUIElement);
  begin
   inherited Create(width,height,parent_,imgName);
   color:=$FF808080;
   src:='';
   shape:=shapeEmpty;
  end;

 procedure TUIImage.SetRenderProc(proc:pointer);
  begin
   style:=0;
   src:='proc:'+FormatHex(UIntPtr(proc));
  end;

 { TUIButton }

 procedure TUIButton.Click;
  begin
   onMouseButtons(1,true);
   onMouseButtons(1,false);
  end;

 constructor TUIButton.Create;
  var
   i:integer;
  begin
   inherited Create(width,height,btnName,parent_);
   shape:=shapeFull;
   font:=BtnFont;
   btnStyle:=bsNormal;
   group:=0;
   caption:=BtnCaption;
   default:=true; // make it default unless there is another sibling button
   if parent<>nil then
    if parent.children<>nil then
     for i:=0 to high(parent.children) do
      if parent.children[i] is TUIButton then
       default:=false;
   pressed:=false;
   pending:=false;
   autoPendingTime:=0;
   CanHaveFocus:=false;
   color:=$FFC0D0D0;
   sendSignals:=ssMajor;
   //CheckAndSetFocus;
   lastPressed:=0;
  end;

 procedure TUIButton.DoClick;
  var
   i:integer;
  begin
   // Toggle switch button
   if btnStyle<>bsNormal then begin
    if group=0 then SetPressed(not pressed)
     else begin
      ASSERT(parent<>nil);
      for i:=0 to length(parent.children)-1 do
       if (parent.children[i] is TUIButton) and ((parent.children[i] as TUIButton).group=group) then
        (parent.children[i] as TUIButton).SetPressed(false);
      SetPressed(true);
     end;
    if (sendSignals<>ssNone) and
       (pressed or (btnStyle=bsCheckbox)) then begin
      Signal('UI\'+name+'\Click',byte(pressed));
      Signal('UI\onButtonDown\'+name,TTag(self));
      if Assigned(onClick) then onClick;
    end;
   end else begin
    if pending then exit;
    // ������ �� ������� ������
    if (sendSignals<>ssNone) and (MyTickCount>lastPressed+50) then begin
     Signal('UI\'+name+'\Click',byte(pressed));
     Signal('UI\onButtonClick\'+name,TTag(self));
     if Assigned(onClick) then onClick;
     lastPressed:=MyTickCount;
    end;
   end;
  end;

 procedure TUIButton.onHotKey(keycode,shiftstate:byte);
  begin
   if btnStyle=bsNormal then begin
    SetPressed(true);
    DoClick;
    timer:=150;
   end else
    DoClick;
  end;

 function TUIButton.onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean;
  begin
   result:=inherited onKey(keycode,pressed,shiftstate);
   if pressed and (keycode in [VK_RETURN,VK_SPACE]) then begin // Enter
    onHotKey(keycode,shiftstate);
    result:=false;
   end;
  end;

 procedure TUIButton.onMouseButtons(button:byte;state:boolean);
  begin
   if not enabled then begin
    Signal('UI\'+name+'\ClickDisabled',button);
    exit;
   end;
   // Regular button
   if (button=1) and (btnStyle=bsNormal) then begin
    if not pressed and state then SetPressed(true); // ������
    if pressed and not state then begin // ��������� � ������������
     DoClick;
     SetPressed(false);
    end;
   end;
   // Special button
   if (button=1) and (btnStyle<>bsNormal) and state then DoClick;
   inherited;
  end;

 procedure TUIButton.onMouseMove;
  begin
   inherited;
   if not lastover and (undermouse=self) then
    Signal('UI\onButtonOver\'+name);
   if lastover and (undermouse<>self) then
    Signal('UI\onButtonOut\'+name);
   if btnStyle=bsNormal then begin
    if pressed and (underMouse<>self) then
     SetPressed(false);
   end;
   lastover:=undermouse=self;
  end;

 procedure TUIButton.onTimer;
  begin
   if btnStyle=bsNormal then begin
    SetPressed(false);
   end;
  end;

 procedure TUIButton.SetPressed(pr: boolean);
  begin
   pressed:=pr;
   if (sendSignals<>ssNone) then begin
    if btnStyle<>bsNormal then begin
     Signal('UI\onButtonSwitch\'+name);
     Signal('UI\'+name+'\Toggle');
    end else begin
     if pr then Signal('UI\onButtonDown\'+name)
       else     Signal('UI\onButtonUp\'+name);
    end;
   end;
  end;

 procedure TUIButton.MakeSwitches(sameGroup:boolean=true); // make all sibling buttons with the same size - switches
  var
   i:integer;
   b:TUIButton;
   first:boolean;
  begin
   if parent=nil then exit;
   first:=true;
   for i:=0 to high(parent.children) do begin
    if not (parent.children[i] is TUIButton) then continue;
    b:=TUIButton(parent.children[i]);
    if not b.visible then continue;
    if abs(b.size.x-size.x)+abs(b.size.y-size.y)>=1 then continue;
    b.btnStyle:=bsSwitch;
    if sameGroup then begin
     b.group:=1;
     if first then begin
      b.pressed:=true;
      first:=false;
     end;
    end else
     b.group:=i+1;
   end;
  end;

 { TUILabel }

 constructor TUILabel.Create(width,height:single;labelname,text:string;color_,bFont:TFontHandle;
    parent_: TUIElement);
  begin
   inherited Create(width,height,parent_,labelName);
   shape:=shapeFull;
   color:=color_;
   align:=taLeft;
   sendSignals:=ssMajor;
   font:=bFont;
   topOffset:=0;
   caption:=text;
  end;


 { TUIWindow }

 constructor TUIWindow.Create(innerWidth,innerHeight:single;sizeable:boolean;wndName,
    wndCaption:string;wndFont:TFontHandle;parent_:TUIElement);
  var
   deltaX,deltaY:integer;
  begin
   resizeable:=sizeable;
   if resizeable then begin
    deltaX:=wcFrameBorder; deltay:=wcFrameBorder;
   end else begin
    deltaX:=2; deltay:=2;
   end;
   inherited Create(innerWidth+deltaX*2,innerHeight+deltay+wcTitleHeight,wndName,parent_);
   paddingLeft:=deltaX; paddingTop:=wcTitleHeight;
   paddingRight:=deltaX; paddingBottom:=deltaY;

   shape:=shapeFull;
   caption:=wndCaption;
   font:=wndFont;
   header:=wcTitleHeight;
   autoBringToFront:=true;
   canhavefocus:=false;
   moveable:=true;
   minW:=32; minH:=32;
   maxW:=1600; maxH:=1200;
   color:=$FFBCB8B0;
   area:=0;
   order:=100; // ���� ��� ������ ��������.
  end;

 function TUIWindow.GetAreaType(x,y:integer;out cur:integer):integer;
  var
   c:byte;
   r:TRect;
  begin
   result:=0; cur:=crDefault;
   r:=GetPosOnScreen;
   if (x<r.left) or (y<r.top) or (x>=r.Right) or (y>=r.Bottom) then exit;
   dec(x,r.Left);
   dec(y,r.Top);
   if resizeable then begin
    if x<wcFrameBorder then inc(result,wcLeftFrame);
    if y<wcFrameBorder then inc(result,wcTopFrame);
    if x+wcFrameBorder>=r.Width then inc(result,wcRightFrame);
    if y+wcFrameBorder>=r.Height then inc(result,wcBottomFrame);
    if (result=0) and (y<header) then inc(result,wcHeader);
   end else begin
    if y<header then inc(result,wcHeader);
   end;
   if result=0 then inc(result,wcClient);

   c:=0;
   if result and (wcLeftFrame+wcRightFrame)>0 then inc(c);
   if result and (wcTopFrame+wcBottomFrame)>0 then inc(c,2);
   case c of
    1:cur:=crResizeW;
    2:cur:=crResizeH;
    3:cur:=crResizeHW;
   end;
  end;

 procedure TUIWindow.onLostFocus;
  begin
   hooked:=false;
  end;

 procedure TUIWindow.onMouseButtons(button:byte;state:boolean);
  var
   pnt:TPoint;
  begin
   inherited;
   if (button=1) and not (area in [0,wcClient]) then begin
    if not hooked and state then hooked:=true;
    if hooked and not state then begin
     hooked:=false;
     // Don't allow window center to be moved outside screen
     pnt:=GetPosOnScreen.CenterPoint;
     /// TODO: implement action
    end;
   end;
  end;

 procedure TUIWindow.onMouseMove;
  var
   iScale:Tvector2s;
   dx,dy:single;
  begin
   if hooked then begin
    iScale:=VectDiv(scale,globalScale); // pixels to parent's space scale
    dx:=(curMouseX-oldMouseX)*iScale.x;
    dy:=(curMouseY-oldMouseY)*iScale.y;
    // Drag
    if area=wcHeader then begin
     position:=PointAdd(position, Point2s(dx,dy));
    end;
    // Resize
    if area and wcRightFrame>0 then Resize(size.x+dx,-1);
    if area and wcBottomFrame>0 then Resize(-1,size.y+dy);
    if area and wcLeftFrame>0 then begin Resize(size.x-dx,-1); position.x:=position.x-dx; end;
    if area and wcTopFrame>0 then begin Resize(-1,size.y-dy); position.y:=position.y-dy; end;
   end;

   inherited;
   area:=GetAreaType(curMouseX,curMouseY,cursor);
   if area in [0,wcClient] then hooked:=false;
  end;

 procedure TUIWindow.Resize(newWidth,newHeight:single);
  begin
   if newwidth<>-1 then begin
    if newwidth<minW then newwidth:=minW;
    if newwidth>maxW then newwidth:=maxW;
   end;
   if newheight<>-1 then begin
    if newheight<minH then newheight:=minH;
    if newheight>maxH then newheight:=maxH;
   end;
   inherited;
  end;

 class function TUIWindow.IsWindow:boolean;
  begin
   result:=true;
  end;


 { TUIEditBox }

 procedure TUIEditBox.AdjustState;
  begin
   if cursorpos>length(realtext) then cursorpos:=length(realtext);
   if selstart>length(realtext) then selstart:=length(realtext);
   if selstart+selcount>length(realtext)+1 then selcount:=length(realtext)-selstart+1;
  end;

 constructor TUIEditBox.Create(width,height:single;boxName:string;
    boxFont:TFontHandle;color_:cardinal;parent_:TUIElement);
  begin
   inherited Create(width,height,parent_,boxName);
   shape:=shapeFull;
   cursor:=crInput;
   realtext:='';
   selstart:=0;
   selcount:=0;
   cursorpos:=0;
   font:=boxFont;
   maxlength:=240;
   password:=false;
   backgnd:=0;
   color:=color_;
   protection:=0;
   needPos:=-1;
   offset:=0;
   // �������� ������
   canhavefocus:=true; //CheckAndSetFocus;
   sendSignals:=ssAll;
   completion:='';
   defaultText:='';
   lastClickTime:=0;
  end;

 function TUIEditBox.GetText:String8;
  begin
   result:=Str8(realtext);
  end;

 procedure TUIEditBox.SetText(s:String8);
  begin
   realtext:=DecodeUTF8(s);
   if cursorpos>length(realtext) then cursorpos:=length(realtext);
  end;

 procedure TUIEditBox.onChar(ch:char;scancode:byte);
  begin
   inherited;
  end;

 procedure TUIEditBox.onUniChar(ch:WideChar;scancode:byte);
  var
   oldText:WideString;
  begin
   oldText:=realText;
   AdjustState;
   cursortimer:=mytickcount;
   if (ch=#13) and (sendSignals<>ssNone) then begin
    if (completion<>'') and (realText<>completion) then begin
     realText:=completion;
     completion:='';
     cursorpos:=length(realtext);
     selcount:=0;
     Signal('UI\'+name+'\AutoCompletion',0);
    end else
     Signal('UI\'+name+'\Enter',0);
   end;
   if (ch=#27) and (sendSignals<>ssNone) then Signal('UI\'+name+'\Escape',0);
   if (ch>=#32) and (selcount>0) then begin
    delete(realtext,selstart,selcount);
    insert(ch,realtext,selstart);
    selcount:=0;
    cursorpos:=selstart;
    exit;
   end;
   if (length(realtext)<maxlength) and (ch>=#32) then begin
    inc(cursorpos);
    insert(ch,realtext,cursorpos);
   end;
   if (sendSignals=ssAll) and (oldText<>realText) then begin
    savedText:=oldText;
    Signal('UI\'+name+'\changed',0);
   end;
  end;

 function TUIEditBox.onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean;
   procedure ClipCopy(cut:boolean=false);
    var
     str:string;
    begin
     if password or (protection<>0) then exit;
     str:=copy(realtext,selstart,selcount);
     CopyStrToClipboard(str);
     if cut then begin
      delete(realtext,selstart,selcount); selcount:=0; cursorpos:=selstart-1;
     end;
    end;
   procedure ClipPaste;
    var
     str:string;
     wst:WideString;
    begin
     wst:=PasteStrFromClipboardW;
     if wst<>'' then begin
      if selcount>0 then begin
       delete(realtext,selstart,selcount);
       cursorpos:=selstart-1;
      end else
       selstart:=cursorpos+1;
      insert(wst,realtext,cursorpos+1);
      selcount:=length(str);
      if length(realtext)>maxlength then setLength(realtext,maxlength);
      if selstart+selcount-1>length(realtext) then selcount:=length(realtext)-selstart+1;
      cursorpos:=selstart+selcount-1;
     end;
    end;
  var
   step:integer;
   oldText:string;
  begin
   oldText:=realText;
   AdjustState;
   result:=inherited onKey(keycode,pressed,shiftstate);
   if pressed then begin
    cursortimer:=mytickcount;

    if (keycode=VK_LEFT) then begin // Left
     step:=1;
     if shiftstate and sscCtrl>0 then begin // ����� ����� ��� �� 1 ������
      while (cursorpos-step>0) and (realtext[cursorpos-step]>='A') do inc(step);
     end;

     if shiftstate and sscShift>0 then begin
      if (selcount>0) and (cursorpos>=selstart) then dec(selcount,step)
      else
      if (selcount>0) and (cursorpos>0) and (cursorpos<selstart) then
       begin dec(selstart,step); inc(selcount,step); end
      else
      if (selcount=0) and (cursorpos>0) then
       begin selstart:=cursorpos; selcount:=1; end;
     end else selcount:=0;
     if (cursorpos>0) then dec(cursorpos,step);
     if cursorpos<0 then cursorpos:=0;
    end;

    if (keycode=VK_RIGHT) and (cursorpos<length(realtext)) then begin // Right
     step:=1;
     if shiftstate and sscCtrl>0 then begin // ����� ����� ��� �� 1 ������
      while (cursorpos+step<length(realtext)) and not ((realtext[cursorpos+step+1]>='A')
       and not (realtext[cursorpos+step]>='A')) do inc(step);
     end;

     if shiftstate and sscShift>0 then begin
      if (selcount>0) and (cursorpos<length(realtext)) and (cursorpos>=selstart) then inc(selcount,step)
      else
      if (selcount>0) and (cursorpos<selstart) then
       begin inc(selstart,step); dec(selcount,step); end
      else
      if (selcount=0) and (cursorpos<length(realtext)) then
       begin selstart:=cursorpos+1; selcount:=1; end;
     end else selcount:=0;
     if (cursorpos<length(realtext)) then inc(cursorpos,step);
     if cursorpos>length(realtext) then cursorpos:=length(realtext);
    end;

    if keycode=VK_HOME then begin  // Home
     if shiftstate and sscShift>0 then begin
      inc(selcount,cursorpos); selstart:=1;
     end else selcount:=0;
     cursorpos:=0;
    end;
    if keycode=VK_END then begin // End
     if shiftstate and sscShift>0 then begin
      if selcount=0 then selstart:=cursorpos+1;
      inc(selcount,length(realtext)-cursorpos);
     end else selcount:=0;
     cursorpos:=length(realtext);
    end;

    if (keycode=VK_BACK) and (shiftState and sscAlt=0) then begin // backspace
     if selcount>0 then
      begin delete(realtext,selstart,selcount); selcount:=0; cursorpos:=selstart-1; end
     else begin
      if cursorpos>0 then begin delete(realtext,cursorpos,1); dec(cursorpos); end;
     end;
    end;

    // Ctrl+C = Copy
    if (keycode=ord('C')) and (shiftState=sscCtrl) and (selcount>0) then clipCopy;
    // Ctrl+X = Cut
    if (keycode=ord('X')) and (shiftState=sscCtrl) and (selcount>0) then clipCopy(true);
    // Ctrl+V = Paste
    if (keycode=ord('V')) and (shiftState=sscCtrl) then
     clipPaste;
    // Ctrl+A: Select all
    if (keycode=ord('A')) and (shiftState=sscCtrl) then
     SelectAll;

    // Ctrl+Z or Alt+BkSp - undo
    if ((keycode=ord('Z')) and (shiftState=sscCtrl)) or
       ((keycode=VK_BACK) and (shiftState=sscAlt)) then begin
     realText:=savedText;
    end;

    if keycode=VK_INSERT then begin // ins
     if (selcount>0) and (shiftstate=sscCtrl) then clipCopy;
     if shiftstate and sscShift>0 then clipPaste;
    end;
    if keycode=VK_DELETE then begin // del
     if selcount>0 then begin
      if shiftstate and sscShift>0 then ClipCopy(true) // Cut
       else begin
        delete(realtext,selstart,selcount); selcount:=0; cursorpos:=selstart-1;
       end;
     end else begin
      if (cursorpos<length(realtext)) then begin
       delete(realtext,cursorpos+1,1);
      end;
     end;
    end;
   end;
   if (sendSignals=ssAll) and (oldText<>realText) then begin
    savedText:=oldText;
    Signal('UI\'+name+'\changed');
   end;
  end;

 procedure TUIEditBox.onMouseButtons(button:byte;state:boolean);
  var
   doubleClick:boolean;
  begin
   doubleClick:=false;
   if (button=1) and (state) then begin
    if MyTickCount<lastClickTime+300 then doubleClick:=true;
    lastClickTime:=MyTickCount;
   end;
   AdjustState;
   inherited;
   needpos:=curMouseX-globalrect.Left-offset;
   if (selcount>0) and (button=1) and state then begin
    selcount:=0; selStart:=0;
   end;
   if (button=1) and state then
    msselect:=true
   else begin
    msselect:=false;
    msSelStart:=0;
   end;
   if doubleclick then begin
    selStart:=1; selCount:=length(realText);
   end;
  end;

 procedure TUIEditBox.onMouseMove;
  begin
   AdjustState;
   inherited;
   if underMouse<>self then begin
    msselect:=false;
    exit;
   end;
   if msselect and (needpos=-1) then begin
    if (msSelStart=0) then msSelStart:=cursorpos;
    if (msSelStart>0) and (cursorpos<>msSelStart) then begin
      if cursorpos<msSelStart then begin
       selstart:=cursorPos+1;
       selcount:=msSelStart-cursorpos;
      end else begin
       selStart:=msSelStart+1;
       selcount:=cursorPos-msSelStart;
      end;
    end;
    needpos:=curMouseX-globalrect.Left-offset;
   end;
  end;

 procedure TUIEditBox.SelectAll;
  begin
   selStart:=1;
   selCount:=length(realText);
   cursorpos:=length(realtext);
  end;

 procedure TUIEditBox.SetFocus;
  begin
   AdjustState;
   inherited;
   SelectAll;
   {$IFDEF IOS}
   Signal('UI\EditBox\onSetFocus',TTag(self));
   {$ENDIF}
  end;

 procedure TUIEditBox.onLostFocus;
  begin
   inherited;
   {$IFDEF IOS}
   Signal('UI\EditBox\onLostFocus',TTag(self));
   {$ENDIF}
  end;

 { TUIScrollBar }

 constructor TUIScrollBar.Create(width,height:single;barName:string;parent_:TUIElement);
  begin
   inherited Create(width,height,parent_,barName);
   shape:=shapeFull;
   min:=0; max:=100; rValue.Init(0); pagesize:=0;
   linkedControl:=nil; step:=1;
   color:=$FFB0B0B0;
   horizontal:=width>height;
   // hooked:=false;
   scroller:=TScrollBarInterface.Create(self);
  end;

 procedure TUIScrollBar.SetPageSize(pageSize:single);
  begin
   self.pagesize:=pagesize;
  end;

function TUIScrollBar.SetRange(newMin,newMax,newPageSize:single):TUIScrollBar;
  begin
   min:=newMin; max:=newMax; pageSize:=newPageSize;
  end;

 function TUIScrollBar.GetValue:single;
  begin
   result:=rValue.value;
   if result>max-pagesize then result:=max-pageSize;
   if result<min then result:=min;
  end;

 procedure TUIScrollBar.Link(elem:TUIElement);
  begin
   LinkedControl:=elem;
  end;

 procedure TUIScrollBar.SetValue(v:single);
  begin
   rValue.Assign(v);
  end;

 function TUIScrollBar.GetAnimating;
  begin
   result:=rValue.isAnimating;
  end;

 function TUIScrollBar.GetScroller:IScroller;
  begin
   result:=scroller as TScrollBarInterface;
  end;

function TUIScrollBar.GetStep:single;
  begin
   result:=step;
  end;

procedure TUIScrollBar.MoveRel(delta:single;smooth:boolean=false);
  begin
   MoveTo(round(rValue.FinalValue)+delta,smooth);
  end;

 procedure TUIScrollBar.MoveTo(val:single;smooth:boolean=false);
  begin
   if val<min then val:=min;
   if val+pagesize>max then val:=max-pagesize;
   if smooth then rValue.Animate(val,300,spline1)
    else rValue.Assign(val);

   Signal('UI\'+name+'\Changed',round(val));
   if linkedControl<>nil then begin
    if linkedcontrol.scrollerH.GetElement=self then
     linkedControl.scroll.X:=value;
    if linkedcontrol.scrollerV.GetElement=self then
     linkedControl.scroll.Y:=value;
   end;
  end;

 procedure TUIScrollBar.onLostFocus;
  begin
   if hooked=self then hooked:=nil;
   clipMouse:=cmNo;
  end;

 procedure TUIScrollBar.onMouseButtons(button:byte;state:boolean);
  var
   p:single;
  begin
   inherited;
   if state and (hooked=nil) and over then begin
    hooked:=self;
    delta:=-1;
    clipMouse:=cmVirtual;
    clipMouseRect:=globalrect;
   end;
   if (hooked=self) and not state then begin
    hooked:=nil;
    clipmouse:=cmNo;
    signal('Mouse\UpdatePos');
   end;
   if not (over or (hooked=self)) and state and globalrect.Contains(Point(curMouseX,curMouseY)) then begin
    // Assume that 0-sized page trackbar is 8 pixels wide
    if horizontal then
     p:=(curMouseX-globalRect.Left-4)/(globalRect.Width-8)
    else
     p:=(curMouseY-globalRect.Top-4)/(globalRect.Height-8);
    if p<0 then p:=0;
    if p>1 then p:=1;
    MoveTo(min+round((max-min-pagesize)*p));
    onMouseMove;
    onMouseButtons(button,true);
   end;
  end;

 procedure TUIScrollBar.onMouseMove;
  var
   p1,p2:single;
   v:integer;
  begin
   inherited;
   if delta=-1 then begin
    p1:=(value-min)/(max-min);
    if p1<0 then p1:=0;
    if horizontal then delta:=curMouseX-globalrect.Left-round(p1*(globalRect.width-8))
     else delta:=curMouseY-globalrect.top-round(p1*(globalRect.height-8));
   end;

   if hooked=self then
    if horizontal then begin
     p1:=(curMouseX-delta-globalrect.Left)/(globalRect.width-8);
     if p1<0 then p1:=0; if p1>1 then p1:=1;
     v:=round(min+(max-min)*p1);
     if v<>value then begin
      MoveTo(v);
     end;
    end else begin
     p1:=(curMouseY-delta-globalrect.top)/(globalRect.Height-8);
     if p1<0 then p1:=0; if p1>1 then p1:=1;
     v:=round(min+(max-min)*p1);
     if v<>value then begin
      MoveTo(v);
     end;
    end;

   p1:=(value-min)/(max-min);
   p2:=(value+pagesize-min)/(max-min);
   if p1<0 then p1:=0;
   if p2>1 then p2:=1;
   if horizontal then begin
    over:=(curMouseY>=globalrect.Top) and (curMouseY<globalrect.Bottom) and
          (curMouseX>=globalrect.Left+round(p1*(globalRect.width-8))) and
          (curMouseX<globalrect.Left+8+round(p2*(globalrect.width-8)));
   end else begin
    over:=(curMouseX>=globalrect.Left) and (curMouseX<globalrect.Right) and
          (curMouseY>=globalrect.Top+round(p1*(globalrect.height-8))) and
          (curMouseY<globalrect.top+8+round(p2*(globalrect.height-8)));
   end;
  end;

 procedure TUIScrollBar.UseButtons(lessBtn,moreBtn:string);
  begin

  end;

  { TUISkinnedWindow }

 constructor TUISkinnedWindow.Create(wndName,wndCaption:string;
    wndFont:TFontHandle;parent_:TUIElement;canmove:boolean=true);
  begin
   inherited Create(100,100,false,wndName,wndCaption,wndFont,parent_);
   dragRegion:=nil;
   background:=nil;
   moveable:=canmove;
   paddingTop:=0; paddingLeft:=0;
   paddingRight:=0; paddingBottom:=0;
  end;

 destructor TUISkinnedWindow.Destroy;
  begin
   dragRegion.Free;
   inherited;
  end;

 function TUISkinnedWindow.GetAreaType(x,y:integer;out cur:integer):integer;
  begin
   result:=0; cur:=crDefault;
   dec(x,globalrect.Left);
   dec(y,globalrect.Right);
   if (x<0) or (y<0) or (x>=globalrect.width) or (y>=globalrect.height) then exit;
   if moveable then result:=wcHeader else result:=wcClient;
   if (dragRegion<>nil) and not dragRegion.TestPoint(x,y) then
    result:=wcClient;
  end;

 { TUIHint }

 constructor TUIHint.Create(x,y:single;text:string;
    act:boolean;parent_:TUIElement);
  begin
   inherited Create(1,1,'hint',parent_);
   SetPos(x,y,pivotTopLeft);
   shape:=shapeFull;
   font:=0;
   simpleText:=text;
   active:=act;
   adjusted:=false;
   created:=MyTickCount;
   parentClip:=false;
  end;

 destructor TUIHint.Destroy;
  begin
   inherited;
  end;

 procedure TUIHint.Hide;
  begin
   if shape<>shapeEmpty then begin
    LogMessage('UIHint Hide');
    shape:=shapeEmpty;
    created:=MyTickCount;
   end;
  end;

 procedure TUIHint.onMouseButtons(button:byte;state:boolean);
  begin
   inherited;
   if state then hide;
  end;

 procedure TUIHint.onTimer;
  begin
   hide;
  end;

 { TUIScrollArea }

 constructor TUIScrollArea.Create(width,height,fullW,fullH:single;
    dir:TUIScrollDirection;parent_:TUIElement);
  begin
   inherited Create(width,height,parent_);
   shape:=shapeFull;
   fullWidth:=fullW;
   fullHeight:=fullH;
   direction:=dir;
  end;

 procedure TUIScrollArea.onMouseButtons(button:byte;state:boolean);
  begin
   if parent<>nil then parent.onMouseButtons(button,state);
  end;

 procedure TUIScrollArea.onMouseMove;
  begin
   if parent<>nil then parent.onMouseMove;
  end;

 procedure TUIScrollArea.onTimer;
  begin

  end;

 { TUIListBox }

 procedure TUIListBox.AddLine(line:string;tag:cardinal=0;hint:string='');
  var
   n:integer;
  begin
   n:=length(lines)+1;
   SetLength(lines,n);
   SetLength(tags,n);
   SetLength(hints,n);
   lines[n-1]:=line;
   tags[n-1]:=tag;
   hints[n-1]:=hint;
   UpdateScroller;
  end;

 procedure TUIListBox.ClearLines;
  begin
   SetLength(lines,0);
   SetLength(tags,0);
   SetLength(hints,0);
   SelectedLine:=-1;
   UpdateScroller;
  end;

 constructor TUIListBox.Create(width,height:single;lHeight:single;listName:string;
   font_:TFontHandle;parent:TUIElement);
  var
   scrollbar:TUIScrollbar;
  begin
   inherited Create(width,height,parent,listName);
   shape:=shapeFull;
   font:=font_;
   lineHeight:=lHeight;
   selectedLine:=-1;
   hoverLine:=-1;
   canHaveFocus:=true;
   sendSignals:=ssMajor;

   scrollBar:=TUIScrollBar.Create(19,height-2,listName+'_scroll',self);
   scrollBar.SetPos(width,1,pivotTopLeft).SetAnchors(1,0,1,1);
   scrollBar.horizontal:=false;
   scrollerV:=scrollBar.GetScroller;
   bgColor:=0;
   textColor:=$E0D0D0D0;
   bgHoverColor:=0;
   hoverTextColor:=$FFD8D8D8;
   bgSelColor:=$90406070;
   selTextColor:=$FFF0F0F0;
   autoSelectMode:=false;
   UpdateScroller;
  end;

 destructor TUIListBox.Destroy;
  begin
   SetLength(lines,0);
   SetLength(tags,0);
   SetLength(hints,0);
   inherited;
  end;

 procedure TUIListBox.onMouseButtons(button:byte;state:boolean);
  begin
   inherited;
   if (button=1) then begin
    if hoverLine>=0 then begin
     selectedLine:=hoverLine;
     if sendSignals<>ssNone then begin
      Signal('UI\'+name+'\SELECTED',selectedLine);
      Signal('UI\ListBox\onSelect\'+name,TTag(self));
     end;
    end;
   end;
  end;

 procedure TUIListBox.onMouseMove;
  var
   cx,cy,n:integer;
  begin
   inherited;
   cx:=curMouseX-(globalRect.Left+1);
   cy:=curMouseY-(globalRect.Top+1);
   if (cx>=0) and (cy>=0) and (cx<globalRect.width-1) and (cy<globalRect.height-1) then begin
    n:=trunc((cy+scrollerV.GetValue)/lineHeight);
    if (n>=0) and (n<length(lines)) then hoverLine:=n
     else hoverLine:=-1;
   end;
   if autoSelectMode then selectedLine:=hoverLine;
   hint:='';
   if (hoverLine>=0) and (hoverLine<=high(hints)) then hint:=hints[hoverLine];
  end;

 procedure TUIListBox.SetLine(index:integer;line:string;tag:cardinal=0;hint:string='');
  begin
   lines[index]:=line;
   tags[index]:=tag;
   hints[index]:=hint;
   UpdateScroller;
  end;

 procedure TUIListBox.SetLines(newLines:StringArr);
  var
   i:integer;
  begin
   SetLength(lines,length(newLines));
   SetLength(tags,length(newLines));
   SetLength(hints,length(newLines));
   for i:=0 to length(lines)-1 do begin
    lines[i]:=newLines[i];
    tags[i]:=0;
    hints[i]:='';
   end;
   if selectedLine>=length(lines) then selectedLine:=length(lines)-1;
   UpdateScroller;
  end;

 procedure TUIListBox.UpdateScroller;
  var
   max:single;
  begin
   max:=length(lines)*lineHeight;
   scrollerV.SetRange(0,max);
   scrollerV.SetStep(round(clientHeight/2) div round(lineHeight));
   scrollerV.SetPageSize(globalRect.height);
   scrollerV.GetElement.size.y:=clientHeight;
   scrollerV.GetElement.visible:=max>clientHeight;
  end;

  { TUIFrame }

 constructor TUIFrame.Create(width,height:single;depth,style_:integer;parent_:TUIElement);
  begin
   inherited Create(width,height,parent_,'UIFrame');
   shape:=shapeFull;
   borderWidth:=depth;
   style:=style_;
   paddingLeft:=depth;  paddingTop:=depth;
   paddingRight:=depth; paddingBottom:=depth;
  end;

 { TUIComboBox }

 procedure TUIComboBox.AddItem(item:WideString;tag:cardinal;hint:WideString);
  var
   n:integer;
  begin
   n:=length(items)+1;
   SetLength(items,n);
   SetLength(tags,n);
   SetLength(hints,n);
   items[n-1]:=item;
   tags[n-1]:=tag;
   hints[n-1]:=hint;
  end;

 procedure TUIComboBox.ClearItems;
  begin
   SetLength(items,0);
   SetLength(tags,0);
   SetLength(hints,0);
  end;

 procedure ComboEventHandler(event:TEventStr;tag:TTag);
  var
   e:TUIElement;
  begin
   if HasPrefix(event,'MOUSE\BTNDOWN',true) then begin
    // if clicked on an element which is not child of the active combobox - hide it
    e:=underMouse;
    if (comboPop<>nil) and (e<>nil) and
      not (e.HasParent(comboPop) or e.HasParent(comboPop.frame)) then comboPop.onDropDown;
   end;
  end;

 constructor TUIComboBox.Create(width,height:single;bFont:TFontHandle;list:WStringArr;
    parent_:TUIElement;name:string);
  var
   btn:TUIButton;
   i,j:integer;
  begin
   inherited Create(width,height,name,'',bFont,parent_);
   shape:=shapeFull;
   font:=bFont;
   items:=Copy(list);
   SetLength(tags,length(items));
   // �������� ������ ����� ���� � ������� "tag|text|hint" ���� "tag|text" ���� "text"
   for i:=0 to high(items) do begin
    j:=pos('|',items[i]);
    if (j>1) and (items[i][1] in ['0'..'9']) then begin
     tags[i]:=StrToIntDef(copy(items[i],1,j-1),0);
     delete(items[i],1,j);
     j:=pos('|',items[i]);
     if j>0 then begin
      if length(items)<>length(hints) then SetLength(hints,length(items));
      hints[i]:=copy(items[i],j+1,length(items[i]));
      SetLength(items[i],j-1);
     end;
    end;
   end;
   curItem:=-1;
   style:=0;
   canHaveFocus:=true;
   maxlines:=15;

   // Default properties for child controls
   frame:=TUIFrame.Create(size.x,2,1,0,self);
   frame.visible:=false;
   frame.parentClip:=false;
   frame.order:=1000;
   popup:=TUIListBox.Create(size.x-2,0,20,'ComboBoxPopUp',font,frame);
   popUp.customPtr:=self;
  // popup.autoSelectMode:=true;
   popup.bgColor:=$FFFFFFFF;
   popup.textColor:=$FF000000;
   popup.bgHoverColor:=$FF405090;
   popup.hoverTextColor:=$FFFFFFFF;
   popup.bgSelColor:=$FF405090;
   popUp.selTextColor:=$FFFFFFFF;

   SetEventHandler('MOUSE\BTNDOWN',ComboEventHandler,emInstant);
  end;

 procedure TUIComboBox.onDropDown;
  var
   r:TRect2s;
   lCount,lHeight,i:integer;
   hint:WideString;
   tag:cardinal;
   root:TUIElement;
  begin
   if not frame.visible then begin
    // Show combo pop
    Signal('UI\COMBOBOX\ONDROP\'+name,TTag(self));
    if comboPop<>nil then comboPop.onDropDown;
    // Attach drop-down list to the root element
    root:=GetRoot;
  {  r:=GetRect;
    r.MoveBy(0,r.y2);}
    r:=TransformTo(GetRect,root);
    frame.position:=Point2s(r.x1, r.y2+1);
    frame.size.x:=size.x;
    frame.AttachTo(root);

    lCount:=length(items);
    if lCount>=maxlines then lCount:=round(maxLines*0.75);
    // size and position
    /// TODO: simplify and rework this
    lHeight:=round(popup.lineHeight);
    popup.size.y:=lHeight*lcount;
    popup.size.x:=frame.size.x-2*frame.borderWidth;
    frame.size.y:=popup.size.y+frame.borderWidth*2;
    if frame.GetPosOnScreen.bottom>=root.height then
     frame.position.y:=r.y1-1;
    // Content
    popUp.ClearLines;
    for i:=0 to high(items) do begin
     if i<=high(hints) then hint:=hints[i]   // !!!
      else hint:='';
     if i<=high(tags) then tag:=tags[i]
      else tag:=i;
     popUp.AddLine(EncodeUTF8(items[i]),tag,hint);
    end;
    frame.visible:=true;
    popup.hoverLine:=curItem;
    timer:=1;
    comboPop:=self;
   end else begin
    // Hide combo pop
    Signal('UI\COMBOBOX\ONHIDE\'+name,TTag(self));
    comboPop:=nil;
    i:=curItem;
    if popup.selectedLine>=0 then curItem:=popup.selectedLine;
    if curItem<>i then begin
     Signal('UI\'+name+'\ONSELECT',i);
     Signal('UI\COMBOBOX\ONSELECT\'+name,TTag(self));
    end;
    frame.visible:=false;
    frame.AttachTo(self);
    timer:=0;
   end;
  end;

 procedure TUIComboBox.onMouseButtons(button:byte;state:boolean);
  begin
   inherited;
   if (button=1) and state then begin
    Signal('UI\ComboBox\DropDown',PtrUInt(self));
    onDropDown;
   end;
  end;

 procedure TUIComboBox.onTimer;
  begin
   // �� �������� inherited, �.�. ��� ��������� ������
   if frame.visible then begin
    timer:=1;
    if (popup.selectedLine>=0) or (FocusedElement<>self) then onDropDown;
   end;
  end;

 procedure TUIComboBox.SetCurItem(item:integer);
  begin
   fCurItem:=item;
   if (item>=0) and (item<=high(items)) then caption:=EncodeUTF8(Items[fCurItem])
    else caption:=EncodeUTF8(defaultText);
   if (item>=0) and (item<=high(tags)) then fCurTag:=tags[item]
    else fCurTag:=-1;
  end;

 procedure TUIComboBox.SetCurItemByTag(tag:integer);
  begin
   SetCurItem(FindInteger(tags,tag));
  end;

 procedure TUIComboBox.SetItem(index:integer;item:WideString;tag:cardinal;
    hint:string);
  begin
   items[index]:=item;
   tags[index]:=tag;
   hints[index]:=hint;
  end;

 procedure TUIFrame.SetBorderWidth(w:integer);
  begin
   borderWidth:=w;
   paddingLeft:=w; paddingRight:=w; paddingBottom:=w; paddingTop:=w;
  end;

 { TScrollBarInterface }

 constructor TScrollBarInterface.Create(owner:TUIScrollbar);
  begin
   inherited Create;
   self.owner:=owner;
  end;

function TScrollBarInterface.GetElement:TUIElement;
  begin
   result:=owner;
  end;

 function TScrollBarInterface.GetPageSize:single;
  begin
   result:=owner.pagesize;
  end;

 function TScrollBarInterface.GetStep:single;
  begin
   result:=owner.step;
  end;

 function TScrollBarInterface.GetValue:single;
  begin
   result:=owner.value;
  end;

 procedure TScrollBarInterface.MoveRel(delta:single;smooth:boolean);
  begin
   owner.MoveRel(delta,smooth);
  end;

 procedure TScrollBarInterface.SetPageSize(pageSize:single);
  begin
   owner.pagesize:=pageSize;
  end;

 procedure TScrollBarInterface.SetRange(min,max:single);
  begin
   owner.SetRange(min,max,owner.pageSize);
  end;

 procedure TScrollBarInterface.SetStep(step:single);
  begin
   owner.step:=step;
  end;

 procedure TScrollBarInterface.SetValue(v:single);
  begin
   owner.value:=v;
  end;

initialization
 TUIButton.SetClassAttribute('handleMouseIfDisabled',true);
 TUIComboBox.SetClassAttribute('handleMouseIfDisabled',false);

end.