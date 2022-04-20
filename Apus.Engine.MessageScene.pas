unit Apus.Engine.MessageScene;
interface
 uses Apus.MyServis;

 var
  msgMainFont:cardinal; // regular font for text and buttons (0 - use inherited or default)
  msgTitleFont:cardinal; // large font for message title (0 - use inherited or default)

 procedure InitMessageScene;
 // mes format: [Title]<CRLF>line1<CRLF>line2...lineN
 // String separator: CRLF or '~'
 procedure ShowMessage(mes:String8;OkEvent:String8='';x:integer=0;y:integer=0);
 procedure Ask(mes,YesEvent,NoEvent:String8;x:integer=0;y:integer=0);
 procedure Confirm(mes,OkEvent,CancelEvent:String8;x:integer=0;y:integer=0);

implementation
 uses Apus.CrossPlatform, SysUtils, Apus.EventMan, Apus.Structs,
   Apus.Engine.API, Apus.Engine.UIRender, Apus.Engine.UITypes, Apus.Engine.UI, Apus.Engine.UIScene,
   Apus.Engine.SceneEffects;

 const
  MODE_MSG = 1;
  MODE_ASK = 2;
  MODE_CONFIRM = 3;

 type
  TMessageScene=class(TUIScene)
   wnd:TUIElement;
   btnOk,btnYes,btnNo:TUIButton;
   title:string;
   lines:StringArr;
   constructor Create;
   procedure Initialize;
   procedure UpdateUI(msgText:string;mode,x,y:integer);
   procedure Render; override;
  end;

  TQueuedMessage=class
   mType:integer;
   msg,event1,event2:String8;
   x,y:integer;
  end;

 var
  scene:TMessageScene;
  queue:TObjectQueue;
  curMsg:TQueuedMessage;

 procedure InitMessageScene;
  begin
   queue.Init(16);
   scene:=TMessageScene.Create;
   scene.Initialize;
  end;

 procedure QueueMsg(msg,e1,e2:String8;mType,x,y:integer);
  var
   obj:TQueuedMessage;
  begin
   obj:=TQueuedMessage.Create;
   obj.mType:=mType;
   obj.msg:=msg;
   obj.event1:=e1;
   obj.event2:=e2;
   obj.x:=x;
   obj.y:=y;
   queue.Add(obj);
  end;

 // Проверить наличие в очереди сообщения и если оно есть - показать окошко
 procedure CheckQueue;
  begin
   if scene.IsActive then exit;
   if curMsg<>nil then curMsg.Free;
   curMsg:=TQueuedMessage(queue.Get);
   if curMsg=nil then exit;
   // Подготовить UI
   with curMsg do
    scene.UpdateUI(DecodeUTF8(msg),mType,x,y);
   // Показать
   LogMessage('ShowMessage: '+curMsg.msg);
   TShowWindowEffect.Create(scene,200,sweShow,2);
  end;

 procedure ShowMessage(mes:String8;OkEvent:String8='';x:integer=0;y:integer=0);
  begin
   QueueMsg(mes,okEvent,'',MODE_MSG,x,y);
   CheckQueue;
  end;

 procedure Ask(mes,YesEvent,NoEvent:String8;x:integer=0;y:integer=0);
  begin
   QueueMsg(mes,YesEvent,NoEvent,MODE_ASK,x,y);
   CheckQueue;
  end;

 procedure Confirm(mes,OkEvent,CancelEvent:String8;x:integer=0;y:integer=0);
  begin
   QueueMsg(mes,OkEvent,CancelEvent,MODE_CONFIRM,x,y);
   CheckQueue;
  end;

 // UI\Message
 // Scene\MessageScene
 procedure EventHandler(event:TEventStr;tag:TTag);
  var
   close:boolean;
  begin
   if SameText('UI\Message\Next',event) then begin
    CheckQueue;
    exit;
   end;

   close:=false;
   if (SameText(event,'Scene\MessageScene\KEYDOWN') and (tag and $FF=VK_RETURN)) or
      (SameText(event,'UI\Message\OK\Click') or
       SameText(event,'UI\Message\YES\Click')) then begin
    if curMsg.event1<>'' then Signal(curMsg.event1);
    close:=true;
   end;

   if (SameText(event,'Scene\MessageScene\KEYDOWN') and (tag and $FF=VK_ESCAPE)) or
      SameText(event,'UI\Message\NO\Click') then begin
    if curMsg.event2<>'' then Signal(curMsg.event2);
    close:=true;
   end;

   if close then begin
    TShowWindowEffect.Create(scene,150,sweHide,2);
    DelayedSignal('UI\Message\Next',200);
   end;
  end;

{ TMessageScene }

constructor TMessageScene.Create;
 begin
  inherited Create('MessageScene',false);
  zOrder:=100;
  SetEventHandler('UI\Message',EventHandler,emQueued);
  SetEventHandler('Scene\MessageScene',EventHandler,emMixed);
 end;

procedure TMessageScene.Initialize;
 begin
  wnd:=TUIElement.Create(400,200,ui,'Message\Wnd');
  wnd.SetPos(game.renderWidth/2,game.renderHeight/2,pivotCenter);
  wnd.shape:=shapeFull;
  wnd.manualDraw:=true;
  wnd.styleInfo:='FFD0D8E0 C0C0C8D0';
  wnd.font:=msgMainFont;

  btnOk:=TUIButton.Create(90,35,'Message\OK','Ok',0,wnd);
  btnOk.SetPos(200,165,pivotCenter).SetAnchors(0.5,1,0.5,1);

  btnYes:=TUIButton.Create(90,35,'Message\YES','Yes',0,wnd);
  btnYes.SetPos(200-70,165,pivotCenter).SetAnchors(0.5,1,0.5,1);

  btnNo:=TUIButton.Create(90,35,'Message\NO','No',0,wnd);
  btnNo.SetPos(200+70,165,pivotCenter).SetAnchors(0.5,1,0.5,1);
 end;

// Update scene with new text and buttons
procedure TMessageScene.UpdateUI(msgText:string;mode,x,y:integer);
 var
  i,width,height,w,btnY:integer;
 begin
  msgText:=StringReplace(msgtext,'~',#13,[rfReplaceAll]);
  msgText:=StringReplace(msgtext,#10,'',[rfReplaceAll]);
  lines:=split(#13,msgText,#0);
  if (length(lines)>0) and lines[0].StartsWith('[') and lines[0].EndsWith(']') then begin
   title:=lines[0];
   title:=copy(title,2,length(title)-2);
   RemoveString(lines,0);
  end else
   title:='';

  width:=round(300*windowScale);
  if title<>'' then width:=Max2(width,txt.WidthW(msgTitleFont,title));
  for i:=0 to high(lines) do
   width:=max2(width,txt.WidthW(msgMainFont,lines[i]));

  inc(width,round(100*windowScale));
  height:=round((120+30*length(lines)+40*byte(title<>''))*windowScale);

  wnd.Resize(width,height);
  wnd.font:=msgMainFont;

  btnOk.visible:=(mode=MODE_MSG);
  btnYes.visible:=(mode in [MODE_ASK,MODE_CONFIRM]);
  btnNo.visible:=(mode in [MODE_ASK,MODE_CONFIRM]);

  if mode=MODE_ASK then begin
   btnYes.caption:='Yes';
   btnNo.caption:='No';
  end;
  if mode=MODE_CONFIRM then begin
   btnYes.caption:='Ok';
   btnNo.caption:='Cancel';
  end;

  if (x>0) or (y>0) then begin
   wnd.position.x:=x;
   wnd.position.y:=y;
  end else
   wnd.Center;
 end;

procedure TMessageScene.Render;
 var
  r:TRect;
  i,x,y:integer;
 begin
  // Draw background
  r:=wnd.GetPosOnScreen;
  DrawManualUI(wnd);

  // Draw content
  x:=r.CenterPoint.X;
  y:=r.Top+round(40*windowScale);
  if title<>'' then begin
   txt.WriteW(msgTitleFont,x,y,$FF402000,title,taCenter);
   inc(y,round(40*windowScale));
  end else
   inc(y,round(8*windowScale));

  for i:=0 to high(lines) do begin
   txt.WriteW(msgMainFont,x,y,$FF202020,lines[i],taCenter);
   inc(y,round(30*windowScale));
  end;
  // Buttons and child elements
  inherited;
 end;

end.
