unit skale;
interface

type
 // Windows Output Modes
 {$MINENUMSIZE 4}
 EOutputMode=(INIT_MODE_WAVEOUT = 0,  // WaveOut
    INIT_MODE_DSOUND,       // DirectSound
    INIT_MODE_ASIO,         // ASIO
    INIT_MODE_NOSOUND,      // NoSound
    INIT_MODE_SLAVE        // Slave mode
 );
 EInitFlags=(INIT_FLAG_NONE = 0  // None
 );
 EInitError=(INIT_OK = 0,            // OK
    INIT_ERROR_UNDEFINED   // Error
 );

 EPlayMode=(PLAY_MODE_PLAY_SONG_FROM_START = 0,       // Play song from start
    PLAY_MODE_PLAY_SONG_FROM_CURRENT_POS,     // Play song from current position
    PLAY_MODE_PLAY_PATTERN_FROM_START,        // Play patern from start
    PLAY_MODE_PLAY_PATTERN_FROM_CURRENT_POS,  // Play pattern from current position
    PLAY_MODE_STOP_PLAYBACK,                  // Stop playback
    PLAY_MODE_STOP_ENGINE                     // Stop mixer engine
);

 TInitData=packed record
    m_eMode:EOutputMode;              // Output Mode
    m_iDevice:integer;            // Output Device number
    m_iSamplesPerSecond:integer;  // SamplesPerSecond
    m_eFlags:EInitFlags;             // Flags
 end;

 TPlayInfo=record
  iPatternListPos:integer;
  iPattern:integer;
  iRow:integer;
 end;

 ISong=class
 end;

 ISkalePlayer=class
  destructor Destroy; virtual;
  function GetSkalePlayer:ISkalePlayer; cdecl;
  function Init(const InitData:TInitData):EInitError; stdcall;
  procedure Done; stdcall;
  function LoadSongFromFile(fname:PChar):ISong; stdcall;
  procedure FreeSong(song:ISong); stdcall;
  procedure SetCurrentSong(song:ISong); stdcall;
  procedure SetPlayMode(mode:EPlayMode); stdcall;
  procedure SetPlayPatternListPos(iPatternListPos:integer); stdcall;
  procedure GetPlayInfo(var info:TPlayInfo); stdcall;
  procedure SlaveProcess(buf:pointer;samples:integer); stdcall;
 end;


implementation
 function ISkalePlayer.GetSkalePlayer; external 'skalePlayer.dll' name '?GetSkalePlayer@ISkalePlayer@@SAPAV1@XZ';
 destructor ISkalePlayer.Destroy;
  begin
  end;

 procedure ISkalePlayer.Done;
  asm
   mov ecx,self
   mov eax,[ecx]
   call [eax+8]
  end;

function ISkalePlayer.Init(const InitData:TInitData):EInitError;
  asm
   mov eax,InitData
   push eax
   mov ecx,self
   mov eax,[ecx]
   call [eax+4]
  end;

 function ISkalePlayer.LoadSongFromFile(fname:PChar):ISong; stdcall;
  asm
   mov eax,fname
   push eax
   mov ecx,self
   mov edx,[ecx]
   call [edx+12]
  end;

 procedure ISkalePlayer.FreeSong(song: ISong);
  asm
   mov eax,song
   push eax
   mov ecx,self
   mov eax,[ecx]
   call [eax+20]
  end;

 procedure ISkalePlayer.SetCurrentSong(song: ISong);
  asm
   mov eax,song
   push eax
   mov ecx,self
   mov eax,[ecx]
   call [eax+24]
  end;

 procedure ISkalePlayer.SetPlayMode(mode: EPlayMode);
  asm
   mov eax,mode
   push eax
   mov ecx,self
   mov eax,[ecx]
   call [eax+28]
  end;

 procedure ISkalePlayer.SetPlayPatternListPos(iPatternListPos:integer);
  asm
   mov eax,iPatternListPos
   push eax
   mov ecx,self
   mov eax,[ecx]
   call [eax+32]
  end;

 procedure ISkalePlayer.GetPlayInfo(var info:TPlayInfo);
  asm
   mov eax,info
   push eax
   mov ecx,self
   mov eax,[ecx]
   call [eax+36]
  end;

 procedure ISkalePlayer.Slaveprocess(buf:pointer;samples:integer);
  asm
   mov eax,samples
   push eax
   mov eax,buf
   push eax
   mov ecx,self
   mov eax,[ecx]
   call [eax+40]
  end;

end.

