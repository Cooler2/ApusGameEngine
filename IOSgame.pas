// Game class for iOS (OpenGL)
//
// Copyright (C) 2012 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit IOSgame;
interface
 uses EngineAPI,Images,engineTools,classes,myservis,BasicGame;

type
 TIOSGame=class(TBasicGame)
  constructor Create;
 protected
  procedure ApplySettings; override;

  // Эти методы используются при смене режима работы (вызов только из главного потока)
  procedure InitGraph; override; // Инициализация графической части (переключить режим и все такое прочее)
  procedure DoneGraph; override; // Финализация графической части

  procedure PresentFrame; override;
  procedure ChoosePixelFormats(needMem:integer); override;
  procedure InitObjects; override;
 public
  function GetStatus(n:integer):string; override;
 end;

implementation
 uses SysUtils,{$IFDEF IOS}gles11,{$ENDIF}cmdproc{$IFDEF DELPHI},graphics{$ENDIF},
     GLImages,EventMan,UIClasses,UIScene,gfxformats,
     Console,PainterGL;

{ TGlGame }

procedure TIOSGame.ApplySettings;
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
  if painter<>nil then (painter as TGLPainter).Reset;
  for i:=low(scenes) to high(scenes) do
   if scenes[i]<>nil then scenes[i].ModeChanged;
 end;
end;

// Эта процедура пытается установить запрошенный видеорежим
// В случае ошибки она просто бросит исключение
procedure TIOSGame.InitGraph;
begin
{ Signal('Engine\BeforeInitGraph');
 // Установить размеры окна и включить его
 ScreenRect:=rect(0,0,params.width,params.height);
 SetWindowArea(params.width,params.height,screenRect);}
 AfterInitGraph;
end;

procedure TIOSGame.InitObjects;
begin
  texman:=TGLTextureMan.Create(1024*BestVidMem);
  painter:=TGLPainter.Create(texman);
end;

procedure TIOSGame.PresentFrame;
begin
   FLog('Present');
   Signal('Engine\PresentFrame');
   inc(FrameNum);
//   (painter as TGLPainter).outputPos:=Point(0,0);
end;

procedure TIOSGame.ChoosePixelFormats(needMem:integer);
begin
 pfTrueColor:=ipf565;
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

constructor TIOSGame.Create;
begin
 inherited Create(20);
 useMainThread:=false;
end;

procedure TIOSGame.DoneGraph;
begin
  inherited;
end;

function TIOSGame.GetStatus(n: integer): string;
begin
 result:='';
end;

end.
