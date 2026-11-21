// Color swatch, replaceable popup editor and shared recent colors.
// Copyright (C) 2026 Ivan Polyacov, Apus Software. BSD-3, see license.txt.
unit Apus.Engine.UIColorPicker;
interface
 uses Apus.Core, Apus.Lib, Apus.Threads, Apus.Engine.Types, Apus.Engine.UITypes,
  Apus.Engine.UIWidgets;

 const
  COLOR_HISTORY_SIZE=5;

 type
  TUIColorValues=array of cardinal;
  IUIColorHistory=interface
   ['{C83197F6-F19B-4B72-A7DC-C0DD9DF41436}']
   function GetColors:TUIColorValues; // independent snapshot, newest first
   procedure Remember(color:cardinal);
  end;

  TUIColorHistory=class(TInterfacedObject,IUIColorHistory)
   constructor Create;
   destructor Destroy; override;
   function GetColors:TUIColorValues;
   procedure Remember(color:cardinal);
  private
   lock:TLock;
   colors:TUIColorValues;
  end;

  TUIColorButton=class;
  TUIColorPopup=class;
  TUIColorEvent=procedure(sender:TUIColorButton;oldColor,newColor:cardinal) of object;

  // Content contract. The popup owns the editor; SetColor is silent, ChooseColor previews.
  // Custom editors may use child focus and request completion through Accept and Cancel.
  TUIColorEditor=class(TUIElement)
   originalColor:cardinal;
   constructor Create(parent:TUIElement;const name:String8); virtual;
   procedure SetColor(value:cardinal); virtual;
   procedure SetAlphaEnabled(enabled:boolean); virtual;
   procedure ChooseColor(value:cardinal); virtual;
   function CanAccept:boolean; virtual;
   function PreferredSize:TVec2; virtual;
   function InitialFocus:TUIElement; virtual; // nil: the popup keeps focus
   procedure Refresh; virtual;
   procedure Accept;
   procedure Cancel;
  protected
   fColor:cardinal;
   fAlphaEnabled:boolean;
   procedure PublishPreview;
  private
   host:TUIColorPopup;
  public
   property color:cardinal read fColor;
   property alphaEnabled:boolean read fAlphaEnabled write SetAlphaEnabled;
  end;
  TUIColorEditorClass=class of TUIColorEditor;

  TUIColorSwatch=class(TUIButton)
   constructor Create(width,height:single;parent:TUIElement;name:String8='');
   procedure SetColor(value:cardinal); virtual;
  protected
   fColor:cardinal;
  public
   property color:cardinal read fColor write SetColor;
  end;

  // Default mouse-only editor. Override BuildContent/LayoutContent to extend its composition.
  TUIHSVColorEditor=class(TUIColorEditor)
   constructor Create(parent:TUIElement;const name:String8); override;
   procedure AfterConstruction; override;
   procedure Resize(newWidth,newHeight:single); override;
   procedure SetColor(value:cardinal); override;
   procedure SetAlphaEnabled(enabled:boolean); override;
   procedure Refresh; override;
  protected
   hue,saturation,value:single;
   svField,hueField,alphaField:TUIElement;
   colorLabel:TUILabel;
   oldSwatch,newSwatch:TUIColorSwatch;
   procedure BuildContent; virtual;
   procedure LayoutContent; virtual;
   procedure ChooseHSV(h,s,v:single);
   procedure ChooseAlpha(alpha:byte);
  private
   procedure RestoreOriginal;
  end;

  TUIColorPicker=TUIHSVColorEditor; // legacy name for the default content

  // Per-control editor class and history; colors are straight ARGB. All UI operations: window thread.
  TUIColorButton=class(TUIColorSwatch)
   onPreview,onChange,onCancel:TUIColorEvent;
   constructor Create(width,height:single;parent:TUIElement;name:String8='');
   procedure SetColor(value:cardinal); override; // cancels an open session, no onChange
   procedure OpenPicker;
   procedure Accept;
   procedure Cancel;
   function IsOpen:boolean;
  protected
   procedure DoClick; override;
  private
   fPopup:TUIColorPopup;
   fEditorClass:TUIColorEditorClass;
   fHistory:IUIColorHistory;
   fPopupStyle:String8;
   fAlphaEnabled:boolean;
   procedure SetEditorClass(editorClass:TUIColorEditorClass);
   procedure SetHistory(const history:IUIColorHistory);
   procedure SetPopupStyle(const value:String8);
   procedure SetAlphaEnabled(enabled:boolean);
  public
   property editorClass:TUIColorEditorClass read fEditorClass write SetEditorClass;
   property history:IUIColorHistory read fHistory write SetHistory;
   property popupStyle:String8 read fPopupStyle write SetPopupStyle; // '' keeps the theme default
   property alphaEnabled:boolean read fAlphaEnabled write SetAlphaEnabled; // default true
  end;

  // Host is public as a type for ownership; applications normally use TUIColorButton.
  TUIColorPopup=class(TUIPopup)
   constructor Create(owner:TUIColorButton);
   destructor Destroy; override;
   procedure Open;
   procedure onRemoved; override;
   procedure Finish(commit,restoreFocus:boolean);
   procedure onTimer; override;
   function HandleFocusedKey(focused:TUIElement;keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
   function ConsumesSceneButtons:boolean; override;
  protected
   procedure DismissPopup; override;
   procedure OutsidePress(target:TUIElement); override;
  private
   owner:TUIColorButton;
   editor:TUIColorEditor;
   recent:array[0..COLOR_HISTORY_SIZE-1] of TUIColorSwatch;
   okButton,cancelButton:TUIButton;
   opened,ownerHeld:boolean;
   rootSize:TVec2;
   rootScale:single;
   heldAtOpen:array[byte] of boolean;
   procedure PositionFooter(width,top:single);
   procedure RefreshRecent;
   procedure ChooseRecent;
   procedure Preview;
   procedure Accept;
   procedure Cancel;
   procedure MoveFocus(backwards:boolean);
   procedure ForgetOwner;
  end;

 function DefaultColorHistory:IUIColorHistory;

implementation
 uses SysUtils, Math, Apus.Colors, Apus.EventMan, Apus.Geom2D, Apus.Engine.API,
  Apus.Engine.Keys, Apus.Engine.Window, Apus.Engine.UI, Apus.Engine.UIShapes, Apus.Engine.DefaultStyle;

 type
  TColorFieldKind=(cfSV,cfHue,cfAlpha);
  TUIColorField=class(TUIElement)
   picker:TUIHSVColorEditor;
   kind:TColorFieldKind;
   constructor Create(picker:TUIHSVColorEditor;kind:TColorFieldKind;const name:String8);
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onMouseMove; override;
   procedure onLostFocus; override;
   procedure UpdateColor;
  end;

 const
  ALPHA_STRIP_WIDTH=44;
  HSV_EDITOR_WIDTH=288;
  HSV_EDITOR_HEIGHT=220;
  FOOTER_HEIGHT=62;
  FOOTER_BUTTON_WIDTH=72;
  FOOTER_BUTTON_GAP=8;
  RECENT_GAP=6;

 var
  sharedHistory:IUIColorHistory;

 function PickerText(const fallback:String8):String8;
  begin
   if Assigned(Translate) then result:=Translate(fallback)
    else result:=fallback;
  end;

 function Opaque(color:cardinal):cardinal; inline;
  begin
   result:=color or $FF000000;
  end;

 function DefaultColorHistory:IUIColorHistory;
  begin
   result:=sharedHistory;
  end;

 constructor TUIColorHistory.Create;
  begin
   inherited;
   lock.Init('ColorHistory',900);
  end;

 destructor TUIColorHistory.Destroy;
  begin
   lock.Cleanup;
   inherited;
  end;

 function TUIColorHistory.GetColors:TUIColorValues;
  begin
   lock.Enter;
   try result:=Copy(colors);
   finally lock.Leave; end;
  end;

 procedure TUIColorHistory.Remember(color:cardinal);
  var
   i,j,n:integer;
  begin
   lock.Enter;
   try
    n:=length(colors);
    i:=0;
    while (i<n) and (colors[i]<>color) do inc(i);
    if i=n then begin
     if n<COLOR_HISTORY_SIZE then SetLength(colors,n+1);
     i:=Min(n,COLOR_HISTORY_SIZE-1);
    end;
    for j:=i downto 1 do colors[j]:=colors[j-1];
    colors[0]:=color;
   finally lock.Leave; end;
  end;

 procedure DrawCheckerboard(const r:TRect;cell:integer);
  var
   x,y,row,col:integer;
  begin
   cell:=Max(1,cell);
   row:=0; y:=r.top;
   while y<r.bottom do begin
    col:=0; x:=r.left;
    while x<r.right do begin
     if (row+col) and 1<>0 then
      draw.FillRect(x,y,Min(r.right,x+cell)-1,Min(r.bottom,y+cell)-1,$FF909090);
     inc(x,cell); inc(col);
    end;
    inc(y,cell); inc(row);
   end;
  end;

 procedure DrawSwatch(element:TUIElement);
  var
   box,bg:TStyleBox;
   r:TRect;
   inset:integer;
  begin
   ResolveStyleBox(element,box);
   DrawStyleBox(box,[TStyleBoxLayer.Shadow]);
   if TUIColorSwatch(element).color shr 24<>255 then begin
    bg:=box; bg.fill.Init(TFill.Solid($FFD0D0D0)); bg.shade.Init(TFill.None);
    DrawStyleBox(bg,[TStyleBoxLayer.Background]);
    // Leave the rounded edge on the base fill: the checker never escapes its corners.
    r:=box.rect; inset:=Ceil(Max(box.radii.MaxRadius,box.borderWidth));
    inc(r.left,inset); inc(r.top,inset); dec(r.right,inset); dec(r.bottom,inset);
    DrawCheckerboard(r,round(6*element.globalScale));
   end;
   box.fill.Init(TFill.Solid(TUIColorSwatch(element).color));
   box.shade.Init(TFill.None);
   DrawStyleBox(box,[TStyleBoxLayer.Background,TStyleBoxLayer.Border]);
  end;

 procedure DrawPanel(element:TUIElement);
  begin
   DrawElementBox(element);
  end;

 constructor TUIColorSwatch.Create(width,height:single;parent:TUIElement;name:String8);
  begin
   inherited;
   fColor:=$FFFFFFFF;
   flags.canHaveFocus:=false;
   drawer:=@DrawSwatch;
  end;

 procedure TUIColorSwatch.SetColor(value:cardinal);
  begin
   fColor:=value;
  end;

 constructor TUIColorEditor.Create(parent:TUIElement;const name:String8);
  begin
   inherited Create(244,258,parent,name);
   fColor:=$FFFFFFFF;
   fAlphaEnabled:=true;
   originalColor:=fColor;
   shape:=shapeFull;
   drawer:=@DrawPanel;
  end;

 procedure TUIColorEditor.SetColor(value:cardinal);
  begin
   if not fAlphaEnabled then value:=Opaque(value);
   fColor:=value;
   Refresh;
  end;

 procedure TUIColorEditor.SetAlphaEnabled(enabled:boolean);
  begin
   fAlphaEnabled:=enabled;
   if not enabled then begin fColor:=Opaque(fColor); originalColor:=Opaque(originalColor); end;
   Refresh;
  end;

 procedure TUIColorEditor.ChooseColor(value:cardinal);
  begin
   if not fAlphaEnabled then value:=Opaque(value);
   if fColor=value then exit;
   SetColor(value);
   PublishPreview;
  end;

 function TUIColorEditor.CanAccept:boolean;
  begin result:=true; end;
 function TUIColorEditor.PreferredSize:TVec2;
  begin result:=size; end;
 function TUIColorEditor.InitialFocus:TUIElement;
  begin result:=nil; end;
 procedure TUIColorEditor.Refresh;
  begin end;
 procedure TUIColorEditor.PublishPreview;
  begin if host<>nil then host.Preview; end;
 procedure TUIColorEditor.Accept;
  begin if host<>nil then host.Accept; end;
 procedure TUIColorEditor.Cancel;
  begin if host<>nil then host.Cancel; end;

 procedure DrawStripPointers(left,right,y,sc:single);
  var
   side:integer;
   x,dir:single;
  begin
   for side:=0 to 1 do begin
    if side=0 then begin x:=left; dir:=-1; end
     else begin x:=right; dir:=1; end;
    draw.FillTriangle(x,y,x+dir*8*sc,y-6*sc,x+dir*8*sc,y+6*sc,$FF000000,$FF000000,$FF000000);
    draw.FillTriangle(x+dir*2*sc,y,x+dir*7*sc,y-4*sc,x+dir*7*sc,y+4*sc,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF);
   end;
  end;

 procedure DrawColorField(element:TUIElement);
  var
   field:TUIColorField;
   p:TUIHSVColorEditor;
   r:TRect;
   i,x,y,a,b:integer;
   sc:single;
  begin
   field:=TUIColorField(element); p:=field.picker;
   r:=element.GetPosOnScreen; sc:=element.globalScale;
   if field.kind<>cfSV then begin
    inc(r.left,round(8*sc)); dec(r.right,round(8*sc));
    if field.kind=cfHue then begin
     for i:=0 to 5 do begin
      a:=r.top+round(r.Height*i/6); b:=r.top+round(r.Height*(i+1)/6)-1;
      draw.FillGradRect(r.left,a,r.right,b,Apus.Colors.Color.FromHSV(i/6,1,1),Apus.Colors.Color.FromHSV((i+1)/6,1,1),true);
     end;
     y:=r.top+round(p.hue*(r.Height-1));
    end else begin
     draw.FillRect(r.left,r.top,r.right,r.bottom,$FFD0D0D0);
     DrawCheckerboard(r,round(6*sc));
     draw.FillGradRect(r.left,r.top,r.right,r.bottom,Opaque(p.color),p.color and $FFFFFF,true);
     y:=r.top+round((1-(p.color shr 24)/255)*(r.Height-1));
    end;
    DrawStripPointers(r.left,r.right,y,sc);
   end else begin
    draw.FillGradRect(r.left,r.top,r.right,r.bottom,$FFFFFFFF,Apus.Colors.Color.FromHSV(p.hue,1,1),false);
    draw.FillGradRect(r.left,r.top,r.right,r.bottom,$00000000,$FF000000,true);
    x:=r.left+round(p.saturation*(r.Width-1)); y:=r.top+round((1-p.value)*(r.Height-1));
    draw.Rect(x-4*sc,y-4*sc,x+4*sc,y+4*sc,$FF000000);
    draw.Rect(x-3*sc,y-3*sc,x+3*sc,y+3*sc,$FFFFFFFF);
   end;
  end;

 constructor TUIColorField.Create(picker:TUIHSVColorEditor;kind:TColorFieldKind;const name:String8);
  begin
   inherited Create(20,20,picker,name);
   self.picker:=picker; self.kind:=kind;
   flags.canHaveFocus:=false;
   drawer:=@DrawColorField;
  end;

 procedure TUIColorField.UpdateColor;
  var
   p:TVec2;
   h,s,v:single;
  begin
   p:=TransformFromScreen(Vec2(curMouseX,curMouseY));
   h:=picker.hue; s:=picker.saturation; v:=picker.value;
   if kind=cfAlpha then begin
    picker.ChooseAlpha(round(255*(1-Clamp(p.y/Max(1,clientHeight-1/globalScale),0,1))));
    exit;
   end;
   if kind=cfHue then h:=Clamp(p.y/Max(1,clientHeight-1/globalScale),0,1)
   else begin
    s:=Clamp(p.x/Max(1,clientWidth-1/globalScale),0,1);
    v:=1-Clamp(p.y/Max(1,clientHeight-1/globalScale),0,1);
   end;
   picker.ChooseHSV(h,s,v);
  end;

 procedure TUIColorField.onMouseButtons(button:byte;state:boolean);
  begin
   inherited;
   if button<>1 then exit;
   if state then begin
    hooked:=self; // capture without constraining the OS pointer
    UpdateColor;
   end else if hooked=self then hooked:=nil;
  end;

 procedure TUIColorField.onMouseMove;
  begin
   inherited;
   if hooked=self then UpdateColor;
  end;

 procedure TUIColorField.onLostFocus;
  begin
   if hooked=self then hooked:=nil;
   inherited;
  end;

 constructor TUIHSVColorEditor.Create(parent:TUIElement;const name:String8);
  begin
   inherited;
   size:=Vec2(HSV_EDITOR_WIDTH,HSV_EDITOR_HEIGHT);
  end;

 procedure TUIHSVColorEditor.AfterConstruction;
  begin
   BuildContent;
   LayoutContent;
   inherited;
  end;

 procedure TUIHSVColorEditor.BuildContent;
  begin
   svField:=TUIColorField.Create(self,cfSV,name+'\SV');
   hueField:=TUIColorField.Create(self,cfHue,name+'\Hue');
   hueField.hint:=PickerText('Hue');
   alphaField:=TUIColorField.Create(self,cfAlpha,name+'\Alpha');
   alphaField.hint:=PickerText('Alpha: opaque at the top, transparent at the bottom');
   oldSwatch:=TUIColorSwatch.Create(30,24,self,name+'\Original');
   oldSwatch.hint:=PickerText('Original color'); oldSwatch.onClickMethod:=RestoreOriginal;
   newSwatch:=TUIColorSwatch.Create(30,24,self,name+'\Current');
   newSwatch.hint:=PickerText('Current color');
   colorLabel:=TUILabel.Create(200,14,self,name+'\ColorText');
   colorLabel.styleInfo:='color:&text; font-size:7.5';
  end;

 procedure TUIHSVColorEditor.LayoutContent;
  var
   w,h,svWidth:single;
  begin
   if svField=nil then exit;
   w:=clientWidth; h:=clientHeight;
   svWidth:=w-ALPHA_STRIP_WIDTH;
   if alphaEnabled then svWidth:=svWidth-ALPHA_STRIP_WIDTH;
   svField.SetPos(0,8); svField.Resize(svWidth,h-70);
   hueField.SetPos(svWidth+6,8); hueField.Resize(38,h-70);
   alphaField.SetPos(svWidth+50,8); alphaField.Resize(38,h-70);
   alphaField.flags.visible:=alphaEnabled;
   oldSwatch.SetPos(0,h-46); oldSwatch.Resize((w-8)/2,24);
   newSwatch.SetPos((w+8)/2,h-46); newSwatch.Resize((w-8)/2,24);
   colorLabel.SetPos(0,h-16); colorLabel.Resize(w,14);
  end;

 procedure TUIHSVColorEditor.Resize(newWidth,newHeight:single);
  begin
   inherited;
   LayoutContent;
  end;

 procedure TUIHSVColorEditor.SetColor(value:cardinal);
  begin
   Apus.Colors.Color.ToHSV(value,hue,saturation,self.value);
   inherited;
  end;

 procedure TUIHSVColorEditor.SetAlphaEnabled(enabled:boolean);
  begin
   if alphaEnabled=enabled then exit;
   inherited;
   if enabled then Resize(size.x+ALPHA_STRIP_WIDTH,size.y)
    else Resize(Max(80,size.x-ALPHA_STRIP_WIDTH),size.y);
  end;

 procedure TUIHSVColorEditor.ChooseHSV(h,s,v:single);
  var
   c:cardinal;
  begin
   hue:=h; saturation:=s; value:=v;
   c:=(Apus.Colors.Color.FromHSV(h,s,v) and $FFFFFF) or (fColor and $FF000000);
   if c=fColor then exit; // retain float hue/SV, including at black and at the red seam
   fColor:=c;
   Refresh;
   PublishPreview;
  end;

 procedure TUIHSVColorEditor.ChooseAlpha(alpha:byte);
  var c:cardinal;
  begin
   if not alphaEnabled then exit;
   c:=(fColor and $FFFFFF) or (cardinal(alpha) shl 24);
   if c=fColor then exit;
   fColor:=c; Refresh;
   PublishPreview;
  end;

 procedure TUIHSVColorEditor.Refresh;
  begin
   if oldSwatch=nil then exit;
   oldSwatch.color:=originalColor; newSwatch.color:=fColor;
   colorLabel.caption:=Conv.ToStr(fColor shr 24)+','+Conv.ToStr((fColor shr 16) and 255)+','+
    Conv.ToStr((fColor shr 8) and 255)+','+Conv.ToStr(fColor and 255)+' #'+Conv.ToHex(fColor,8);
  end;

 procedure TUIHSVColorEditor.RestoreOriginal;
  begin ChooseColor(originalColor); end;

 constructor TUIColorButton.Create(width,height:single;parent:TUIElement;name:String8);
  begin
   inherited;
   fHistory:=DefaultColorHistory;
   fEditorClass:=TUIHSVColorEditor;
   fAlphaEnabled:=true;
   flags.canHaveFocus:=true;
  end;

 procedure TUIColorButton.SetColor(value:cardinal);
  begin
   Cancel;
   if not fAlphaEnabled then value:=Opaque(value);
   inherited;
  end;

 procedure TUIColorButton.SetAlphaEnabled(enabled:boolean);
  begin
   if fAlphaEnabled=enabled then exit;
   Cancel;
   fAlphaEnabled:=enabled;
   if not enabled then fColor:=Opaque(fColor);
  end;

 procedure TUIColorButton.SetEditorClass(editorClass:TUIColorEditorClass);
  begin
   if editorClass=nil then editorClass:=TUIHSVColorEditor;
   if fEditorClass=editorClass then exit;
   Cancel;
   if fPopup<>nil then begin fPopup.Remove; fPopup:=nil; end;
   fEditorClass:=editorClass;
  end;

 procedure TUIColorButton.SetHistory(const history:IUIColorHistory);
  begin
   Cancel;
   fHistory:=history;
   if fHistory=nil then fHistory:=DefaultColorHistory;
  end;

 procedure TUIColorButton.SetPopupStyle(const value:String8);
  begin
   Cancel;
   if fPopup<>nil then begin fPopup.Remove; fPopup:=nil; end;
   fPopupStyle:=value;
  end;

 function TUIColorButton.IsOpen:boolean;
  begin result:=(fPopup<>nil) and fPopup.opened; end;
 procedure TUIColorButton.Accept;
  begin if IsOpen then fPopup.Accept; end;
 procedure TUIColorButton.Cancel;
  begin if IsOpen then fPopup.Finish(false,true); end;

 procedure TUIColorButton.OpenPicker;
  begin
   if deleted or not IsVisible or not IsEnabled then exit;
   if TUIPopup.TakeAnchorGuard(self) then exit;
   if IsOpen then exit;
   if fPopup=nil then fPopup:=TUIColorPopup.Create(self);
   fPopup.Open;
  end;

 procedure TUIColorButton.DoClick;
  begin
   if TUIPopup.TakeAnchorGuard(self) then exit;
   if IsOpen then Accept else OpenPicker;
  end;

 constructor TUIColorPopup.Create(owner:TUIColorButton);
  var i:integer;
  begin
   inherited Create(0,0,owner,owner.name+'\Picker');
   self.owner:=owner;
   flags.canHaveFocus:=true;
   SetPadding(10);
   drawer:=@DrawPanel;
   if owner.fPopupStyle<>'' then styleInfo:=owner.fPopupStyle;
   editor:=owner.fEditorClass.Create(self,name+'\Editor');
   editor.host:=self;
   for i:=0 to high(recent) do begin
    recent[i]:=TUIColorSwatch.Create(30,22,self,name+'\Recent'+Conv.ToStr(i+1));
    recent[i].onClickMethod:=ChooseRecent;
   end;
   okButton:=TUIButton.Create(FOOTER_BUTTON_WIDTH,26,self,name+'\Accept').Setup(PickerText('OK'));
   okButton.flags.canHaveFocus:=false;
   okButton.onClickMethod:=Accept;
   cancelButton:=TUIButton.Create(FOOTER_BUTTON_WIDTH,26,self,name+'\Cancel').Setup(PickerText('Cancel'));
   cancelButton.flags.canHaveFocus:=false;
   cancelButton.onClickMethod:=Cancel;
  end;

 procedure TUIColorPopup.PositionFooter(width,top:single);
  var
   i:integer;
   swatchWidth:single;
  begin
   swatchWidth:=(width-(COLOR_HISTORY_SIZE-1)*RECENT_GAP)/COLOR_HISTORY_SIZE;
   for i:=0 to high(recent) do begin
    recent[i].SetPos(i*(swatchWidth+RECENT_GAP),top+6);
    recent[i].Resize(swatchWidth,22);
   end;
   okButton.SetPos(width-2*FOOTER_BUTTON_WIDTH-FOOTER_BUTTON_GAP,top+36);
   cancelButton.SetPos(width-FOOTER_BUTTON_WIDTH,top+36);
  end;

 procedure TUIColorPopup.RefreshRecent;
  var
   colors:TUIColorValues;
   i:integer;
  begin
   colors:=owner.fHistory.GetColors;
   for i:=0 to high(recent) do begin
    recent[i].flags.visible:=i<length(colors);
    if i<length(colors) then begin
     recent[i].color:=colors[i];
     if not owner.alphaEnabled then recent[i].color:=Opaque(colors[i]);
     recent[i].hint:='ARGB: $'+Conv.ToHex(recent[i].color,8);
    end;
   end;
  end;

 procedure TUIColorPopup.ChooseRecent;
  begin
   if TUIButton.Sender is TUIColorSwatch then editor.ChooseColor(TUIColorSwatch(TUIButton.Sender).color);
  end;

 procedure TUIColorPopup.ForgetOwner;
  begin
   if owner=nil then exit;
   if owner.fPopup=self then owner.fPopup:=nil;
   if ownerHeld then begin
    ownerHeld:=false;
    owner.Release;
   end;
   owner:=nil;
  end;

 destructor TUIColorPopup.Destroy;
  begin
   ForgetOwner;
   inherited;
  end;

 procedure TUIColorPopup.onRemoved;
  begin
   // Owner and reparented popup can be removed together. Release holds now.
   opened:=false;
   timer:=0;
   ForgetOwner;
   inherited;
  end;

 procedure TUIColorPopup.DismissPopup;
  begin
   Finish(false,true);
  end;

 procedure TUIColorPopup.OutsidePress(target:TUIElement);
  begin
   Finish(not owner.deleted and owner.IsVisible and owner.IsEnabled and editor.CanAccept,true);
  end;

 procedure TUIColorPopup.Open;
  var
   root,f:TUIElement;
   r:TRect2;
   pref:TVec2;
   wnd:TWindow;
   fit,contentWidth:single;
   i,code:integer;
  begin
   if opened then exit;
   root:=owner.GetRoot; wnd:=root.GetWindow;
   if (wnd=nil) or not owner.Acquire then exit;
   ownerHeld:=true;
   if not RegisterPopup(root,owner) then begin
    if ownerHeld then begin
     ownerHeld:=false;
     owner.Release;
    end;
    exit;
   end;
   AttachTo(root);
   editor.alphaEnabled:=owner.alphaEnabled;
   editor.originalColor:=owner.color;
   editor.SetColor(owner.color);
   pref:=editor.PreferredSize;
   contentWidth:=Max(2*FOOTER_BUTTON_WIDTH+FOOTER_BUTTON_GAP,pref.x);
   size:=Vec2(contentWidth+padding.left+padding.right,
     Max(1,pref.y)+FOOTER_HEIGHT+padding.top+padding.bottom);
   PositionFooter(contentWidth,Max(1,pref.y));
   RefreshRecent;
   // Scale the whole composition for tiny roots; positions and input use the same transform.
   fit:=Min(1,Min(root.clientWidth/size.x,root.clientHeight/size.y));
   scale:=Max(0.01,fit); size:=Vec2(size.x*scale,size.y*scale);
   editor.Resize(Max(1,pref.x),Max(1,pref.y));
   r:=owner.TransformTo(owner.GetRect,root);
   PlacePopup(root,r.x1,r.y2,r.y1);
   rootSize:=Vec2(root.clientWidth,root.clientHeight); rootScale:=root.globalScale;
   SavePopupFocus(wnd);
   for i:=0 to 255 do begin
    code:=Scan.FromKey(TKey(i));
    heldAtOpen[i]:=(code>0) and (code<=high(wnd.keyState)) and (wnd.keyState[code] and 1<>0);
   end;
   opened:=true; flags.visible:=true; timer:=50;
   SetFocus;
   f:=editor.InitialFocus;
   if (f<>nil) and ((f=editor) or f.HasParent(editor)) then f.SetFocus;
  end;

 procedure TUIColorPopup.Finish(commit,restoreFocus:boolean);
  var
   oldColor,newColor:cardinal;
   callback:TUIColorEvent;
   history:IUIColorHistory;
   held:boolean;
   button:TUIColorButton;
  begin
   if not opened then exit;
   opened:=false; // before focus changes and application callbacks
   timer:=0; flags.visible:=false;
   oldColor:=editor.originalColor; newColor:=editor.color;
   button:=owner;
   history:=button.fHistory;
   if (hooked<>nil) and ((hooked=self) or hooked.HasParent(self)) then begin
    hooked.onLostFocus; hooked:=nil; clipMouse:=cmNo;
   end;
   if restoreFocus then EndPopup(pfcRestore) else EndPopup(pfcClear);
   callback:=nil;
   if not button.deleted then begin
    if commit then begin
     button.fColor:=newColor;
     if oldColor<>newColor then callback:=button.onChange;
    end else callback:=button.onCancel;
   end;
   held:=ownerHeld; ownerHeld:=false;
   if not button.deleted then AttachTo(button) else Remove;
   try
    if commit and (history<>nil) then history.Remember(newColor);
    if Assigned(callback) then callback(button,oldColor,newColor);
   finally
    if held then button.Release;
   end;
  end;

 procedure TUIColorPopup.Accept;
  begin if opened and editor.CanAccept then Finish(true,true); end;
 procedure TUIColorPopup.Cancel;
  begin Finish(false,true); end;
 procedure TUIColorPopup.Preview;
  begin
   if opened and not owner.deleted and Assigned(owner.onPreview) then
    owner.onPreview(owner,editor.originalColor,editor.color);
  end;

 procedure TUIColorPopup.onTimer;
  var
   f:TUIElement;
   wnd:TWindow;
  begin
   if not opened then exit;
   wnd:=GetWindow;
   if (wnd=nil) or (parent=nil) then begin Finish(false,false); exit; end;
   f:=TUIElement(wnd.focus.element);
   if owner.deleted or not owner.IsVisible or not owner.IsEnabled or
      not IsVisible or (parent.clientWidth<>rootSize.x) or (parent.clientHeight<>rootSize.y) or
      (parent.globalScale<>rootScale) or (f=nil) or ((f<>self) and not f.HasParent(self)) then begin
    Finish(false,false); exit;
   end;
   RefreshRecent;
   timer:=50;
  end;

 procedure TUIColorPopup.MoveFocus(backwards:boolean);
  var
   items:TUIElements;
   i,index:integer;
   f:TUIElement;
   procedure Collect(e:TUIElement);
    var j,n:integer;
    begin
     if not e.IsVisible or not e.IsEnabled then exit;
     if e.flags.canHaveFocus then begin n:=length(items); SetLength(items,n+1); items[n]:=e; end;
     for j:=0 to high(e.children) do Collect(e.children[j]);
    end;
  begin
   items:=nil; Collect(editor);
   if length(items)=0 then begin SetFocus; exit; end;
   f:=TUIElement(GetWindow.focus.element); index:=-1;
   for i:=0 to high(items) do if items[i]=f then index:=i;
   if backwards then begin
    if index<=0 then index:=high(items) else dec(index);
   end else index:=(index+1) mod length(items);
   items[index].SetFocus;
  end;

 function TUIColorPopup.HandleFocusedKey(focused:TUIElement;keycode:byte;pressed:boolean;shiftstate:byte):boolean;
  begin
   if not opened then exit(true);
   // Let the world end a key gesture that started before the popup opened.
   if not pressed and heldAtOpen[keycode] then begin heldAtOpen[keycode]:=false; exit(true); end;
   result:=false;
   if pressed then case TKey(keycode) of
    TKey.Escape:begin Cancel; exit; end;
    TKey.Enter:begin Accept; exit; end;
    TKey.Tab:begin MoveFocus(shiftstate and sscShift<>0); exit; end;
   end;
   if focused<>self then focused.onKey(keycode,pressed,shiftstate);
  end;

 function TUIColorPopup.ConsumesSceneButtons:boolean;
  begin result:=true; end;

initialization
 sharedHistory:=TUIColorHistory.Create;
 TUIColorPopup.SetDefault('styleInfo','fill:&surface-alt; border-color:&border-dark; border-width:1; radius:4; '+
  'color:&text; box-shadow:&shadow 2 3 4');
 TUIColorSwatch.SetDefault('styleInfo','radius:3; border-width:1; border-color:&border-dark; '+
  ':hover { border-color:&accent; } :focused { border-color:&accent; border-width:2; } '+
  ':disabled { border-color:&text-muted; }');
end.
