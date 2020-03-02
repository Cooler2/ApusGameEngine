// Android MediaPlayer JNI interface
// Copyright (C) 2017 Apus Software (www.apus-software.com)
// Author: Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit AndroidMediaPlayer;
{$mode delphi}
interface

uses
  jni;

type

 { TJNIMediaPlayer }
 TJNIMediaPlayer=class
  constructor Create;
  destructor Destroy; override;
  procedure SetDataSource(fName:string;loop:boolean=true);
  procedure Start;
  procedure Stop;
  procedure SetVolume(rVolume,lVolume:single);
  procedure Pause;
  procedure Resume;
 private
  mpl:jobject;
 end;

implementation
 uses MyServis,SysUtils,Android;

 { TJNIMediaPlayer }

constructor TJNIMediaPlayer.Create;
 var
  cls:jclass;
 begin
   if appEnv=nil then AndroidInitThread;
   // Create MediaPlayer object
   cls:=appEnv^.FindClass(appEnv,'android/media/MediaPlayer');
   mpl:=appEnv^.NewObject(appEnv,cls,
     GetMethodID('android/media/MediaPlayer','<init>','()V'));
   if mpl=nil then ForceLogMessage('MediaPlayer creation failed!');
   NewGlobalRef(mpl);
 end;

destructor TJNIMediaPlayer.Destroy;
 begin
  FreeGlobalRef(mpl);
  inherited;
 end;

procedure TJNIMediaPlayer.SetDataSource(fName: string; loop: boolean);
 begin
  CallMethod(mpl,'android/media/MediaPlayer','setDataSource','(Ljava/lang/String;)V',[fName]);
  if loop then
    CallMethod(mpl,'android/media/MediaPlayer','setLooping','(Z)V',[true]);
  CallMethod(mpl,'android/media/MediaPlayer','prepare','()V',[]);
 end;

procedure TJNIMediaPlayer.Start;
 begin
  CallMethod(mpl,'android/media/MediaPlayer','start','()V',[]);
 end;

procedure TJNIMediaPlayer.Stop;
 begin
  CallMethod(mpl,'android/media/MediaPlayer','stop','()V',[]);
 end;

procedure TJNIMediaPlayer.SetVolume(rVolume,lVolume:single);
 begin
  CallMethod(mpl,'android/media/MediaPlayer','setVolume','(FF)V',[rVolume,lVolume]);
 end;

procedure TJNIMediaPlayer.Pause;
 begin
  CallMethod(mpl,'android/media/MediaPlayer','pause','()V',[]);
 end;

procedure TJNIMediaPlayer.Resume;
 begin
  Start;
 end;

end.

