// Standard scene for visual editing of published variables (using MyServis unit)
// Press Ctrl+[~] to show/hide
//
// Copyright (C) 2013-2014 Apus Software (www.apus-software.com)
// Author: Ivan Polyacov (ivan@apus-software.com)
unit TweakScene;
interface
 uses EngineCls;

 procedure CreateTweakerScene(tinyFont,normalFont:cardinal);

implementation
 uses SysUtils,MyServis,publics,Math,UIClasses,CommonUI,EventMan,UIRender,engineTools;

 type
  TTweakerScene=class(TUIScene)
   tinyFont,normalFont:cardinal;
   context:string;
   editbox:TUIEditBox;
   listbox:TUIListbox;
   editors:array[0..15] of TUIControl;
   edCount:integer;
   constructor Create(tinyFont_,normalFont_:cardinal);
   procedure SetStatus(st:TSceneStatus); override;
   procedure onMouseBtn(btn:byte;pressed:boolean); override;
   procedure onMouseWheel(delta:integer); override;
   procedure PlaceTrackers(keepPos:boolean=false);
  end;

  //
  TTracker=class(TUIControl)
   value,min,max,initialValue:single;
   vType:integer;
   constructor Create(x,y:integer;parent:TUIControl;mode:integer;iValue,initValue:single);
   procedure onMouseMove; override;
   procedure onMouseScroll(delta:integer); override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure Draw(x1,y1,x2,y2:integer); virtual;
   function ValueToX(v:single):integer;
   function XToValue(x:integer):single;
  private
   moving:boolean;
  end;

  TValueEditor=class(TUIControl)
   varName:string;
   trackers:array[0..3] of TTracker;
   constructor Create(vName,vValue,iValue:string;parent:TUIControl);
   procedure Draw(x1,y1,x2,y2:integer); virtual;
  end;

 var
  tweakerScene:TTweakerScene;

 function EventHandler(event:eventStr;tag:integer):boolean;
  begin
   result:=false;
   event:=UpperCase(event);
   if event='KBD\KEYDOWN' then begin
    // Ctrl+[~] - показать/скрыть твикер
    if (tag and 255=192) and (tag and $20000>0) then begin
     result:=true;
     if tweakerScene.status<>ssActive then
      tweakerScene.SetStatus(ssActive)
     else
      tweakerScene.SetStatus(ssFrozen);
    end;
   end;
   if event='UI\TWEAKER\LIST\SELECTED' then
    tweakerScene.PlaceTrackers(true);
  end;

 procedure StyleDrawer(control:TUIControl);
  var
   x1,y1,x2,y2,h:integer;
  begin
   with control do begin
    x1:=globalrect.Left;
    y1:=globalrect.Top;
    x2:=globalrect.Right-1;
    y2:=globalrect.Bottom-1;
   end;

   if control.ClassType=TUIControl then begin
    painter.FillRect(x1,y1,x2,y2,$60404040);
    exit;
   end;

   if control.ClassType=TValueEditor then
    TValueEditor(control).Draw(x1,y1,x2,y2);

   if control.ClassType=TTracker then
    TTracker(control).Draw(x1,y1,x2,y2);

   if control.ClassType=TUIButton then
    with control as TUIButton do begin
//    painter.FillGradrect(x1,y1,x2,y2,$);
//     painter.Rect(x1,y1,x2,y2,$50A0A0A0);
     painter.TextOut(tweakerScene.tinyFont,(x1+x2) div 2-1,y2-2,$C0E0D0B0,caption);
    end;
  end;

 procedure CreateTweakerScene(tinyFont,normalFont:cardinal);
  begin
   RegisterUIStyle(3,StyleDrawer);
   tweakerScene:=TTweakerScene.Create(tinyFont,normalFont);
   tweakerScene.tinyFont:=tinyFont;
   tweakerScene.normalFont:=normalFont;
   game.AddScene(tweakerScene);
   SetEventHandler('KBD\KeyDown',EventHandler);
   SetEventHandler('UI\Tweaker',EventHandler);
  end;


{ TTweakerScene }

constructor TTweakerScene.Create(tinyFont_,normalFont_:cardinal);
var
 i,h:integer;
begin
 inherited Create('Tweaker',false);
 ignoreKeyboardEvents:=true;
 zorder:=1000000;
 tinyFont:=tinyFont_;
 normalFont:=normalFont_;
 UI.Resize(320,300);
 UI.styleinfo:='60404040';
 edCount:=0;

 h:=round(11+game.renderHeight*0.01);
 listbox:=TUIListbox.Create(10,10,300,h*3+2,h,'Tweaker\List',normalFont,ui);
 listbox.bgColor:=$60303030;
 listbox.AnchorRight:=true;
end;

procedure TTweakerScene.onMouseBtn(btn: byte; pressed: boolean);
begin

end;

procedure TTweakerScene.onMouseWheel(delta: integer);
begin

end;

procedure TTweakerScene.PlaceTrackers;
var
 i,j:integer;
 sa:StringArr;
 name,value,iValue:string;
begin
 // Delete old trackers
 ui.height:=listBox.height+20;
 for i:=0 to edCount-1 do
  FreeAndNil(editors[i]);

 // Create new trackers
 if (listbox.selectedLine>=0) then begin
  context:=listbox.lines[listbox.selectedLine];
  i:=pos(': ',context);
  if i>0 then delete(context,1,i+1);
  sa:=split(';',context);
  for i:=0 to length(sa)-1 do begin
   j:=pos('=',sa[i]);
   if j=0 then continue;
   name:=chop(copy(sa[i],1,j-1));
   ivalue:=chop(copy(sa[i],j+1,100));
   value:=GetOverriddenValue(name,context);
   if value='' then value:=iValue;
   editors[i]:=TValueEditor.Create(name,value,iValue,ui);
  end;
  edCount:=length(sa);
 end;

 // Adjust vertical position
 if not keepPos then ui.y:=game.mouseY-ui.height div 2;
 if ui.y+ui.height>game.renderHeight then ui.y:=game.renderHeight-ui.height;
 if ui.y<5 then ui.y:=5;
end;

procedure TTweakerScene.SetStatus(st: TSceneStatus);
var
 sa:StringArr;
 lastIdx:integer;
begin
 if st=ssActive then begin
  // Update UI Layout
  ui.Resize(round(200+game.renderWidth*0.1),-1);
  ui.x:=game.mouseX-ui.width div 2;
  if ui.x<5 then ui.x:=5;
  if ui.x+ui.width>game.renderWidth-5 then ui.x:=game.renderWidth-5-ui.width;
  ui.height:=listBox.height+20;

  sa:=GetGlobalContexts(lastIdx);
  listBox.SetLines(sa);
  listBox.selectedLine:=lastIdx;
  if (length(sa)>0) and (listbox.selectedLine<0) then listbox.selectedLine:=0;

  PlaceTrackers;
 end else begin
  clipMouse:=cmNo;
  hooked:=nil;
 end;
 inherited;
end;

{ TFloatTracker }

constructor TTracker.Create(x,y:integer;parent: TUIControl; mode:integer;iValue,initValue:single);
begin
 inherited Create(x,y,parent.width-x-5-5*byte(mode in [3..6]),18+game.renderHeight div 50,parent);
 style:=3;
 value:=iValue;
 initialValue:=initValue;
 moving:=false;
 vType:=mode;
 if mode<3 then begin
  min:=-1.1; max:=1.1;
  while value>(min*0.1+max*0.9) do max:=max+abs(max-min);
  while value<(min*0.9+max*0.1) do min:=min-abs(max-min);
 end else begin
  min:=0; max:=255;
 end;
end;

procedure TTracker.Draw(x1, y1, x2, y2: integer);
var
 i,j:integer;
 xx,yy:integer;
 step:single;
 fl:boolean;
 c:cardinal;
begin
 //painter.Rect(x1,y1,x2,y2,$80C0C0C0);
 yy:=y1+round(height*0.48);
 painter.DrawLine(x1,yy-1,x2,yy-1,$80202020);
 painter.DrawLine(x1,yy+1,x2,yy+1,$80A0A0A0);
 step:=0.0001; j:=0;
 while (max-min)/step>40 do begin
  if j mod 3=0 then step:=step*2;    // ->0.2
  if j mod 3=1 then step:=step*2.5;  // ->0.5
  if j mod 3=2 then step:=step*2;    // ->1.0
  inc(j);
 end;
 if vType in [3..6] then begin
  step:=16; j:=4;
 end else
  j:=5;
 for i:=round(min/step) to round(max/step) do begin
  xx:=ValueToX(i*step);
  if (xx>=0) and (xx<width) then begin
   if i mod j=0 then begin
    painter.TextOut(tweakerScene.tinyFont,x1+round(xx*0.98+width*0.01),(yy+y2) div 2+4,$C0E0E0E0,
      FloatToStrF(i*step,ffGeneral,5,0),taCenter);
    painter.DrawLine(x1+xx,yy-4,x1+xx,yy+4,$90C0C0C0);
   end else
    painter.DrawLine(x1+xx,yy-2,x1+xx,yy+3,$90A0A0A0);
  end;
 end;
 // Draw initial value
 if value<>initialValue then begin
  xx:=ValueToX(initialValue);
  if (xx>=0) and (xx<width) then begin
   inc(xx,x1);
   painter.DrawLine(xx,yy,xx-4,yy-4,$D0C0B0A0);
   painter.DrawLine(xx,yy,xx+4,yy-4,$D0C0B0A0);
   painter.DrawLine(xx-4,yy-4,xx-4,yy-10,$D0C0B0A0);
   painter.DrawLine(xx+4,yy-4,xx+4,yy-10,$D0C0B0A0);
  end;
 end;
 // Draw slider
 if vType>1 then xx:=ValueToX(round(value))
  else xx:=ValueToX(value);
 if (xx>=0) and (xx<width) then begin
  j:=4+game.renderHeight div 80;
  c:=$FFD8D0C0;
  if vType=4 then c:=$FFE0A0A0;
  if vType=5 then c:=$FFA0D0A0;
  if vType=6 then c:=$FFA0A0F0;
  inc(xx,x1);
  for i:=-4 to 4 do
   painter.DrawLine(xx+i,yy-j,xx+i,yy-abs(i),c-$101010*abs(i));
 end;
end;

procedure TTracker.onMouseButtons(button: byte; state: boolean);
begin
  inherited;
  if state then begin
   moving:=true;
   hooked:=self;
   clipMouse:=cmVirtual;
   clipMouseRect:=globalrect;
   onMouseMove;
  end else begin
   moving:=false;
   hooked:=nil;
   clipMouse:=cmNo;
   if vType<3 then begin
    if value>min*0.05+max*0.95 then max:=max+(max-min)*0.5;
    if value<min*0.95+max*0.05 then min:=min-(max-min)*0.5;
   end;
  end;
end;

procedure TTracker.onMouseMove;
var
 xx:integer;
begin
  inherited;
  if moving then begin
   xx:=curMouseX-globalRect.Left;
   value:=XToValue(xx);
   if value<min then value:=min;
   if value>max then value:=max;
   if vType>1 then value:=round(value);
   if (max-min)>2000 then value:=RoundTo(value,1);
   if (max-min)>200 then value:=RoundTo(value,0);
   if (max-min)>20 then value:=RoundTo(value,-1);
   if (max-min)>2 then value:=RoundTo(value,-2);
   if (max-min)>0.2 then value:=RoundTo(value,-3);
   if (max-min)>0.02 then value:=RoundTo(value,-4);
  end;
end;

procedure TTracker.onMouseScroll(delta: integer);
begin
 inherited;
 if vType>=3 then exit;
 if delta<0 then begin
  min:=min-0.4*abs(max-value);
  max:=max+0.4*abs(value-min);
 end;
 if delta>0 then begin
  if (vType=1) or (max-min>100) then begin
   min:=min*0.5+value*0.5;
   max:=max*0.5+value*0.5;
  end;
 end;
end;

function TTracker.ValueToX(v: single): integer;
begin
 result:=2+round((v-min)/(max-min)*(width-5));
end;

function TTracker.XToValue(x: integer): single;
begin
 result:=min+(max-min)*((x-2)/(width-5));
end;

{ TFloatEditor }

constructor TValueEditor.Create(vName,vValue,iValue:string;parent:TUIControl);
var
 c,ic:cardinal;
 i:integer;
 btn:TUIButton;
begin
 inherited Create(10,parent.height-5,parent.width-20,24+game.renderHeight div 40,parent,'Editor_'+vName);
 varName:=vName;
 style:=3;
 varName[1]:='g';
 varName[2]:=UpCase(varName[2]);
 if varName[2]='F' then begin // Float value
  trackers[0]:=TTracker.Create(5,round(height*0.2),self,1,ParseFloat(vValue),ParseFloat(iValue));
 end;
 if varName[2]='I' then begin // Integer value
  trackers[0]:=TTracker.Create(5,round(height*0.2),self,2,StrToInt(vValue),StrToInt(iValue));
 end;
 if varName[2]='C' then begin // Color value
  c:=StrToInt(vValue);
  ic:=StrToInt(iValue);
  i:=0;
  trackers[0]:=TTracker.Create(68,i,self,3,c shr 24,ic shr 24); inc(i,trackers[0].height-1);
  trackers[1]:=TTracker.Create(68,i,self,4,c shr 16 and $FF,ic shr 16 and $FF); inc(i,trackers[0].height-1);
  trackers[2]:=TTracker.Create(68,i,self,5,c shr 8 and $FF,ic shr 8 and $FF); inc(i,trackers[0].height-1);
  trackers[3]:=TTracker.Create(68,i,self,6,c and $FF,ic and $FF); inc(i,trackers[0].height-1);
  height:=i+1;
 end;
 parent.height:=y+height+10;
{ btn:=TUIButton.Create(width-12,0,12,12,'TweakScene\Reset_'+vName,'o',tweakerScene.tinyFont,self);
 btn.style:=3;
 btn.hint:='Revert to initial value';}
end;

procedure TValueEditor.Draw(x1, y1, x2, y2: integer);
 var
  h,yy:integer;
  c:cardinal;
  vI:integer;
  vF:single;
 begin
  painter.FillRect(x1,y1,x2,y2,$90202020);
  h:=y2-y1;
  if varname[2] in ['F','I'] then begin
   painter.TextOut(tweakerScene.normalFont,x1+2,y1+round(h*0.26),
     $FFF0E0C0,varname+'='+FloatToStrF(trackers[0].value,ffGeneral,4,0));
   if varname[2]='F' then begin
    vF:=trackers[0].value;
    OverrideGlobal(varName,vF,tweakerScene.context);
   end;
   if varname[2]='I' then begin
    vI:=round(trackers[0].value);
    OverrideGlobal(varName,vI,tweakerScene.context);
   end;
  end;
  if varname[2]='C' then begin
   c:=round(trackers[0].value) shl 24+
      round(trackers[1].value) shl 16+
      round(trackers[2].value) shl 8+
      round(trackers[3].value);
   painter.TextOut(tweakerScene.normalFont,x1+2,y1+round(h*0.09),$FFF0E0C0,varname+'=');
   painter.TextOut(tweakerScene.normalFont,x1+2,y1+round(h*0.20),$FFF0E0C0,IntToHex(c,8));
   yy:=y1+round(h*0.25);
//   painter.FillRect(x1+5,yy,x1+60,y2-5,$FF
   painter.FillGradrect(x1+5,yy,x1+60,y2-5,c,c or $FF000000,true);
   painter.Rect(x1+4,yy-1,x1+61,y2-4,$90F0E0C0);
   OverrideGlobal(varName,C,tweakerScene.context);
  end;
 end;

end.
