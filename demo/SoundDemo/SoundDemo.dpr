// Console demo for the sound subsystem: plays samples and music through
// whatever backend is compiled in (SDL2_mixer by default, see defines.inc).
//
// Usage:
//   SoundDemo                 - interactive mode: type commands or 1..N
//   SoundDemo 5 w2000 1 w5000 - script mode: run the listed commands, then exit
// A script item is either a command ("Play\Sample"), a predefined command
// number, a delay in milliseconds ("w2000"), a direct call of the sound API:
//   tone:F,MS      - a procedural sine tone of F Hz for MS milliseconds
//   sweep          - plays Sample and slides its speed from 1 to 2 over a second
//   cut            - stops a 2 s tone after 0.5 s: the stop fades out, no click
// or a check:
//   check:music    - fails the run unless a music track is playing at that moment
//   check:played=N - fails the run unless exactly N Sound\FilePlayed notifications came
// "%res%" in a command is replaced with the resource folder.
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

type
 TPredefined=record
  cmd,hint:string;
 end;

const
 defaultCmd:array[1..21] of TPredefined=(
  (cmd:'PlayMusic\testOGG'; hint:'music, ogg'),
  (cmd:'PlayMusic\testMP3'; hint:'music, mp3'),
  (cmd:'PlayMusic\testMOD::3'; hint:'music, a module, transition 3 (fade-out, then fade-in)'),
  (cmd:'PlayMusic\None'; hint:'stop the music'),
  (cmd:'Play\Sample'; hint:'sample'),
  (cmd:'Play\Stereo'; hint:'stereo sample'),
  (cmd:'Play\Low'; hint:'low-rate sample'),
  (cmd:'Play\Wav'; hint:'wav sample'),
  (cmd:'Play\sampleLeft'; hint:'sample panned left'),
  (cmd:'Play\sampleQuiet'; hint:'quiet sample'),
  (cmd:'SetGroup\file,duck=20,exclusive=1'; hint:'files duck the music to 20%, one at a time'),
  (cmd:'PlayFile\%res%sampleStereo.ogg'; hint:'play a file outside the config'),
  (cmd:'StopAllFiles'; hint:'stop the files of 12 (not music or samples)'),
  (cmd:'ClearCache'; hint:'unload the samples'),
  (cmd:'PlayMusic\testLoop'; hint:'loop: 330 Hz intro once, then a seamless 440 Hz loop'),
  (cmd:'PlayMusic\testLoopTime'; hint:'the same, the loop start given in seconds'),
  (cmd:'Play\Sample,speed=2'; hint:'an octave higher, twice shorter'),
  (cmd:'tone:440,1000'; hint:'procedural tone'),
  (cmd:'sweep'; hint:'sample speed slides from 1 to 2'),
  (cmd:'PlayMusic\testLoopBad'; hint:'a loop start 2 ms off: how a click sounds'),
  (cmd:'cut'; hint:'a tone stopped early: no click'));

 // Fade-in and fade-out of a tone (sec): a sine that starts or ends at full slope clicks
 TONE_EDGE = 0.005;

type
 // Procedural sound of the demo: a sine tone
 TTone=record
  freq:single;
  duration:single; // seconds
  phase:double;    // 0..1
  total:integer;   // values per channel in the tone
  left:integer;    // values per channel still to generate, -1 = not started
 end;
 PTone=^TTone;

var
 filesPlayed:integer; // Sound\FilePlayed notifications received
 tones:array of PTone; // freed after the sound system stops
 i:integer;

// Stream procedure (audio thread): it touches only the fields of its own tone
function ToneProc(data:PSingle;count,channels,sampleRate:integer;userData:pointer):boolean;
 var
  tone:PTone;
  i,c,edge:integer;
  v,env:single;
 begin
  tone:=userData;
  if tone.left<0 then begin
   tone.total:=round(tone.duration*sampleRate);
   tone.left:=tone.total;
  end;
  edge:=round(TONE_EDGE*sampleRate);
  for i:=1 to count do begin
   v:=0;
   if tone.left>0 then begin
    env:=1;
    if tone.total-tone.left<edge then env:=(tone.total-tone.left)/edge;
    if tone.left<edge then env:=tone.left/edge;
    v:=0.5*env*sin(2*Pi*tone.phase);
    tone.phase:=frac(tone.phase+tone.freq/sampleRate);
    dec(tone.left);
   end;
   for c:=1 to channels do begin
    data^:=v;
    inc(data);
   end;
  end;
  result:=tone.left>0;
 end;

// tone:F,MS
function PlayTone(const params:string):TChannel;
 var
  tone:PTone;
  p:integer;
 begin
  p:=Pos(',',params);
  New(tone);
  tone.freq:=Conv.ToInt(copy(params,1,p-1));
  tone.duration:=Conv.ToInt(copy(params,p+1,10))/1000;
  tone.phase:=0;
  tone.left:=-1;
  SetLength(tones,length(tones)+1);
  tones[high(tones)]:=tone;
  result:=sound.PlayStream(ToneProc,tone,1);
  if result=0 then Log.Error('[SOUNDDEMO] the tone did not start');
 end;

procedure OnFilePlayed(event:TEventStr;tag:TTag);
 begin
  Atomic.Inc(filesPlayed);
  writeln(event);
 end;

// Resolve a numeric shortcut into a real command
function ExpandCommand(cmd:string):string;
 var
  v:integer;
 begin
  result:=cmd;
  if length(cmd)>2 then exit;
  v:=Conv.ToInt(cmd);
  if (v>0) and (v<=high(defaultCmd)) then result:=defaultCmd[v].cmd;
 end;

procedure RunCommand(cmd:string);
 var
  ch:TChannel;
 begin
  cmd:=ExpandCommand(cmd);
  if SameText(copy(cmd,1,5),'tone:') then begin
   writeln(cmd);
   PlayTone(copy(cmd,6,20));
   exit;
  end;
  if SameText(cmd,'cut') then begin
   writeln('cut: a 2 s tone stopped after 0.5 s');
   ch:=PlayTone('440,2000');
   CoreTime.Sleep(500);
   sound.StopChannel(ch);
   exit;
  end;
  if SameText(cmd,'sweep') then begin
   writeln('sweep: speed 1 -> 2 over 1 s');
   ch:=sound.Play('Sample');
   sound.SetChannelSpeed(ch,2,1);
   exit;
  end;
  if SameText(cmd,'check:music') then begin
   if sound.IsMusicPlaying then
    writeln('check:music - playing')
   else
    // logged as an error, so a script run fails with a non-zero exit code
    Log.Error('[SOUNDDEMO] check:music failed - no music is playing');
   exit;
  end;
  if SameText(copy(cmd,1,13),'check:played=') then begin
   if Atomic.Add(filesPlayed,0)=Conv.ToInt(copy(cmd,14,10)) then
    writeln(cmd+' - ok')
   else
    Log.Error('[SOUNDDEMO] %s failed - %d file(s) played',[cmd,Atomic.Add(filesPlayed,0)]);
   exit;
  end;
  cmd:=StringReplace(cmd,'%res%',soundFolderPath,[rfIgnoreCase]);
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
  i:integer;
 begin
  for i:=1 to high(defaultCmd) do
   writeln(i:3,'  ',defaultCmd[i].cmd,' - ',defaultCmd[i].hint);
  writeln('Enter a command (like "Play\Sample"), or 1..',high(defaultCmd),
    ' for predefined commands, or "q" to exit.');
  repeat
   write('Sound\:');
   if EOF then break; // the input is closed (redirected from a file or a pipe)
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
  sound.Init(slDefault); // whichever backend is compiled in
  SetEventHandler('SOUND\FILEPLAYED',OnFilePlayed,emInstant);

  if ParamCount>0 then RunScript
   else RunInteractive;

  sound.Done;
  for i:=0 to high(tones) do Dispose(tones[i]);
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
