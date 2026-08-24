// Console demo for the sound subsystem: plays samples and music through
// whatever backend is compiled in (SDL2_mixer by default, see defines.inc).
//
// Usage:
//   SoundDemo                 - interactive mode: type commands or 1..N
//   SoundDemo 5 w2000 1 w5000 - script mode: run the listed commands, then exit
// A script item is either a command ("Play\Sample"), a predefined command
// number, a delay in milliseconds ("w2000"), or the check "check:music"
// which fails the run unless a music track is playing at that moment.
{$APPTYPE CONSOLE}

program SoundDemo;

uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.Conv,
  Apus.Files,
  Apus.Log,
  Apus.EventMan,
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

// Resolve a numeric shortcut into a real command
function ExpandCommand(cmd:string):string;
 var
  v:integer;
 begin
  result:=cmd;
  if length(cmd)>2 then exit;
  v:=Conv.ToInt(cmd);
  if (v>0) and (v<=high(defaultCmd)) then result:=defaultCmd[v];
 end;

procedure RunCommand(cmd:string);
 begin
  if SameText(cmd,'check:music') then begin
   if IsMusicPlaying then
    writeln('check:music - playing')
   else
    // logged as an error, so a script run fails with a non-zero exit code
    Log.Error('[SOUNDDEMO] check:music failed - no music is playing');
   exit;
  end;
  cmd:=ExpandCommand(cmd);
  writeln('SOUND\'+cmd);
  Signal('SOUND\'+cmd);
 end;

// Non-interactive mode: run the command line as a script and exit
procedure RunScript;
 var
  i,delay:integer;
  st:string;
 begin
  for i:=1 to ParamCount do begin
   st:=ParamStr(i);
   if (length(st)>1) and (st[1] in ['w','W']) and (Conv.ToInt(copy(st,2,10))>0) then begin
    delay:=Conv.ToInt(copy(st,2,10));
    writeln('(wait ',delay,' ms)');
    CoreTime.Sleep(delay);
   end else
    RunCommand(st);
  end;
  // let the last command be heard before shutting the system down
  CoreTime.Sleep(500);
 end;

procedure RunInteractive;
 var
  cmd:string;
 begin
  writeln('Enter a command (like "Play\Sample"), or 1..',high(defaultCmd),
    ' for predefined commands, or "q" to exit.');
  repeat
   write('Sound\:');
   readln(cmd);
   if SameText(cmd,'q') then break;
   if cmd<>'' then RunCommand(cmd);
  until false;
 end;

begin
 try
  Logger.UseLogFile('SoundDemo.log',true);
  // The demo runs either from the build output folder (bin64) or from its own one
  if Folder.Exists('../demo/SoundDemo/Res') then
   soundFolderPath:='../demo/SoundDemo/Res/'
  else
   soundFolderPath:='Res/';
  soundConfigFile:=soundFolderPath+'sounds.ctl';
  writeln('Sound resources: ',soundFolderPath);
  if not FileExists(soundConfigFile) then
   raise EError.Create('Sound configuration not found: '+soundConfigFile);
  InitSoundSystem(slDefault); // whichever backend is compiled in

  if ParamCount>0 then RunScript
   else RunInteractive;

  DoneSoundSystem;
  // Playback problems are logged as errors, so a script run can be a CI check
  if Logger.GetErrorCount>0 then begin
   writeln('FAILED: ',Logger.GetErrorCount,' error(s) logged, see SoundDemo.log');
   ExitCode:=1;
  end;
 except
  on e:Exception do begin
   writeln('Error: '+ExceptionMsg(e));
   ExitCode:=1;
  end;
 end;
end.
