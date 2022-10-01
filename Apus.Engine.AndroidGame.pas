// Game object for Android platform (OpenGL ES)
//
// Copyright (C) 2017 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.AndroidGame;
interface
 uses JNI, Classes,
   Apus.Engine.EngineAPI,Apus.Images,Apus.Engine.EngineTools,
   Apus.AnimatedValues,Apus.Common,Apus.Engine.BasicGame,Apus.Engine.UIClasses;

type

 { TAndroidGame }

 TAndroidGame=class(TBasicGame)
  constructor Create;
 protected
  procedure ApplySettings; override;

  // Эти методы используются при смене режима работы (вызов только из главного потока)
  procedure InitGraph; override; // Инициализация графической части (переключить режим и все такое прочее)
  procedure DoneGraph; override; // Финализация графической части

  procedure PresentFrame; override;
  procedure CalcPixelFormats(needMem:integer); override;
  procedure InitObjects; override;
  procedure SetupRenderArea; override;

  procedure ScreenToGame(var p:TPoint); override;
  procedure GameToScreen(var p:TPoint); override;

 public
  // virtual keyboard
  keyboardStatus:boolean;
  lastEdit:TUIEditBox;
  lastSelStart,lastSelCount,lastCursorPos:integer;
  screenOffsetY:TAnimatedValue; // offset render area to fit virtual keyboard
  function GetStatus(n:integer):string; override;
 end;


implementation
 uses Apus.Android, SysUtils, Apus.Engine.CmdProc, Apus.EventMan, Apus.Engine.CommonUI, Apus.GfxFormats,
     Apus.Engine.Console, GLES20, Apus.Engine.GLImages, Apus.Engine.PainterGL2;

{ TAndroidGame }

procedure TAndroidGame.ApplySettings;
var
 i:integer;
begin
 if running then begin // смена параметров во время работы
  //if texman<>nil then (texman as TDXTextureMan).releaseAll;
  Signal('Debug\Settings Changing');
 end;
 if running then begin
  InitGraph;
  //if texman<>nil then (texman as TDXTextureMan).ReCreateAll;
  if painter<>nil then (painter as TGLPainter2).Reset;
  for i:=1 to length(scenes) do
   if scenes[i]<>nil then scenes[i].ModeChanged;
 end;
end;

// Эта процедура пытается установить запрошенный видеорежим
// В случае ошибки она просто бросит исключение
procedure TAndroidGame.InitGraph;
begin
 ForceLogMessage('Loading GLES 2.0');
 InitGLES;
 ForceLogMessage('GLES Loaded');

 displayWidth:=params.width;
 displayHeight:=params.height;
 windowWidth:=displayWidth;
 windowHeight:=displayHeight;
 ForceLogMessage(Format('Device screen size: %d %d',[displayWidth,displayHeight]));

 ForceLogMessage('OpenGL version: '+PChar(glGetString(GL_VERSION)));
 ForceLogMessage('OpenGL vendor: '+PChar(glGetString(GL_VENDOR)));
 ForceLogMessage('OpenGL renderer: '+PChar(glGetString(GL_RENDERER)));
 ForceLogMessage('OpenGL extensions: '+#13#10+StringReplace(PChar(glGetString(GL_EXTENSIONS)),' ',#13#10,[rfReplaceAll]));

 AfterInitGraph;
end;

procedure TAndroidGame.InitObjects;
begin
  texman:=TGLTextureMan.Create(1024*BestVidMem);
  painter:=TGLPainter2.Create(texman);
end;

procedure TAndroidGame.SetupRenderArea;
begin
  inherited;
  TGLPainter2(painter).SetDefaultRenderArea(0,0,displayWidth,displayHeight,
      displayWidth,displayHeight);
end;

procedure TAndroidGame.ScreenToGame(var p:TPoint);
 begin
  inc(p.y,screenOffsetY.IntValue);
 end;

procedure TAndroidGame.GameToScreen(var p:TPoint);
 begin
  dec(p.y,screenOffsetY.IntValue);
 end;

procedure TAndroidGame.PresentFrame;
var
 keyboardNeeded:boolean;
 y:integer;
 change:boolean;
begin
// // No need to present frame on Android
 inc(FrameNum);

 // Virtual keyboard
 keyboardNeeded:=(FocusedControl<>nil) and (focusedControl is TUIEditBox);
 if keyboardNeeded<>keyboardStatus then begin
  if keyboardNeeded then begin
   ShowVirtualKeyboard(ktDefault);
   y:=FocusedControl.GetPosOnScreen.Bottom;
   if y>round(displayHeight*0.44) then
     screenOffsetY.Animate(y-round(displayHeight*0.4),250,Spline1,100);
  end else begin
   HideVirtualKeyboard;
   screenOffsetY.Animate(0,250,Spline1,50);
  end;
  keyboardStatus:=keyboardNeeded;
 end;
 // Monitor editor changed
 if keyboardNeeded then begin
  change:=false;
  if lastEdit<>focusedControl then begin
   lastEdit:=focusedControl as TUIEditBox;
   change:=true;
  end;
  if lastEdit.cursorpos<>lastCursorPos then begin
   lastCursorPos:=lastEdit.cursorpos;
   change:=true;
  end;
  if lastEdit.selStart<>lastSelStart then begin
   lastSelStart:=lastEdit.selstart;
   change:=true;
  end;
  if lastEdit.selcount<>lastSelCount then begin
   lastSelCount:=lastEdit.selcount;
   change:=true;
  end;
{  if change then
   if lastEdit.selCount>0 then
     UpdateVirtualKeyboard(android.mainView,lastSelStart,lastSelStart+lastSelCount-1)
   else
     UpdateVirtualKeyboard(android.mainView,lastCursorPos,lastCursorPos);}
 end;

 TGLPainter2(painter).SetDefaultRenderArea(0,screenOffsetY.IntValue,
   displayWidth,displayHeight,displayWidth,displayHeight);
end;

procedure TAndroidGame.CalcPixelFormats(needMem:integer);
begin
 pfTrueColor:=ipfARGB;
 pfTrueColorAlpha:=ipfARGB;
 pfTrueColorLow:=ipf565;
 pfTrueColorAlphaLow:=ipfARGB;

 pfRTLow:=ipf565;
 pfRTNorm:=ipfARGB;
 pfRTHigh:=ipfARGB;
 pfRTAlphaLow:=ipfARGB;
 pfRTAlphaNorm:=ipfARGB;
 pfRTAlphaHigh:=ipfARGB;
end;

constructor TAndroidGame.Create;
begin
 ForceLogMessage('Base address (Create$$TAndroidGame): '+PtrToStr(@TAndroidGame.Create));
 inherited Create(30);
 useMainThread:=false;
 screenOffsetY.Init;
end;

procedure TAndroidGame.DoneGraph;
begin
  inherited;
end;

function TAndroidGame.GetStatus(n: integer): string;
begin
 result:='';
end;

end.
