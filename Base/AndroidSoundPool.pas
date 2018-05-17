// Android SoundPool JNI interface
// Copyright (C) 2017 Apus Software (www.apus-software.com)
// Author: Ivan Polyacov (ivan@apus-software.com, cooler@tut.by)
unit AndroidSoundPool;
{$mode delphi}
interface
  uses jni;

 type
  TSoundID = jint;
  TStreamID = jint;

  TSoundPool=class
   soundPool:jobject;
   count:integer;
   constructor Create;
   destructor Destroy; override;
   // Load a file from bundle resources
   function LoadSoundFile(fName:string):TSoundID;
   // Play loaded sound
   function PlaySound(soundID:TSoundID;lVolume,rVolume,speed:single;loop:boolean):TStreamID;
   // Change stream volume
   procedure SetStreamVolume(streamID:TStreamID;lVolume,rVolume:single);
   // Change stream speed (rate)
   procedure SetStreamSpeed(streamID:TStreamID;speed:single);
   // Stop stream playback
   procedure StopSound(streamID:TStreamID);
   // Release sound
   procedure UnloadSound(soundID:TSoundID);
  end;

{ var

 // Must be called BEFORE any functions below
 procedure InitSoundPool;
 // Load a file from bundle resources
 function LoadSoundFile(fName:string):TSoundID;
 // Play loaded sound
 function PlaySound(soundID:TSoundID;lVolume,rVolume,speed:single;loop:boolean):TStreamID;
 // Change stream volume
 procedure SetStreamVolume(streamID:TStreamID;lVolume,rVolume:single);
 // Change stream speed (rate)
 procedure SetStreamSpeed(streamID:TStreamID;speed:single);
 // Stop stream playback
 procedure StopSound(streamID:TStreamID);
 // Release sound
 procedure UnloadSound(soundID:TSoundID);}

implementation
 uses MyServis,SysUtils,Android;

 constructor TSoundPool.Create;
  var
   cls:jclass;
   args:array[0..3] of jvalue;
  begin
   if appEnv=nil then AndroidInitThread;
   // Create sound pool object
   // android.media.SoundPool soundPool = SoundPool(4,3,0);
   cls:=appEnv^.FindClass(appEnv,'android/media/SoundPool');
   args[0].i:=4;
   args[1].i:=3;
   args[2].i:=0;
   soundPool:=appEnv^.NewObjectA(appEnv,cls,
     GetMethodID('android/media/SoundPool','<init>','(III)V'),@args);
   if soundPool=nil then ForceLogMessage('SoundPool creation failed!');
   NewGlobalRef(soundPool);
   DebugMessage('SoundPool created: '+PtrToStr(soundPool));
  end;

 destructor TSoundPool.Destroy;
  begin
   FreeGlobalRef(soundPool);
  end;

 function TSoundPool.LoadSoundFile(fName:string):TSoundID;
  var
   id:jint;
   afd:jobject;
  begin
   result:=0;
   if soundPool=nil then exit;

   // afd = appAssetManager.openFd(fName)
   afd:=CallMethod(appAssetManager,'android/content/res/AssetManager',
    'openFd','(Ljava/lang/String;)Landroid/content/res/AssetFileDescriptor;',
    [fName]).l;

   if afd=nil then begin
    LogMessage('Asset not found: '+fName);
    exit;
   end;

   // int id = soundPool.Load(afd, 1)
   id:=CallMethod(soundPool,'android/media/SoundPool',
    'load','(Landroid/content/res/AssetFileDescriptor;I)I',[afd,1]).i;

   result:=id;
   if id>0 then inc(count);
  end;

 function TSoundPool.PlaySound(soundID:TSoundID;lVolume,rVolume,speed:single;loop:boolean):TStreamID;
  var
   args:array[0..5] of jvalue;
  begin
   ASSERT(soundPool<>nil);
   ASSERT(soundID<>0);
   args[0].i:=soundID;
   args[1].f:=lVolume;
   args[2].f:=rVolume;
   args[3].i:=1;
   args[4].i:=-byte(loop);
   args[5].f:=speed;
   result:=appEnv^.CallIntMethodA(appEnv,soundPool,
     GetMethodID('android/media/SoundPool','play',
      '(IFFIIF)I'),@args);
  end;

 procedure TSoundPool.SetStreamVolume(streamID:TStreamID;lVolume,rVolume:single);
  var
   args:array[0..3] of jvalue;
  begin
   ASSERT(soundPool<>nil);
   ASSERT(streamID<>0);
   args[0].i:=streamID;
   args[1].f:=lVolume;
   args[2].f:=rVolume;
   appEnv^.CallVoidMethodA(appEnv,soundPool,
     GetMethodID('android/media/SoundPool','setVolume',
      '(IFF)V'),@args);
  end;

 procedure TSoundPool.SetStreamSpeed(streamID:TStreamID;speed:single);
  var
   args:array[0..3] of jvalue;
  begin
   ASSERT(soundPool<>nil);
   ASSERT(streamID<>0);
   args[0].i:=streamID;
   args[1].f:=speed;
   appEnv^.CallVoidMethodA(appEnv,soundPool,
     GetMethodID('android/media/SoundPool','setRate',
      '(IF)V'),@args);
  end;

 procedure TSoundPool.StopSound(streamID:TStreamID);
  var
   args:array[0..0] of jvalue;
  begin
   ASSERT(soundPool<>nil);
   ASSERT(streamID<>0);
   args[0].i:=streamID;
   appEnv^.CallVoidMethodA(appEnv,soundPool,
     GetMethodID('android/media/SoundPool','stop',
      '(I)V'),@args);
  end;

 procedure TSoundPool.UnloadSound(soundID:TSoundID);
  var
   args:array[0..0] of jvalue;
  begin
   ASSERT(soundPool<>nil);
   ASSERT(soundID<>0);
   args[0].i:=soundID;
   appEnv^.CallBooleanMethodA(appEnv,soundPool,
     GetMethodID('android/media/SoundPool','unload',
      '(I)V'),@args);
   if count>0 then dec(count);
  end;

end.

