{$APPTYPE CONSOLE}

program soundDemo;

uses
  Apus.MyServis,
  SysUtils,
  Apus.EventMan,
  Apus.Engine.API,
  Apus.Engine.Sound;

const
 defaultCmd:array[1..10] of string=(
  'PlayMusic\testOGG',
  'PlayMusic\testMP3',
  'PlayMusic\testMOD::3',
  'PlayMusic\None',
  'Play\Sample',
  'Play\Stereo',
  'Play\Low',
  'Play\Wav',
  'Play\sampleLeft',
  'Play\sampleQuiet');


var
 cmd:string;
 v:integer;
 tag:int64;
begin
 try
  UseLogFile('test.log',true);
  soundFolderPath:='..\demo\SoundDemo\Res\';
  soundConfigFile:='..\demo\SoundDemo\Res\sounds.ctl';
  writeln('Select backend library: ');
  writeln(' 1 - !Mixer (ImxEx.dll)');
  writeln(' 2 - BASS (bass.dll)');
  writeln(' 3 - SDL Mixer (sdl_mixer.dll)');
  readln(cmd);
  case ParseInt(cmd) of
   1:InitSoundSystem(slIMixer);
   2:InitSoundSystem(slBass);
   3:InitSoundSystem(slSDL);
  end;

  writeln('Enter command (like "Play\sample") or '#13#10'1..',high(defaultCmd),' for predefined commands or "q" to exit.');

  repeat
   write('Sound\:');
   readln(cmd);
   if length(cmd)<3 then begin
    v:=ParseInt(cmd);
    if (v>0) and (v<=high(defaultCmd)) then begin
     cmd:=defaultCmd[v];
     writeln('SOUND\'+cmd);
    end;
   end;
   if SameText(cmd,'q') then break;
   Signal('SOUND\'+cmd,tag);
  until false;

  DoneSoundSystem;
 except
  on E:Exception do writeln('Error: '+ExceptionMsg(e));
 end;
end.
