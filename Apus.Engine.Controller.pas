// Interface for game controllers: joystick, gamepad etc
//
// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.Controller;
interface
uses Apus.MyServis;

type
 TGameControllerType=(gcUnplugged,
                      gcUnknown,
                      gcJoystick,
                      gcGamepad,
                      gcWheel);

 TConAxisType=(atAxis0,
            atAxis1,
            atAxis2,
            atAxis3,
            atAxis4,
            atAxis5,
            atAxis6,
            atAxis7,
            atLeftX,
            atLeftY,
            atRightX,
            atRightY);

 TConButtonType=(btButton0,
              btButton1,
              btButton2,
              btButton3,
              btButton4,
              btButton5,
              btButton6,
              btButton7,
              btButton8,
              btButton9,
              btButton10,
              btButton11,
              btButton12,
              btButton13,
              btButton14,
              btButton15,
              btButtonA,
              btButtonB,
              btButtonX,
              btButtonY,
              btButtonBack,
              btButtonGuide,
              btButtonStart,
              btButtonDPadUp,
              btButtonDPadDown,
              btButtonDPadLeft,
              btButtonDPadRight,
              btButtonLeftShoulder,
              btButtonRightShoulder);

 TGameController=record
  index:integer;
  controllerType:TGameControllerType;
  name:String8;
  numAxes,numButtons:integer;
  buttons:cardinal;
  axes:array[TConAxisType] of single; // -1..1 range
  function GetButton(btn:TConButtonType):boolean;
 end;
 PGameController=^TGameController;

var
 controllers:array[0..3] of TGameController;

 function GetButtonName(btn:TConButtonType):String8;

implementation
 uses SysUtils;
{ TGameController }

function TGameController.GetButton(btn:TConButtonType): boolean;
 begin
  result:=GetBit(buttons,ord(btn));
 end;

function GetButtonName(btn: TConButtonType): String8;
const
 conButtonNames:array[btButtonA..btButtonRightShoulder] of String8=(
  'A','B','X','Y','Back','Guide','Start',
  'DPad Up','DPad Down','DPad Left','DPad Right',
  'Left Shoulder','Right Shoulder');
 begin
  if btn in [low(conButtonNames)..high(conButtonNames)] then
   result:=conButtonNames[btn]
  else
   result:=IntToStr(ord(btn));
 end;

var
 i:integer;
initialization
 for i:=0 to high(controllers) do
  controllers[i].index:=i;
end.
