// Base Scene and SceneEffect classes
//
// Copyright (C) 2022 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.Scene;
interface
uses Types, Apus.Structs;

type
 TGameScene=class;

 // ������� ������ ��� background-�����
 TSceneEffect=class
  timer:integer; // ����� (� �������� �������), ��������� � ������� ������ �������
  duration:integer;  // �����, �� ������� ������ ������ ����������
  done:boolean;  // ����, ��������������� � ���, ��� ������ ��������
  target:TGameScene;
  name:string; // description for debug reasons
  constructor Create(scene:TGameScene;TotalTime:integer); // ������� ������ �� �������� ����� (� ��.)
  procedure DrawScene; virtual; abstract; // ��������� ������ ��������� ��������� ��������� ����� � �������� (� ������� RT)
  destructor Destroy; override;
 end;

 // -------------------------------------------------------------------
 // TGameScene - ������������ �����
 // -------------------------------------------------------------------
 TSceneStatus=(ssFrozen,     // ����� ��������� "����������"
               ssBackground, // ����� ��������������, �� �� ��������
                             // (����� ���-�� � ������� ������ � �� ������ �� �����)
               ssActive);    // ����� �������, �.�. �������������� � ��������

 TGameScene=class
  status:TSceneStatus;
  name:string;
  fullscreen:boolean; // true - opaque scene, no any underlying scenes can be seen, false - scene layer is drawn above underlying image
  frequency:integer; // ������� ��� � ������� ����� �������� ���������� ����� (0 - ������ ����)
  effect:TSceneEffect; // ������, ����������� ��� ������ �����
  zOrder:integer; // ���������� ������� ��������� ����
  activated:boolean; // true ���� ����� ��� ������ ������������ ��� ����������, �� ��� �� ����� ������� ��������
  shadowColor:cardinal; // ���� �� 0, �� �������� ����� ���������� �����
  ignoreKeyboardEvents:boolean; // ���� true - ����� ����� �� ����� �������� ������� � ������������ �����, ���� ������ �������
  initialized:boolean;

  // ���������� ��������
  accumTime:integer; // ����������� ����� (� ��)

  constructor Create(fullscreen:boolean=true);
  destructor Destroy; override;

  // ���������� �� ������������, ����� �������������� ��� ������������� ��� �������� � �����������
  // !!! Call this manually from constructor!
  procedure onCreate; virtual;

  // ��� ��������� ������� ������������ ������ ���!
  procedure SetStatus(st:TSceneStatus); virtual;

  // status=ssActive
  function IsActive:boolean;

  // Called only once from the main thread before first Render() call
  procedure Initialize; virtual;

  // ��������� �����, ���������� � �������� �������� ���� ������ ����� �� ����������
  // ���� ����� ����� ��������� ������ �����, ��������/��������� �������� � �.�.
  function Process:boolean; virtual;

  // ��������� �����. ���������� ������ ���� ������ ���� ����� ������� � ����������
  // �� ������ ������ ���������� RenderTarget � ��� ������ � ���������
  // ���� ����� ������� ���� ���� UI, �� ���� ����� ������ �������
  // ��������� UI ��� ��� �����������
  procedure Render; virtual;

  // ���������� ���� �� ������� ������ � ������
  function KeyPressed:boolean; virtual;
  // Read buffered key event: 0xAAAABBCC or 0 if no any keys were pressed
  // AAAA - unicode char, BB - scancode, CC - ansi char
  function ReadKey:cardinal; virtual;
  // �������� ������� � �����
  procedure WriteKey(key:cardinal); virtual;
  // �������� ����� �������
  procedure ClearKeyBuf; virtual;

  // ����� ������ (��� ������ ���������� - ����� ������ ��������)
  procedure ModeChanged; virtual;

  // ��������� � ���, ��� ������� ��������� (��� ����� ���� ������ ����) �������� ������, ����� ����� ������������� �� ���
  procedure onResize; virtual;
  // ������� ����
  procedure onMouseMove(x,y:integer); virtual;
  procedure onMouseBtn(btn:byte;pressed:boolean); virtual;
  procedure onMouseWheel(delta:integer); virtual;

  // For non-fullscreen scenes return occupied area
  function GetArea:TRect; virtual; abstract;
 private
  // Keyboard input
  keyBuffer:TQueue;
 end;


implementation
 uses Apus.MyServis, SysUtils;

 { TGameScene }

 procedure TGameScene.ClearKeyBuf;
  begin
   keyBuffer.Clear;
  end;

 constructor TGameScene.Create(fullScreen:boolean=true);
  begin
   status:=ssFrozen;
   self.fullscreen:=fullscreen;
   frequency:=60;
   keyBuffer.Init(64);
   zorder:=0;
   activated:=false;
   effect:=nil;
   name:=ClassName;
   ignoreKeyboardEvents:=false;
   if classType=TGameScene then onCreate; // each generic child class must call this in the constructors last string
  end;

 destructor TGameScene.Destroy;
  begin
   if status<>ssFrozen then raise EError.Create('Scene must be frozen before deletion: '+name+' ('+ClassName+')');
  end;

 procedure TGameScene.Initialize;
  begin
  end;

 function TGameScene.IsActive: boolean;
  begin
   result:=status=ssActive;
  end;

procedure TGameScene.ModeChanged;
  begin
  end;

 procedure TGameScene.onMouseBtn(btn: byte; pressed: boolean);
  begin
  end;

 procedure TGameScene.onMouseMove(x, y: integer);
  begin
  end;

 procedure TGameScene.onMouseWheel(delta:integer);
  begin
  end;

 procedure TGameScene.onResize;
  begin
  end;

 function TGameScene.Process:boolean;
  begin
   result:=true;
  end;

 procedure TGameScene.onCreate;
  begin
  end;

 function TGameScene.KeyPressed:boolean;
  begin
   result:=not keyBuffer.Empty;
  end;


 function TGameScene.ReadKey:cardinal;
  var
   item:TDataItem;
  begin
   if keyBuffer.Get(item) then
    result:=cardinal(item.data)
   else
    result:=0;
  end;

 procedure TGameScene.WriteKey(key:cardinal);
  var
   item:TDataItem;
  begin
   item.data:=integer(key);
   keyBuffer.Add(item);
  end;

 procedure TGameScene.Render;
  begin
  end;

 procedure TGameScene.SetStatus(st: TSceneStatus);
  begin
   status:=st;
   if status=ssActive then activated:=true
    else activated:=false;
  end;

 { TSceneEffect }

 constructor TSceneEffect.Create(scene:TGameScene;TotalTime:integer);
  begin
   done:=false;
   duration:=TotalTime;
   if duration=0 then duration:=10;
   timer:=0;
   if scene.effect<>nil then begin
    ForceLogMessage('New scene effect replaces old one! '+scene.name+' previous='+scene.effect.name);
    scene.effect.Free;
   end;
   scene.effect:=self;
   target:=scene;
   name:=self.ClassName+' for '+scene.name+' created '+FormatDateTime('nn:ss.zzz',Now);
   LogMessage('Effect %s: %s',[PtrToStr(self),name]);
  end;

 destructor TSceneEffect.Destroy;
  begin
    LogMessage('Scene effect %s deleted: %s',[PtrToStr(self),name]);
    inherited;
  end;

end.
