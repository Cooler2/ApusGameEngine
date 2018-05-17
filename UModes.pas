{$R-}
unit UModes;

interface
uses EngineCls,BasicGame,ImageMan,CommonUI,UIClasses,EventMan,
     enginetools,Images,TweakScene,
  {$IFDEF MSWINDOWS}
    {$IFDEF DIRECTX}d3d8,DxImages8,dxGame8,{$ENDIF}
    {$IFDEF OPENGL}dglOpenGL,GLImages,GLgame,{$ENDIF}
  {$ENDIF}
  {$IFDEF IOS}GLImages,IOSgame,{$ENDIF}
  {$IFDEF ANDROID}GLImages,AndroidGame,{$ENDIF}
  Console;

const
 UsedAPI:TGraphicsAPI=gaOpenGL;

type
tmode=class;

tInternalScene=class(tUIScene)
 mode:tmode;
 function Process:boolean; override;
 procedure onMouseBtn(btn:byte;pressed:boolean); override;
 procedure onMouseMove(x,y:integer); override;
 procedure onMouseWheel(delta:integer); override;
 procedure Render; override;
 procedure SetStatus(st:TSceneStatus); override;
end;

tmode=class
 windowed,moveable:boolean;
 wasinit,minimized:boolean;
 lastdrawtime:integer;
 name:string;
 baseimagefile:string;
 xpos,ypos,width,height:integer;
 scene:tInternalScene;
 wndimage:tUIImage;
 Skinnedwnd:TUISkinnedWindow;
 Mainwnd:TUIWindow;
 background:TTexture;
 needcorrectwindow:boolean;
 modified:boolean; // should be set to FALSE in Process if scene don't need to be repainted
 preloadOrder:integer; // приоритет вызова preload (чем больше - тем раньше запускается), default=10 (0 - не запускается вообще)
 function Visible:boolean;
 procedure Process; virtual;
 procedure MouseBtn(btn:byte;pressed:boolean); virtual;
 procedure MouseMove(x,y:integer); virtual;
 procedure MouseWheel(delta:integer); virtual;
 // Called for events: "UI\ModeName\*" (sync mode) and "SCENES\ModeName\*" (async mode)
 procedure ProcessSignal(event:EventStr;tag:integer); virtual;
// procedure Network(datasize:integer;datapointer:pnetdata); virtual; // datasize=0 connection broken
 procedure ConnectionEstablished; virtual;
 procedure Show(effnumber,time:integer); virtual;
 procedure ShowNonModal(effnumber,time:integer); virtual;
 procedure Hide(effnumber,time:integer); virtual;
 procedure Draw(x,y:integer); virtual;
 procedure DrawAfterUI(x,y:integer); virtual;
 procedure Addscene;
 procedure ModeInit; virtual;
 procedure Preload; virtual;  // вызывается в отдельном потоке при старте игры, тут можно загрузить графику или делать какой-то препроцессинг 
 procedure FreeMemory; virtual;
 procedure Restore; virtual;
 constructor Create(modeName:string;preInit:boolean=true); virtual;
 procedure LanguageChanged; virtual;
 procedure ScreenSizeChanged; virtual;
 procedure StatusChanged; virtual;
 procedure onClosing; virtual;
end;

tregisteredmode=object
 mode:tmode;
 preinitrequired:boolean;                 
end;

tstepsinfo=object
 totalvalue:integer;
 steps:array[1..250] of integer;
end;

procedure BasicGameInit(gametitle:string;gamewidth:integer=1024;gameheight:integer=768;
   firstmessage:string='';unicodeMode:boolean=false;maxFPS:boolean=false);
procedure GameDone;
procedure InitModes;
procedure PreloadModes;
procedure CheckProgress;
function CreateImage(filename:string;transparent:boolean=true;allowModify:boolean=false):TTextureImage;
function LoadFont(filename:string):integer;
function GetProgressValue:integer;
procedure DetermineSettings;
{procedure CursorLoader(reason:TReason;var image:TImgDescriptor);
procedure CursorDrawer(image:TImgDescriptor;x,y:integer;color:cardinal;p1,p2,p3,p4:single);}

var smallfont,mainfont,largefont:cardinal; // to be initialized in project code
    defmtwidth:integer=1024;
    defmtheight:integer=1024;
    retinaScreen:boolean;
    windowedMode:boolean;
    DebugMode:boolean;
    game:TBasicGame;
(*    {$IFDEF DIRECTX}
    game:TDxGame8;
    {$ENDIF}
    {$IFDEF OPENGL}
    game:TGLGame;
    {$ENDIF} *)
    {$IFDEF IOS}
    game:TIOSGame;
    {$ENDIF}

    DefColorDepth:byte=32;
    refreshRate:integer=0;
    windowFullScreen:boolean=true; // окно на весь экран
    CenterImage:boolean=false; // располагать изображение по центру, если окно больше нужного размера
    useSystemCursor:boolean=true; // Использовать системный курсор
    stepsinfo,stepsout:tstepsinfo;
    curvalue,firstprogress,larstprogress,larstsleep:integer;
    curstep:integer;
    configDir:string='';

implementation
uses {$IFDEF MSWINDOWS}windows,{$ELSE}CrossPlatform,{$ENDIF}
     BasicPainter,sysutils,stdEffects,directtext,ControlFiles2,
     MyServis,types,UDict,conScene;


var nummodes:integer=0;
    modes:array[1..1024] of tregisteredmode;
    lasttime:integer;
    curorder:integer=1;

function TMode.Visible:boolean;
begin
 result:=false;
 if self=nil then exit;
 if (scene<>nil) and (scene.status=ssActive) then result:=true;
end;

function getprogressvalue:integer;
var q,w:integer;
begin
 result:=0;
{ result:=curvalue;
 if (curvalue<stepsinfo.totalvalue)and(stepsinfo.totalvalue<>0) then
 begin
  q:=stepsinfo.steps[curstep+1];
  if q>0 then
  begin
   w:=curvalue*(getcurtime-larstprogress) div (larstprogress-firstprogress+20);
   if w>q then w:=q;
   inc(result,w);
  end;
 end;}
end;

procedure CheckProgress;
var f:file of tstepsinfo;
    w,e:integer;
begin
 exit;
 if game.terminated then
  raise EError.Create('Game is terminated');
 {$IFNDEF IOS}
 if stepsinfo.totalvalue=0 then
 begin
  firstprogress:=getcurtime;
  larstsleep:=firstprogress;
  w:=0;
  if fileexists('Inf\Steps.spe') then
  begin
   try
    assign(f,'Inf\Steps.spe');
    reset(f);
    read(f,stepsinfo);
    close(f);
   except
    w:=1;
   end;
  end else w:=1;
  if w=1 then
  begin
   stepsinfo.totalvalue:=100;
  end;
  lasttime:=getcurtime;
  curstep:=0;
  curvalue:=0;
 end else
 begin
  larstprogress:=getcurtime;
  inc(curstep);
  inc(curvalue,stepsinfo.steps[curstep]);

  e:=lasttime;
  lasttime:=getcurtime;
  stepsout.steps[curstep]:=lasttime-e;
  inc(stepsout.totalvalue,stepsout.steps[curstep]);

  assign(f,'Inf\Steps.out');
  rewrite(f);
  write(f,stepsout);
  close(f);
 end;
 if larstprogress-larstsleep>70 then
 begin
  Sleep(1);
  larstsleep:=larstprogress;
 end;
 {$ENDIF}
end;

function LoadFont(filename:string):integer;
var
 q:integer;
 font2x:string;
 scale:boolean;
begin
 {$IFDEF ANDROID}
 result:=0; exit;
 {$ENDIF}
 font2x:=StringReplace(filename,'.fnt','2x.fnt',[rfIgnoreCase]);
 scale:=false;
 if retinaScreen and FileExists(font2x) then begin
  filename:=font2x; scale:=true;
 end;
 q:=LoadRasterFont(filename);
 result:=painter.PrepareFont(q);
 if scale then painter.SetFontScale(result,2);
end;

function CreateImage(filename:string;transparent:boolean=true;allowModify:boolean=false):TTextureImage;
var
 flags:cardinal;
begin
 if allowModify then flags:=liffAllowChange
  else flags:=0;
 if pos('.',filename)>0 then
 begin
  filename:=uppercase(filename);
  if copy(filename,length(filename)-3,4)='.TXT' then
   result:=LoadImageFromFile(filename,flags) as TTextureImage
  else
   if transparent then
    result:=LoadImageFromFile(filename,flags+MTFlags(defmtwidth,defmtheight),pftruecoloralpha) as TTextureImage else
   result:=LoadImageFromFile(filename,flags+MTFlags(defmtwidth,defmtheight),pftruecolor) as TTextureImage;
 end else
{ if fileexists(filename+'.jpg') then
  result:=CreateImage(filename+'.jpg') else
 if fileexists(filename+'.tga') then
  result:=CreateImage(filename+'.tga') else
 if fileexists(filename+'.txt') then
  result:=CreateImage(filename+'.txt') else
 begin
  forcelogmessage('Strange image: '+filename);}
  result:=LoadImageFromFile(filename,flags+MTFlags(defmtwidth,defmtheight)) as TTextureImage;
// end;
end;

procedure InitModes;
var q:integer;
 w:int64;
begin
 LogMessage('Init modes');
 for q:=1 to nummodes do
  if modes[q].preinitrequired then
  begin
   w:=MyTickCount;
//   CheckProgress;
   {$IFDEF ESTVERSION}ForceLogMessage{$else}LogMessage{$endif}('Initializing mode '+modes[q].mode.name);
   modes[q].mode.ModeInit;
   HandleSignals;
   {$IFDEF ESTVERSION}ForceLogMessage{$else}LogMessage{$endif}(modes[q].mode.name+
    ' is ready. Loading time '+inttostr(MyTickCount-w));
  end;
 LogMessage('Init modes done!');
end;

procedure PreloadModes;
var
 i,j:integer;
 order:array[1..100] of integer;
 t:int64;
begin
 for i:=1 to nummodes do order[i]:=i;
 for i:=1 to nummodes-1 do
  for j:=i+1 to numModes do
   if modes[order[j]].mode.preloadOrder>modes[order[i]].mode.preloadOrder then
    Swap(order[i],order[j]);

 for i:=1 to nummodes do
  begin
   j:=order[i];
   if modes[j].mode.preloadOrder<=0 then break;
   LogMessage('Loading mode '+modes[j].mode.name);
   t:=MyTickCount;
   modes[j].mode.Preload;
   LogMessage(modes[j].mode.name+' loaded, time='+inttostr(MyTickCount-t));
   HandleSignals;
  end;
end;

{function CursorEventHandler(event:EventStr;tag:integer):boolean;
var
 flag:boolean;
begin
 flag:=event[length(event)]='N';
 case tag of
  CursorLink:game.ToggleCursor(CursorLink,flag);
  crResizeH:game.ToggleCursor(CursorNS,flag);
  crResizeW:game.ToggleCursor(CursorWE,flag);
  crResizeHW:game.ToggleCursor(CursorAll,flag);
 end;
 result:=false;
end;}

procedure DetermineSettings;
var
  adaptername:string[250];
  i:integer;
begin
 adaptername:='';
 {$IFDEF DIRECTX}
 if UsedAPI=gaDirectX then begin
  for i:=0 to length(d3d8.primaryAdapter.Description) do
   if d3d8.primaryAdapter.Description[i]<>#0 then
    adaptername:=adaptername+UpCase(d3d8.primaryAdapter.Description[i])
   else break;
  ForceLogMessage('Primary adapter: '+adaptername);
  if pos('RIVA TNT',adaptername)>0 then
   DisableEffects:=true;
  end; 
 {$ENDIF}
 {$IFDEF OPENGL}
 if usedAPI=gaOpenGL then begin
  if (not GL_ARB_framebuffer_object) or
     (not GL_VERSION_2_0) then
   DisableEffects:=true;
 end;
 {$ENDIF}
end;

(*procedure CursorLoader(reason:TReason;var image:TImgDescriptor);
begin
 {$IFNDEF IOS}
 if reason=rPrepare then begin
  if image.name='DEFAULT' then begin
   image.tag:=LoadCursorFromFile('images\cursors\default.cur');
  end;
  if image.name='HAND' then begin
   image.tag:=LoadCursor(0,IDC_HAND);
  end;
  if image.name='RESIZENS' then begin
   image.tag:=LoadCursor(0,IDC_SIZENS);
  end;
  if image.name='RESIZEWE' then begin
   image.tag:=LoadCursor(0,IDC_SIZEWE);
  end;
  if image.name='RESIZEALL' then begin
   image.tag:=LoadCursor(0,IDC_SIZEALL);
  end;
 end else begin
  // Курсоры освобождать нет нужды...
 end;
 {$ENDIF}
end;

procedure CursorDrawer(image:TImgDescriptor;x,y:integer;color:cardinal;p1,p2,p3,p4:single);
var
 cur:HCursor;
begin
 {$IFNDEF IOS}
 cur:=GetCursor;
 if cur<>HCursor(image.tag) then
  SetCursor(HCursor(image.tag));
 {$ENDIF}
end; *)

function EventHandler(event:eventStr;tag:integer):boolean;
var
 i:integer;
begin
 result:=true;
 event:=UpperCase(event);
 // Language changed?
 if event='UI\LANGUAGECHANGED' then begin
  for i:=1 to nummodes do try
   modes[i].mode.LanguageChanged;
  except
   on e:exception do ForceLogMessage('Error in '+modes[i].mode.name+' LanguageChanged: '+ExceptionMsg(e));
  end;
  exit;
 end;
 // Screen resolution changed?
 if event='UI\SCREENSIZECHANGED' then begin
  for i:=1 to nummodes do try
   modes[i].mode.ScreenSizeChanged;
  except
   on e:exception do ForceLogMessage('Error in '+modes[i].mode.name+' ScreenSizeChanged: '+ExceptionMsg(e));
  end;
  exit;
 end;
end;

procedure BasicGameInit(gametitle:string;gamewidth:integer=1024;gameheight:integer=768;
   firstmessage:string='';unicodeMode:boolean=false;maxFPS:boolean=false);
var q:integer;
    st,logmode:string;
    settings:TGameSettings;
    {$IFDEF MSWINDOWS}
    wi:TWindowInfo;
    {$ENDIF}
begin
 Randomize;
 logmode:='';
 // Определить цель запуска exe-шника
 for q:=1 to ParamCount do
 begin
  st:=UpperCase(ParamStr(q));
  if pos('-V',st)=1 then begin
   logMode:=copy(st,3,length(st)-2);
  end;
  if st='-WND' then begin
   WindowedMode:=true;
   windowFullScreen:=false;
  end;
  if st='-DBG' then DebugMode:=true;
 end;
 logMode:=logmode+'268';
 if FileExists(configDir+'game.log') then begin
  if FileExists(configDir+'game.old') then DeleteFile(configDir+'game.old');
  RenameFile(configDir+'game.log',configDir+'game.old');
 end;
 UseLogFile(configDir+'game.log');
 if firstmessage<>'' then
  forcelogmessage(firstmessage);
 CritMsg('Game launched at '+FormatDateTime('ddddd tttt',now)+' in '+GetCurrentDir);
 SetLogMode(lmVerbose,logMode);
 if not debugMode then
 {$IFDEF MSWINDOWS}
 LogCacheMode(true,false,true);
 {$ELSE}
 LogCacheMode(true,false,false);
 {$ENDIF}

 RegisterThread('ControlThread');

 {$IFDEF MSWINDOWS}
   {$IFDEF DIRECTX}
   if usedAPI=gaDirectX then game:=TDxGame8.Create(80);
   {$ENDIF}
   {$IFDEF OPENGL}
   if usedAPI=gaOpenGL then game:=TGLGame.Create(false);
   if usedAPI=gaOpenGL2 then game:=TGLGame.Create(true);
   {$ENDIF}
 {$ENDIF}
 {$IFDEF IOS}
 game:=TIOSGame.Create;
 {$ENDIF}
 {$IFDEF ANDROID}
 game:=TAndroidGame.Create();
 {$ENDIF}
 if game=nil then raise EError.Create('Game object not created!');
 with settings do
 begin
  title:=GameTitle;
  width:=gamewidth;
  height:=gameheight;
  colorDepth:=DefColorDepth;
  refresh:=RefreshRate;
  if WindowedMode then begin
   if windowFullScreen then begin
    altmode:=dmNone;
    mode:=dmFullScreen;
   end else begin
    mode:=dmFixedWindow;
    altMode:=dmNone;
   end;
  end else begin
   mode:=dmSwitchResolution;
   altMode:=dmFixedWindow;
  end;
  fitmode:=dfmKeepAspectRatio;
  showSystemCursor:=useSystemCursor;
  zbuffer:=16;
  stencil:=false;
  multisampling:=0;
  slowmotion:=false;
//  customCursor:=not useSystemCursor;
  if maxFPS then begin
   VSync:=0;
   game.showFPS:=true;
  end else
   VSync:=1;
 end;
 if settings.mode<>dmSwitchResolution then
  ForceLogMessage('Running in cooperative mode')
 else
  ForceLogMessage('Running in exclusive mode');

 if unicodeMode then begin
  ForceLogMessage('Unicode mode ON');
  game.unicode:=true;
 end;

 game.Settings:=settings;
 if DebugMode then game.ShowDebugInfo:=3;
 try
  game.Run;
 except
  on e:exception do begin
    ErrorMessage('Failed to run the game: '+ExceptionMsg(e));
    halt;
  end;
 end;
 ForceLogMessage('RUN');
 DetermineSettings;
 game.initialized:=true;
 InitUI;
 {$IFDEF IOS}
 filemode:=0;
 {$ENDIF}
 if retinaScreen or (game.RenderRect.Right>=1024) then
  (painter as TBasicPainter).PFTexWidth:=512; // more space for fonts

// InitUsableNetwork(game,rootDir);

 {$IFNDEF IOS}
{ SetDrawer('cursors\',CursorLoader,CursorDrawer);
 game.RegisterCursor(CursorDefault,1,'cursors\default');
 game.RegisterCursor(CursorLink,5,'cursors\hand');
 game.RegisterCursor(CursorNS,6,'cursors\resizeNS');
 game.RegisterCursor(CursorWE,6,'cursors\resizeWE');
 game.RegisterCursor(CursorAll,6,'cursors\resizeALL');
 SetEventHandler('UI\Cursor',CursorEventHandler);}
 {$ENDIF}
 CheckProgress;

 SetEventHandler('UI\LANGUAGECHANGED',@EventHandler,sync);
 SetEventHandler('UI\SCREENSIZECHANGED',@EventHandler,sync);

 AddConsoleScene;
 CreateTweakerScene(painter.GetFont('Default',6),painter.GetFont('Default',7));
end;

procedure GameDone;
begin
 // Остановка и деинициализация
// DoneUsableNetwork;
 DoneUI;
 // Вероятно game уже завершил работу, однако убедиться в этом нужно!
 game.Stop;
 game.Free;
 StopLogThread;
end;

function tInternalScene.Process:boolean;
begin
 try
  result:=inherited Process;
  mode.modified:=true;
  mode.Process;
  if  not mode.modified then result:=false;
 except
  on e:Exception do LogMessage('Error in Process of '+name+': '+ExceptionMsg(e));
 end;
end;

procedure tInternalScene.onMouseBtn(btn:byte;pressed:boolean);
var c,f:tUIControl;
begin
 inherited;
 try
  c:=underMouse;
  f:=focusedControl;
  if (f<>nil)and(f<>c)and(f.classType=TUIEditBox)and(pressed) then
   Setfocusto(nil);
  while (c<>nil)and(c.parent<>nil) do c:=c.parent;
  if (c<>UI) then exit;
  mode.MouseBtn(btn,pressed);
 except
  on e:Exception do LogMessage('Error in onMouseBtn for '+name+': '+ExceptionMsg(e));
 end;
end;

procedure tInternalScene.onMouseMove(x,y:integer);
begin
 inherited;
 try
{ c:=underMouse;
 while (c<>nil)and(c.parent<>nil) do c:=c.parent;
 if (c<>UI)and(c<>nil) then exit;}
 if mode.windowed=false then
  mode.MouseMove(x,y)
 else
 begin
  if mode.mainwnd<>nil then begin
   dec(x,mode.mainwnd.x); dec(y,mode.Mainwnd.y);
   if mode.wndimage<>nil then begin
    dec(x,mode.wndImage.x); dec(y,mode.wndImage.y);
   end;
  end;
  mode.MouseMove(x,y);
 end;
 except
  on e:Exception do LogMessage('Error in onMouseMove for '+name+': '+ExceptionMsg(e));
 end;
end;

procedure tInternalScene.onMouseWheel(delta:integer);
begin
 try
  mode.MouseWheel(delta);
 except
  on e:Exception do LogMessage('Error in onMouseWheel for '+name+': '+ExceptionMsg(e));
 end;
end;

procedure tInternalScene.Render;
begin
 if mode.windowed and (mode.baseimagefile='') then mode.Draw(UI.x,UI.y);
 inherited;
 if mode.windowed and (mode.baseimagefile='') then mode.DrawAfterUI(UI.x,UI.y);
end;

procedure TInternalScene.SetStatus(st:TSceneStatus);
begin
 inherited;
 if mode<>nil then mode.StatusChanged;
end;


procedure tmode.Process;
begin
end;

procedure tmode.MouseBtn(btn:byte;pressed:boolean);
begin
end;

procedure tmode.MouseMove(x,y:integer);
begin
end;

procedure tmode.MouseWheel(delta:integer);
begin
end;

procedure tmode.ProcessSignal(event:EventStr;tag:integer);
begin
end;

{procedure tmode.Network(datasize:integer;datapointer:pnetdata);
begin
end;}

procedure tmode.ConnectionEstablished;
begin
end;

procedure tmode.Show(effnumber,time:integer);
var q:integer;
begin
 if time=0 then time:=1;
 game.EnterCritSect;
 try
 try
 inc(curorder);
 if wasinit=false then
  modeinit;
 if minimized then
  restore;
 if effnumber=0 then effnumber:=2;
 if windowed then
 begin
  scene.zorder:=100000+curorder;
  if effnumber<>-1 then
   TShowWIndowEffect.Create(self.Scene,time,sweShowModal,effnumber)
 end
 else
 begin
  scene.zorder:=curorder;
  if effnumber<>-1 then
   for q:=1 to nummodes do   // Найти другую сцену, из которой переходим
   begin
    if (modes[q].mode.wasinit)and
       (modes[q].mode.windowed=false)and
       (modes[q].mode.scene.status=ssActive)and
       (modes[q].mode<>self) then begin
     modes[q].mode.onClosing;
     TTransitionEffect.Create(self.Scene,modes[q].mode.scene,time);
     break;
    end;
   end;
 end;
 except
  on e:exception do ForceLogMessage('Error in Mode.Show: '+ExceptionMsg(e));
 end;
 finally
  game.LeaveCritSect;
 end;
end;

procedure tmode.ShowNonModal(effnumber,time:integer);
var q:integer;
begin
 game.EnterCritSect;
 try
 inc(curorder);
 if wasinit=false then
 begin
  modeinit;
 end;
 if effnumber=0 then effnumber:=2;
 if windowed then
 begin
  scene.zorder:=100000+curorder;
  if effnumber<>-1 then
   TShowWIndowEffect.Create(self.Scene,time,sweShow,effnumber)
 end
 else
 begin
  scene.zorder:=curorder;
  if effnumber<>-1 then
   for q:=1 to nummodes do
    if (modes[q].mode.windowed=false)and(modes[q].mode.scene.status=ssActive)and(modes[q].mode<>self) then
   TTransitionEffect.Create(self.Scene,modes[q].mode.scene,time);
 end;
 finally
   game.LeaveCritSect;
 end;
end;


procedure tmode.Hide(effnumber,time:integer);
begin
 game.EnterCritSect;
 try
 if windowed and (effnumber<>-1) then
  TShowWIndowEffect.Create(self.Scene,time,sweHide,effnumber);
 finally
   game.LeaveCritSect;
 end;
end;

procedure tmode.Draw(x,y:integer);
begin
 lastdrawtime:=getcurtime;
 if background<>nil then begin
  if (background.width=screenWidth) and
     (background.height=screenHeight) then
   painter.DrawImage(0,0,background)
  else
   painter.DrawScaled(0,0,screenWidth,screenHeight,background);
 end;
end;

procedure tmode.DrawAfterUI(x,y:integer);
begin
 lastdrawtime:=getcurtime;
end;

procedure CommonLoader(reason:TReason;var image:TImgDescriptor);
begin
end;

procedure CommonDrawer(image:TImgDescriptor;x,y:integer;color:cardinal;p1,p2,p3,p4:single);
var q:integer;
    s,s2,s3:string;
begin
 s:=uppercase(image.FullName);
 for q:=1 to nummodes do
 begin
  s2:=modes[q].mode.name+'\BACKGROUND';
  s3:='IMAGES\'+modes[q].mode.name+'MAIN';
  if (copy(s,1,length(s2))=s2)or(copy(s,1,length(s3))=s3) then
  begin
   if (modes[q].mode.windowed=false)and(modes[q].mode.background<>nil) then
    painter.DrawImage(0,0,modes[q].mode.background,$FF808080);

   if (modes[q].mode.windowed) then
    modes[q].mode.Draw(x,y);
  end;
 end;
end;

function CommonHandler(event:EventStr;tag:integer):boolean;
var q,w:integer;
    s,s2:string;
    x,y:integer;
begin
 result:=false;
 event:=uppercase(event);
// forcelogmessage('Event: '+event);
 for q:=1 to nummodes do if modes[q].mode.wasinit then
 begin
  s:='UI\'+modes[q].mode.name+'\';
  if copy(event,1,length(s))=s then
  try
   s2:=copy(event,length(s),255);
   {if (s2='NETDATA') then
   begin
    w:=GetNetMsg(tag,pointer(pdata));
    modes[q].mode.Network(w,pdata);
   end else
   if (s2='CONNECTIONBROKEN') then
    modes[q].mode.Network(0,nil) else
   if (s2='CONNECTIONESTABLISHED') then
    modes[q].mode.ConnectionEstablished else}
   modes[q].mode.ProcessSignal(event,tag);
  except
   on e:exception do ForceLogMessage('Error in '+modes[q].mode.name+' event '+event+' handling: '+ExceptionMsg(e));
  end;

  with modes[q].mode do
   if (scene<>nil) and (scene.UI<>nil) then begin
    x:=scene.UI.x;
    y:=scene.UI.y;
   end else begin
    x:=0; y:=0;
   end;
  if event='SCENES\'+modes[q].mode.name+'\BEFOREUIRENDER' then
   if not modes[q].mode.windowed then try
     modes[q].mode.Draw(x,y);
   except
    on e:exception do LogMessage('Error in '+modes[q].mode.name+' Draw: '+ExceptionMsg(e));
   end;

  if event='SCENES\'+modes[q].mode.name+'\AFTERUIRENDER' then try
//   if not WindowedMode then
    modes[q].mode.DrawAfterUI(x,y);
  except
   on e:exception do LogMessage('Error in '+modes[q].mode.name+' DrawAfterUI: '+ExceptionMsg(e));
  end;
 end;
end;

procedure tmode.AddScene;
begin
 Scene.mode:=self;
 game.AddScene(Scene);
end;

procedure tmode.FreeMemory;
begin
 if (windowed=false)and(background<>nil) then
  texman.FreeImage(background);
 if (windowed) and (skinnedwnd.background<>nil) then
  texman.FreeImage(TTexture(skinnedwnd.background));
 minimized:=true;
end;

procedure tmode.Restore;
begin
 if windowed=false then
 begin
  try
   background:=CreateImage('IMAGES\'+name+'\BACKGROUND');
  except
   background:=nil;
  end
 end else
 begin
  if baseimagefile<>'' then
  begin
   skinnedWnd.Background:=LoadImageFromFile(baseimagefile);
  end
 end;
 minimized:=false;
end;

procedure TMode.Preload;
begin
 if (windowed=false) and (background=nil) then
  try
   if screenWidth/ScreenHeight>1.5 then
    background:=CreateImage('IMAGES\'+name+'\BACKGROUNDWIDE',false)
   else
    background:=CreateImage('IMAGES\'+name+'\BACKGROUND',false);
  except
   background:=nil;
  end
end;

procedure tmode.ModeInit;
begin
 forcelogmessage('Init '+name);
 wasinit:=true;
 minimized:=false;
 lastdrawtime:=GetCurTime;
 SetEventHandler('UI\'+name+'\',CommonHandler,sync);
 SetEventHandler('SCENES\'+name+'\',CommonHandler,async);

 if windowed=false then
 begin
  Scene:=TInternalScene.Create(name);
  AddScene;
 end else
 begin
  Scene:=TInternalScene.Create(name,false,true);
  AddScene;
  mainwnd:=nil;
  if (baseimagefile<>'') and (baseimagefile<>'empty') then
  begin
   SkinnedWnd:=TUISkinnedWindow.Create(name+'\WND','',MainFont,nil);
   SetupWindow(SkinnedWnd,LoadImageFromFile(baseimagefile));
   mainwnd:=skinnedwnd;
   MainWnd.style:=1;
   MainWnd.color:=$FF808080;
   MainWnd.moveable:=moveable;
  end;
  if baseimagefile='empty' then
  begin
   SkinnedWnd:=TUISkinnedWindow.Create(name+'\WND','',MainFont,nil);
   mainwnd:=skinnedwnd;
   MainWnd.style:=1;
   MainWnd.color:=$FF808080;
   mainwnd.visible:=false;
   MainWnd.moveable:=moveable;
  end;
  scene.ui.Free;
  Scene.UI:=MainWnd;

  if baseimagefile<>'' then begin
   if needcorrectwindow then
    wndImage:=TUIImage.Create(0,0,300,300,Name+'MAIN',Mainwnd)
   else
    wndImage:=TUIImage.Create(5,24,300,300,Name+'MAIN',Mainwnd);
   wndImage.AnchorRight:=true;
   wndImage.AnchorBottom:=true;
   wndImage.transpmode:=tmTransparent;
   SetDrawer('Images\'+name+'main',CommonLoader,CommonDrawer);
  end;
 end;
end;

constructor tmode.Create(modeName:string;preInit:boolean);
begin
 ForceLogMessage(name);
 name:=uppercase(modeName);
 inc(nummodes);
 modes[nummodes].mode:=self;
 modes[nummodes].preinitrequired:=preinit;
 moveable:=true;
 needcorrectwindow:=true; // если окно - то точного размера, без отступов на рамку (а нафиг рамка???)
 preloadOrder:=10;
end;

procedure TMode.LanguageChanged;
begin
end;

procedure TMode.ScreenSizeChanged;
begin
end;

procedure TMode.StatusChanged;
begin
end;

procedure TMode.onClosing;
begin
end;

initialization
 stepsinfo.totalvalue:=0;
 curvalue:=0;
end.
