unit EAGLViewU;

{$modeswitch ObjectiveC1}

interface

uses
  sysUtils,
  types,
  iPhoneAll,
  gles11,
  glext;

type

  TMultiTouchEvent=record
   count:byte;
   points:array[1..4] of TPoint;
  end;

  { EAGLView }

  EAGLView = objcclass(UIView)
    // The pixel dimensions of the CAEAGLLayer.
    framebufferWidth:GLint;
    framebufferHeight:GLint;
    
    // The OpenGL ES names for the framebuffer and renderbuffer used to render to this view.
    defaultFramebuffer, colorRenderbuffer:GLuint;
    context:EAGLContext;
  public
    class function layerClass:Pobjc_class; override;
    function initWithCoder(aDecoder: NSCoder): id; override;
    procedure setFramebuffer; message 'setFramebuffer';
    function presentFramebuffer:boolean; message 'presentFramebuffer';
    procedure setContext(newContext:EAGLContext); message 'setContext:';
    procedure awakeFromNib; override;
  private
    procedure createFramebuffer; message 'createFramebuffer';
    procedure deleteFramebuffer; message 'deleteFramebuffer';

    procedure touchesBegan_withEvent(touches: NSSet; event: UIEvent); override;
    procedure touchesMoved_withEvent(touches: NSSet; event: UIEvent); override;
    procedure touchesEnded_withEvent(touches: NSSet; event: UIEvent); override;
    procedure touchesCancelled_withEvent(touches: NSSet; event: UIEvent); override;
  end;

 EAGLViewController=objcclass(UIViewController)
  function shouldAutorotateToInterfaceOrientation(orientation:UIInterfaceOrientation):boolean; override;
 end;

 var
   retina:boolean=false;
   supportRetina:boolean=false;
   landscapeOnly:boolean=false;

implementation
 uses CGGeometry,EventMan,MyServis;

 var
  curtouch:UITouch;
  mTouch:TMultiTouchEvent;

 class function EAGLView.layerClass:Pobjc_class;
  begin
   NSLog(NSSTR('layerClass'));
   result:=CAEAGLLayer;
  end;

 function EAGLView.initWithCoder(aDecoder: NSCoder): id;
  var
   eaglLayer:CAEAGLLayer;
   scale:single;
  begin
   NSLog(NSSTR('initWithCoder'));
   self:=inherited initWithCoder(aDecoder);
   if self<>nil then begin
    eaglLayer:=CAEAGLLayer(layer);
    eaglLayer.setOpaque(TRUE);
    scale:=UIScreen.MainScreen.scale;
    ForceLogMessage('Scale='+Inttostr(round(scale*1000)));
    if supportRetina and (scale=2.0) then begin
     setContentScaleFactor(2.0);
     retina:=true;
    end;
   end;
   result:=self;
  end;

 function EAGLViewController.shouldAutorotateToInterfaceOrientation(orientation:UIInterfaceOrientation):boolean;
  begin
   if landscapeOnly then
     result:=(orientation in [UIInterfaceOrientationLandscapeLeft,UIInterfaceOrientationLandscapeRight])
   else
     result:=true;
  end;

 procedure EAGLView.createFramebuffer;
  begin
   NSLog(NSSTR('CreateFrameBuffer'));
   if (context<>nil) and (defaultFrameBuffer=0) then begin
    EAGLContext.setCurrentContext(context);
    glGenFramebuffersOES(1,@defaultFramebuffer);
    glBindFramebufferOES(GL_FRAMEBUFFER_OES,defaultFramebuffer);

    glGenRenderbuffersOES(1,@colorRenderbuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES,colorRenderBuffer);
    context.renderbufferStorage_FromDrawable(GL_RENDERBUFFER_OES,CAEAGLLayer(layer));
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES,GL_RENDERBUFFER_WIDTH_OES,framebufferWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES,GL_RENDERBUFFER_HEIGHT_OES,framebufferHeight);
    NSLog(NSSTR(PChar('FB size: '+inttostr(framebufferWidth)+' '+inttostr(framebufferHeight))));

    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, colorRenderbuffer);
    if (glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) <> GL_FRAMEBUFFER_COMPLETE_OES) then
       NSLog(NSSTR('Failed to make complete framebuffer object'));
   end;
  end;

 procedure EAGLView.deleteFramebuffer;
  begin
   if context<>nil then begin
    EAGLContext.setCurrentContext(context);
     if defaultFramebuffer<>0 then begin
      glDeleteFramebuffersOES(1,@defaultFramebuffer);
      defaultFramebuffer:=0;
     end;
     if colorRenderbuffer<>0 then begin
      glDeleteRenderbuffersOES(1,@colorRenderbuffer);
      colorRenderbuffer:=0;
     end;
   end;
  end;

procedure EAGLView.touchesBegan_withEvent(touches: NSSet; event: UIEvent);
 var
   touch:UITouch;
   arr:NSArray;
   point:CGPoint;
   i:integer;
 begin
//  ForceLogMessage(inttostr(touches.count));
  if (touches.count=1) and (curTouch=nil) then begin // Single tap started
   touch:=touches.anyObject;
   curTouch:=touch.retain;
   point:=touch.locationInView(self);
   Signal('Engine\SingleTouchStart',round(point.x)+round(point.y) shl 16);
  end;
  if touches.count>1 then begin
   mTouch.count:=touches.count;
   arr:=touches.allObjects;
   for i:=1 to mTouch.count do begin
    if i>4 then break;
    touch:=arr.objectAtIndex(i-1);
    point:=touch.locationInView(self);
    mTouch.points[i].x:=round(point.x);
    mTouch.points[i].y:=round(point.y);
   end;
   Signal('Engine\MultiTouch',cardinal(@mTouch));
  end;
 end;

procedure EAGLView.touchesMoved_withEvent(touches: NSSet; event: UIEvent);
 var
   touch:UITouch;
   point:CGPoint;
 begin
  if touches.count=1 then begin // Single tap moved
   touch:=touches.anyObject;
   if touch=curTouch then begin
    point:=touch.locationInView(self);
    Signal('Engine\SingleTouchMove',round(point.x)+round(point.y) shl 16);
   end;
  end;
 end;

procedure EAGLView.touchesEnded_withEvent(touches: NSSet; event: UIEvent);
 var
   touch:UITouch;
   point:CGPoint;
   arr:NSArray;
   i:integer;
 begin
//  if touches.count=1 then begin // Single tap ended
//   touch:=touches.anyObject;
   arr:=touches.allObjects;
   for i:=0 to arr.count-1 do begin
    touch:=arr.objectAtIndex(i);
    if touch=curTouch then begin
     point:=touch.locationInView(self);
     Signal('Engine\SingleTouchRelease',round(point.x)+round(point.y) shl 16);
     curTouch.release;
     curTouch:=nil;
    end;
   end;
   //arr.release;
{  end else begin
   curTouch.release;
   curTouch:=nil;
  end;}
 end;

procedure EAGLView.touchesCancelled_withEvent(touches: NSSet; event: UIEvent);
 begin
  curTouch.release;
  curTouch:=nil;
 end;

procedure EAGLView.awakeFromNib;
 begin
  NSLog(NSSTR('AwakeFromNib'));
 end;

 procedure EAGLView.setFramebuffer;
  begin
//   NSLog(NSSTR('setFrameBuffer'));
   if context<>nil then begin
    EAGLContext.setCurrentContext(context);
    if defaultFramebuffer=0 then CreateFramebuffer;
    glBindFramebufferOES(GL_FRAMEBUFFER_OES,defaultFramebuffer);
    glViewport(0,0,framebufferWidth,framebufferHeight);
   end;
  end;

 function EAGLView.presentFramebuffer:boolean;
  begin
   result:=false;
   if context<>nil then begin
    EAGLContext.setCurrentContext(context);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES,colorRenderbuffer);
    result:=context.presentRenderbuffer(GL_RENDERBUFFER_OES);
   end;
  end;

 procedure EAGLView.setContext(newContext: EAGLContext);
  begin
    if context<>newContext then begin
      deleteFramebuffer;
      context.release;
      context:=newContext.retain;
      EAGLContext.setCurrentContext(nil);
    end;
  end;

end.
