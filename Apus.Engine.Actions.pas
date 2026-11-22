// UI actions: a command with its state (caption, shortcut, enabled, checked) shared by
// menu lines, buttons and keys. An action belongs to a scene (TGameScene.AddAction): the
// scene matches its shortcuts and refreshes the state of all its actions in one place
// (TGameScene.UpdateActions). Guide: manual/ui_actions.md
//
// Threads: change the state of an action as any UI state - in the window thread or under
// its lock (TWindow.LockState). The engine calls (UpdateActions, onUpdate, the handlers run by
// keys, menu lines and clicks) already are; an async click handler locks the window itself.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (https://github.com/Cooler2/ApusGameEngine)
unit Apus.Engine.Actions;
interface
uses Apus.Core, Apus.Engine.Keys;

type
 {$SCOPEDENUMS ON}
 // How a menu line shows the checked state of its action
 TActionMark=(None,Check,Radio);
 {$SCOPEDENUMS OFF}

 TUIAction=class;

 // An element that follows an action (the VCL TActionLink pattern): the action calls Changed
 // after any change of its state, the element copies what it shows. The element owns its
 // link and frees it when removed (onRemoved), not in its destructor: elements are freed
 // later than the actions of their scene
 TActionLink=class
  action:TUIAction; // nil - detached (the action is freed)
  constructor Create(action:TUIAction); // joins the links of the action
  destructor Destroy; override;         // leaves them
  procedure Changed; virtual; abstract;
 end;

 TActionShortcut=record
  key:TKey;
  shift:byte; // sscXxx bits: exactly these modifiers
 end;
 TActionShortcuts=array of TActionShortcut;

 TUIAction=class
 private
  fId,fCaption,fHint,fShortcuts:String8;
  fEnabled,fChecked:boolean;
  fMark:TActionMark;
  fKeys:TActionShortcuts;
  fProc:TProcedure;
  fMethod:TObjProcedure;
  fLinks:array of TActionLink;
  procedure SetCaption(const value:String8);
  procedure SetHint(const value:String8);
  procedure SetShortcuts(const value:String8);
  procedure SetEnabled(value:boolean);
  procedure SetChecked(value:boolean);
  procedure SetMark(value:TActionMark);
  procedure Changed;
  procedure AddLink(link:TActionLink);
  procedure RemoveLink(link:TActionLink);
 public
  tag:integer; // free for the app, as TUIElement.tag
  // Set by the owner scene: refreshes the state of its actions (TGameScene.UpdateActions)
  updater:TObjProcedure;
  // Optional: refresh this action, called after the updater
  onUpdate:TObjProcedure;
  // The action whose handler runs now in this thread (window), nil outside: lets one handler
  // serve several actions
  class threadvar executing:TUIAction;

  // shortcuts: 'Ctrl+Z', several - 'Ctrl+Y, Ctrl+Shift+Z' (see ParseShortcut)
  constructor Create(const id,caption:String8;const shortcuts:String8='');
  destructor Destroy; override; // by the owner only, after its UI; detaches the links left
  // The only entry point (keys, menu lines, buttons, app code): refreshes the state (Update),
  // then if enabled runs the handler, refreshes again and returns true; disabled - false
  function Execute:boolean;
  // Refresh the state: the updater of the owner, then onUpdate
  procedure Update;
  // The first shortcut as written: 'Ctrl+Y'; '' - none
  function ShortcutText:String8;
  // One of the shortcuts, the modifiers exactly (ShiftMatches: either Ctrl key is Ctrl)
  function Matches(key:TKey;shift:byte):boolean;
  procedure SetHandler(handler:TProcedure); overload;
  procedure SetHandler(handler:TObjProcedure); overload;
  // nil - no handler; a non-nil pointer is a plain procedure (never @obj.Method: it loses self)
  procedure SetHandler(handler:pointer); overload;
  function HasHandler:boolean;

  property id:String8 read fId;                                  // stable, not translated: 'edit.undo'
  property caption:String8 read fCaption write SetCaption;       // with the mnemonic: '&Undo'
  property hint:String8 read fHint write SetHint;                // short: tooltip and status line
  property shortcuts:String8 read fShortcuts write SetShortcuts; // 'Ctrl+Y, Ctrl+Shift+Z'
  property enabled:boolean read fEnabled write SetEnabled;       // true by default
  property checked:boolean read fChecked write SetChecked;       // set by the app, Execute doesn't flip it
  property mark:TActionMark read fMark write SetMark;            // how a menu line shows checked
  property keys:TActionShortcuts read fKeys;              // parsed shortcuts
 end;

// One shortcut: modifiers Ctrl, Shift, Alt, Win (any case) and a key by TKey.FromName:
// 'Ctrl+Shift+Z', 'F1', 'Ctrl+=', 'Ctrl+NumAdd'. The comma key is 'Comma' (a comma separates
// shortcuts); there is no '+' key on the US layout: 'Ctrl+Shift+=' or 'Ctrl+NumAdd'
function ParseShortcut(const text:String8;out key:TKey;out shift:byte):boolean;
// A list separated by commas; false - some shortcut is wrong (the right ones are returned)
function ParseShortcuts(const text:String8;out list:TActionShortcuts):boolean;

// Caption text without the '&' marks: '&&' is the sign itself, the first single '&' marks
// the mnemonic (pos, len - its bytes in the result, len=0 - none), a trailing '&' is dropped
function MenuCaptionText(const caption:String8;out pos,len:integer):String8; overload;
function MenuCaptionText(const caption:String8):String8; overload;

implementation
uses SysUtils, Apus.Log, Apus.Threads;

var
 // The links of all actions: an element may get its action in any thread (a page built by
 // an async click handler) while the window thread refreshes the state. Entered under a window
 // lock (20); the elements copy the state inside it, so TActionLink.Changed must not enter
 // locks of levels up to 25 (but the window lock already held)
 linkLock:TLock;

const
 // the sscXxx bits of Apus.Engine.API
 MOD_SHIFT=1;
 MOD_CTRL=2;
 MOD_ALT=4;
 MOD_WIN=8;

// Position of a byte in a string, 0 - none (Pos on a String8 converts it in Delphi)
function CharPos(c:AnsiChar;const s:String8):integer;
 var
  i:integer;
 begin
  for i:=1 to length(s) do
   if s[i]=c then exit(i);
  result:=0;
 end;

function ParseShortcut(const text:String8;out key:TKey;out shift:byte):boolean;
 var
  st,part:string;
  p:integer;
 begin
  key:=TKey.None;
  shift:=0;
  st:=Trim(string(text));
  result:=false;
  if st='' then exit;
  // modifiers are the parts before the last '+'; a part may not be empty
  repeat
   p:=Pos('+',st);
   if (p<=1) or (p=length(st)) then break;
   part:=UpperCase(Trim(Copy(st,1,p-1)));
   if (part='CTRL') or (part='CONTROL') then shift:=shift or MOD_CTRL
   else if part='SHIFT' then shift:=shift or MOD_SHIFT
   else if part='ALT' then shift:=shift or MOD_ALT
   else if part='WIN' then shift:=shift or MOD_WIN
   else exit;
   st:=Trim(Copy(st,p+1,length(st)));
  until false;
  key:=TKey.FromName(st);
  result:=key<>TKey.None;
 end;

function ParseShortcuts(const text:String8;out list:TActionShortcuts):boolean;
 var
  st,part:String8;
  p,n:integer;
  key:TKey;
  shift:byte;
 begin
  result:=true;
  list:=nil;
  st:=text;
  n:=0;
  while st<>'' do begin
   p:=CharPos(',',st);
   if p=0 then p:=length(st)+1;
   part:=Copy(st,1,p-1);
   Delete(st,1,p);
   if Trim(string(part))='' then continue;
   if ParseShortcut(part,key,shift) then begin
    SetLength(list,n+1);
    list[n].key:=key;
    list[n].shift:=shift;
    inc(n);
   end else
    result:=false;
  end;
 end;

function Utf8CharLen(c:AnsiChar):integer;
 begin
  case byte(c) of
   $C0..$DF:result:=2;
   $E0..$EF:result:=3;
   $F0..$F7:result:=4;
  else
   result:=1;
  end;
 end;

function MenuCaptionText(const caption:String8;out pos,len:integer):String8;
 var
  i,n,l:integer;
 begin
  pos:=0; len:=0;
  SetLength(result,length(caption));
  n:=0; i:=1;
  while i<=length(caption) do begin
   if caption[i]='&' then begin
    inc(i);
    if i>length(caption) then break; // a trailing mark is dropped
    if (caption[i]<>'&') and (len=0) then begin // the first mark is the mnemonic
     l:=Min(Utf8CharLen(caption[i]),length(caption)-i+1);
     pos:=n+1; len:=l;
     System.Move(caption[i],result[n+1],l);
     inc(n,l); inc(i,l);
     continue;
    end;
    // '&&' - the sign itself; a further mark - just its character
   end;
   inc(n);
   result[n]:=caption[i];
   inc(i);
  end;
  SetLength(result,n);
 end;

function MenuCaptionText(const caption:String8):String8;
 var
  pos,len:integer;
 begin
  result:=MenuCaptionText(caption,pos,len);
 end;

{ TActionLink }

constructor TActionLink.Create(action:TUIAction);
 begin
  self.action:=action;
  if action<>nil then action.AddLink(self);
 end;

destructor TActionLink.Destroy;
 begin
  linkLock.Enter; // the action may be freed in another thread meanwhile
  try
   if action<>nil then action.RemoveLink(self);
  finally
   linkLock.Leave;
  end;
  inherited;
 end;

{ TUIAction }

constructor TUIAction.Create(const id,caption:String8;const shortcuts:String8);
 begin
  fId:=id;
  fCaption:=caption;
  fEnabled:=true;
  SetShortcuts(shortcuts);
 end;

destructor TUIAction.Destroy;
 var
  i:integer;
 begin
  // a link left by an element that has not freed it yet: it must not touch this action
  linkLock.Enter;
  try
   for i:=0 to high(fLinks) do fLinks[i].action:=nil;
   fLinks:=nil;
  finally
   linkLock.Leave;
  end;
  inherited;
 end;

procedure TUIAction.Update;
 begin
  if Assigned(updater) then updater;
  if Assigned(onUpdate) then onUpdate;
 end;

function TUIAction.Execute:boolean;
 var
  prev:TUIAction;
 begin
  Update;
  result:=fEnabled;
  if not result then exit;
  prev:=executing;
  executing:=self;
  try
   if Assigned(fMethod) then fMethod
   else if Assigned(fProc) then fProc;
  finally
   executing:=prev;
  end;
  Update; // the elements show the state after the command at once
 end;

function TUIAction.ShortcutText:String8;
 var
  p:integer;
 begin
  result:=fShortcuts;
  p:=CharPos(',',result);
  if p>0 then SetLength(result,p-1);
  result:=String8(Trim(string(result)));
 end;

function TUIAction.Matches(key:TKey;shift:byte):boolean;
 var
  i:integer;
 begin
  for i:=0 to high(fKeys) do
   if (fKeys[i].key=key) and ShiftMatches(fKeys[i].shift,shift) then exit(true);
  result:=false;
 end;

procedure TUIAction.SetHandler(handler:TProcedure);
 begin
  fProc:=handler;
  fMethod:=nil;
 end;

procedure TUIAction.SetHandler(handler:TObjProcedure);
 begin
  fMethod:=handler;
  fProc:=nil;
 end;

procedure TUIAction.SetHandler(handler:pointer);
 begin
  fMethod:=nil;
  fProc:=TProcedure(handler);
 end;

function TUIAction.HasHandler:boolean;
 begin
  result:=Assigned(fMethod) or Assigned(fProc);
 end;

procedure TUIAction.SetCaption(const value:String8);
 begin
  if value=fCaption then exit;
  fCaption:=value;
  Changed;
 end;

procedure TUIAction.SetHint(const value:String8);
 begin
  if value=fHint then exit;
  fHint:=value;
  Changed;
 end;

procedure TUIAction.SetShortcuts(const value:String8);
 begin
  if not ParseShortcuts(value,fKeys) then begin
   Log.Error('Action %s: wrong shortcut in "%s"',[fId,value]);
   ASSERT(false,'Action '+fId+': wrong shortcut in "'+value+'"');
  end;
  if value=fShortcuts then exit;
  fShortcuts:=value;
  Changed;
 end;

procedure TUIAction.SetEnabled(value:boolean);
 begin
  if value=fEnabled then exit;
  fEnabled:=value;
  Changed;
 end;

procedure TUIAction.SetChecked(value:boolean);
 begin
  if value=fChecked then exit;
  fChecked:=value;
  Changed;
 end;

procedure TUIAction.SetMark(value:TActionMark);
 begin
  if value=fMark then exit;
  fMark:=value;
  Changed;
 end;

procedure TUIAction.Changed;
 var
  i:integer;
 begin
  linkLock.Enter;
  try
   for i:=high(fLinks) downto 0 do
    if i<=high(fLinks) then fLinks[i].Changed; // a link may leave the list in Changed
  finally
   linkLock.Leave;
  end;
 end;

procedure TUIAction.AddLink(link:TActionLink);
 var
  n:integer;
 begin
  linkLock.Enter;
  try
   n:=length(fLinks);
   SetLength(fLinks,n+1);
   fLinks[n]:=link;
  finally
   linkLock.Leave;
  end;
 end;

procedure TUIAction.RemoveLink(link:TActionLink);
 var
  i:integer;
 begin
  linkLock.Enter;
  try
   for i:=0 to high(fLinks) do
    if fLinks[i]=link then begin
     fLinks[i]:=fLinks[high(fLinks)];
     SetLength(fLinks,length(fLinks)-1);
     exit;
    end;
  finally
   linkLock.Leave;
  end;
 end;

initialization
 linkLock.Init('UIActions',25);
end.
