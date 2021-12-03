// IMixerPro Sound System by Igor Lobanchikov: http://apus-software.com/imixer/
// Installer (dll + lib + documentation): http://apus-software.com/imixer/bin/IMixerPro.exe
// Don't confuse IMix* (IMixer) and IMX* (IMixerPro) - they are different things.
unit IMixEx;
{$IF not Defined(MSWINDOWS) or Defined(CPU64) or Defined(CPUx64)}
 {$FATAL 'IMixer is only available on Win32'}
{$ENDIF}
interface
uses windows;
type
 HSample=DWORD;
 HChannel=DWORD;
 HStream=DWORD;
 HMod=DWORD;
 HSYNC=DWORD;
 //      Sync callback
 SyncProc=procedure(handle:HSync;channel:HChannel;data,user:DWORD); stdcall;

 PIMX3DVector=^IMX3DVECTOR;
 IMX3DVECTOR=record
  x,y,z:single;
 end;


const
 IMX_OK          = 0;

 //   IMXInit flags
 IMX_INIT_8BIT       = 1;
 IMX_INIT_MONO       = 2;

 //   IMXModulePlay flags
 IMX_MODULE_LOOP     = 1;
 IMX_MODULE_POSRESET = 2;

 //   IMXStreamPlay flags
 IMX_STREAM_LOOP     = 1;
 IMX_STREAM_3D       = 4;
 IMX_STREAM_FORCERIGHT = $10;
 IMX_STREAM_FORCELEFT  = $20;
 IMX_STREAM_FORCEMONO  = $30;

 //   IMXSampleLoad flags
 IMX_SAMPLE_LOOP     = 1;
 IMX_SAMPLE_3D       = 4;

 //   IMXSampleSet3DParameters
 //   IMXChannelSet3DParameters
 IMX_3DMODE_NORMAL   = 0;
 IMX_3DMODE_HEADRELATIVE = 1;
 IMX_3DMODE_DISABLE  = 2;

 //   IMXChannelSetSync type
 IMX_SYNC_END        = 1;
 IMX_SYNC_POS        = 2;
 IMX_SYNC_EVMASK     = $0FFFFFF;
 IMX_SYNC_MIXTIME    = $4000000;

 //  3D Algorythms
 IMX_3DALG_DEFAULT   = 0;
 IMX_3DALG_OFF       = 1;
 IMX_3DALG_FULL      = 2;
 IMX_3DALG_LIGHT     = 3;

 //      Initialization done
 function IMXInit(hwnd:HWnd;freq,flags:DWORD;reserved:integer=-1):boolean; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXUninit:longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXStart:longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXStop:longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXPause(Pause:longbool):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};

 //      Control mixer
 function IMXSetGlobalVolumes(modvol,smpvol,streamvol:integer):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXGetGlobalVolumes(var modvol,smpvol,streamvol:integer):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXSetBlockSize(sec:double):double; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXGetVersion:cardinal; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};

 //      3D functions
 function IMXCommit3D:longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXSetListnerPosition(Pos:PIMX3DVector=nil;vel:PIMX3DVector=nil;
            front:PIMX3DVector=nil;top:PIMX3DVector=nil):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXSetEnvironmentFactors(distance:single=-1;rolloff:single=-1;doppler:single=-1):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 procedure IMXSet3DAlgorithm(Algorithm:cardinal=IMX_3DALG_DEFAULT); cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};

 //      Sample
 function IMXSampleLoad(FromMem:longbool;FileName:PAnsiChar;Offset:DWORD=0;
                        Length:DWord=0;res2:DWORD=0;Flags:DWORD=0):HSample; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXSamplePlay(hsmp:HSAMPLE;vol:integer=100;pan:integer=0;
                        freq:DWORD=0;start:DWORD=0):HChannel; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXSamplePlay3D(hsmp:HSAMPLE;pos:PIMX3DVector=nil;orient:PIMX3DVector=nil;
            vel:PIMX3DVector=nil;vol:integer=100;freq:cardinal=0;start:cardinal=0):HChannel; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXSampleSet3DParameters(hsmp:HSAMPLE;IAngle:integer=-1;OAngle:integer=-1;outVol:integer=-1;
            MinDist:single=-1;MaxDist:single=-1;Mode:integer=-1):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXSampleUnload(hsmp:HSample):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};

 //      Module
 function IMXModuleLoad(FromMem:longbool;FileName:PAnsiChar;Offset:DWORD=0;
                        Length:DWORD=0;res2:DWORD=0):HMod; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXModulePlay(hmod:HMod;flags:integer=-1):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXModuleUnload(hmod:HMod):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXModuleAttachInstruments(targethmod,sourcehmod:HMod):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXModuleAdjustBPM(hmod:HMod;bpm:double=1):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};

 //      Stream
 function IMXStreamOpenFile(fromMem:longbool;filename:PAnsiChar;offset:DWORD=0;
            length:DWORD=0;flags:DWORD=0):HStream; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXStreamPlay(hstream:HStream;flags:integer=-1):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXStreamClose(hstream:HStream):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};

 //      Channel
 function IMXChannelStop(hchan:HChannel):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXChannelSetAttributes(hchan:HChannel;vol:integer=-1;pan:integer=-101;
                                  freq:integer=-1):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXChannelSetSync(hchan:HChannel;sType,param:DWORD;proc:SyncProc;
                            User:DWORD):HSync; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXChannelSlide(hchan:HChannel;vol:integer=-1;pan:integer=-101;freq:DWORD=0;
                          time:integer=100):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXChannelSetPosition(hchan:HChannel;pos:DWORD):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXChannelRemoveSync(hchan:HChannel;sync:HSync):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXChannelSet3DParameters(hchan:HChannel;IAngle:integer=-1;OAngle:integer=-1;
            outVol:integer=-1;MinDist:single=-1;MaxDist:single=-1;
            Mode:integer=-1):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};
 function IMXChannelSet3DPosition(hchan:HChannel;pos:PIMX3DVector=nil;orient:PIMX3DVector=nil;
                                  vel:PIMX3DVector=nil):longbool; cdecl; external 'IMxEx.dll' {$IFNDEF FPC} delayed {$ENDIF};

implementation

end.
