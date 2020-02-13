// Android file system - load asset files
// Copyright (C) 2017 Apus Software (www.apus-software.com)
// Author: Ivan Polyacov (ivan@apus-software.com, cooler@tut.by)
unit Android;
{$IFDEF FPC}
{$mode delphi}
{$ENDIF}
interface
 {$IFDEF ANDROID}
  uses jni,MyServis;

 type
  // keyboard types
  TKeyboardType=(ktDefault,
                 ktNumeric,
                 ktURL);

 var
  // Global variables: filled by InitAndroid
  curActivity:jobject=nil;
  mainView:jobject=nil;
  appResources:jobject;  // Resources
  appAssetManager:jobject; // AssetManager

  appCacheDir:string='';
  appDataDir:string='';
  appPackageName:string='';

 threadvar
  appEnv:PJNIEnv; // Thread-local JNI environment

 // MUST be called BEFORE any functions below
 procedure InitAndroid(env:PJNIEnv;activity,view:jobject);

 // MUST be called BEFORE any JNI-related calls from a SECONDARY thread
 procedure AndroidInitThread;
 procedure AndroidDoneThread;

 // Assets management
 function AndroidListDir(dirName:string):StringArr;
 function AndroidFileExists(fname:string):boolean;
 function AndroidLoadFile(fname:string):string;
 function AndroidLoadFile2(fname:string):ByteArray;
 function AndroidOpenFile(fname:string):pointer;
 function AndroidReadFile(f:pointer;var buf;size:integer):integer;
 procedure AndroidCloseFile(f:pointer);

 // Convert Java.String to pascal string (utf8)
 function StringFromJavaString(js:jobject):string;
 function JavaString(st:string):jobject;

 // Aux functions ----
 // Find method ID
 function GetMethodID(className,methodName,methodSign:string):jMethodID;
 // Call object method and handle Java exceptions
 function CallMethod(obj:jobject;className,methodName,methodSign:string;params:array of const):jvalue;

 procedure NewGlobalRef(var obj:jobject); // replace local reference with global one
 procedure FreeGlobalRef(var obj:jobject); // obj:=nil

 // Copy fName from Assets (APK bundle) to AppData folder (if not exist) and return its name
 function CopyAssetFile(fName:string):string;

 // Check if there is a Java exception thrown and raise EWarning if needed
 procedure HandleException(context:string='');

 // Virtual keyboard
 procedure ShowVirtualKeyboard(kTyte:TKeyboardType);
 procedure HideVirtualKeyboard;
 procedure UpdateVirtualKeyboard(view:jobject;selStart,selEnd:integer);

 procedure LogD(text:string);
 procedure LogI(text:string);

 {$ENDIF}
implementation
 {$IFDEF ANDROID}
 uses ctypes,SysUtils;
 {$linklib android}
 type
   PAAssetManager = pointer;
   PAAssetDir = pointer;
   PAAsset = pointer;
   Poff_t = pointer;

 const
   AASSET_MODE_UNKNOWN = 0;
   AASSET_MODE_RANDOM = 1;
   AASSET_MODE_STREAMING = 2;
   AASSET_MODE_BUFFER = 3;

 var
   aMgr:PAAssetManager;

 function AAssetManager_fromJava(env:PJNIEnv;mgr:jobject):pointer; cdecl; external;
 function AAssetManager_openDir(mgr: PAAssetManager; dirName: Pchar): PAAssetDir; cdecl; external;
 function AAssetManager_open(mgr: PAAssetManager; filename: Pchar; mode: cint): PAAsset; cdecl; external;
 function AAssetDir_getNextFileName(assetDir: PAAssetDir): Pchar; cdecl; external;
 procedure AAssetDir_rewind(assetDir: PAAssetDir); cdecl; external;
 procedure AAssetDir_close(assetDir: PAAssetDir); cdecl; external;
 function AAsset_read(asset: PAAsset; buf: Pointer; count: csize_t): cint; cdecl; external;
 function AAsset_seek(asset: PAAsset; offset: coff_t; whence: cint): coff_t; cdecl; external;
 procedure AAsset_close(asset: PAAsset); cdecl; external;
 function AAsset_getBuffer(asset: PAAsset): Pointer; cdecl; external;
 function AAsset_getLength(asset: PAAsset): coff_t; cdecl; external;
 function AAsset_getRemainingLength(asset: PAAsset): coff_t; cdecl; external;
 function AAsset_openFileDescriptor(asset: PAAsset; outStart, outLength: Poff_t): cint; cdecl; external;
 function AAsset_isAllocated(asset: PAAsset): cint; cdecl; external;

 function AndroidLog(prio:longint;tag,text:pchar):longint; cdecl; varargs; external 'liblog.so' name '__android_log_print';

 procedure LogD(text:string);
  begin
   AndroidLog(3,'ApusLib',PChar(text));
  end;

 procedure LogI(text:string);
  begin
   AndroidLog(4,'ApusLib',PChar(text));
  end;


 function GetMethodID(className,methodName,methodSign:string):jMethodID;
  var
   cls:jclass;
  begin
   cls:=appEnv^.FindClass(appEnv,PChar(className));
   if cls=nil then raise EError.Create('Android class not found: '+className);
   result:=appEnv^.GetMethodID(appEnv,cls,PChar(methodName),PChar(methodSign));
   if result=nil then raise EError.Create('Android method not found: '+className+'.'+methodName+':'+methodSign);
  end;

 function CallMethod(obj:jobject;className,methodName,methodSign:string;params:array of const):jvalue;
  var
   i,n:integer;
   args:array[0..15] of jvalue;
   methodID:jMethodID;
   rType:char;
  begin
   methodID:=GetMethodID(className,methodName,methodSign);
   i:=pos(')',methodSign);
   if (i=0) or (i>=length(methodSign)) then
     raise EWarning.Create('Bad method signature: '+methodSign+' for '+className+':'+methodName);
   rType:=UpCase(methodSign[i+1]);
   if length(params)=0 then
    case rType of
     'L':result.l:=appEnv^.CallObjectMethod(appEnv,obj,methodID);
     'Z':result.z:=appEnv^.CallBooleanMethod(appEnv,obj,methodID);
     'B':result.b:=appEnv^.CallByteMethod(appEnv,obj,methodID);
     'C':result.c:=appEnv^.CallCharMethod(appEnv,obj,methodID);
     'S':result.s:=appEnv^.CallShortMethod(appEnv,obj,methodID);
     'I':result.i:=appEnv^.CallIntMethod(appEnv,obj,methodID);
     'F':result.f:=appEnv^.CallFloatMethod(appEnv,obj,methodID);
     'D':result.d:=appEnv^.CallDoubleMethod(appEnv,obj,methodID);
     'V':appEnv^.CallVoidMethod(appEnv,obj,methodID);
    end
   else begin
    n:=0;
    i:=1;
    while i<length(methodSign) do begin
     case methodSign[i] of
      'Z':begin args[n].z:=byte(params[n].VBoolean); inc(n); end;
      'B':begin args[n].b:=params[n].VInteger; inc(n); end;
      'C':begin args[n].c:=params[n].VInteger; inc(n); end;
      'S':begin args[n].s:=params[n].VInteger; inc(n); end;
      'I':begin args[n].i:=params[n].VInteger; inc(n); end;
      'F':begin args[n].f:=params[n].VExtended^; inc(n); end;
      'D':begin args[n].d:=params[n].VExtended^; inc(n); end;
      'L':begin
           if params[n].VType=vtAnsiString then begin
            args[n].l:=JavaString(AnsiString(params[n].VAnsiString));
           end
           else
            args[n].l:=params[n].VPointer;
           inc(n);
           while (i<length(methodSign)) and (methodSign[i]<>';') do inc(i);
         end;
     end;
     inc(i);
     if methodSign[i]=')' then break;
    end;

    case rType of
     'L':result.l:=appEnv^.CallObjectMethodA(appEnv,obj,methodID,@args);
     'Z':result.z:=appEnv^.CallBooleanMethodA(appEnv,obj,methodID,@args);
     'B':result.b:=appEnv^.CallByteMethodA(appEnv,obj,methodID,@args);
     'C':result.c:=appEnv^.CallCharMethodA(appEnv,obj,methodID,@args);
     'S':result.s:=appEnv^.CallShortMethodA(appEnv,obj,methodID,@args);
     'I':result.i:=appEnv^.CallIntMethodA(appEnv,obj,methodID,@args);
     'F':result.f:=appEnv^.CallFloatMethodA(appEnv,obj,methodID,@args);
     'D':result.d:=appEnv^.CallDoubleMethodA(appEnv,obj,methodID,@args);
     'V':appEnv^.CallVoidMethodA(appEnv,obj,methodID,@args);
    end;
   end;
   HandleException(methodName+methodSign);
  end;

 procedure NewGlobalRef(var obj:jObject);
  begin
   obj:=appEnv^.NewGlobalRef(appEnv,obj);
  end;

 procedure FreeGlobalRef(var obj:jobject);
  begin
   if obj=nil then exit;
   appEnv^.DeleteGlobalRef(appEnv,obj);
   obj:=nil;
  end;

 function StringFromJavaString(js:jobject):string;
  var
   len:jsize;
   pc,p:Pjchar;
   isCopy:jboolean;
   ws:WideString;
   i:integer;
  begin
   if js=nil then begin
    result:=''; exit;
   end;
   if appEnv=nil then AndroidInitThread;
   len:=appEnv^.GetStringLength(appEnv,js);
   SetLength(ws,len);
   pc:=appEnv^.GetStringChars(appEnv,js,isCopy);
   p:=pc;
   for i:=1 to len do begin
    ws[i]:=WideChar(pc^);
    inc(pc);
   end;
   appEnv^.ReleaseStringChars(appEnv,js,p);
   result:=EncodeUTF8(ws);
  end;

 function JavaString(st:string):jobject;
  begin
   result:=appEnv^.NewStringUTF(appEnv,PChar(st));
  end;

 procedure InitAndroid(env:PJNIEnv;activity,view:jobject);
  var
   fObj,sObj:jobject;
   args:array[0..3] of jvalue;
  begin
   ForceLogMessage('InitAndroid');
   appEnv:=env;
   curActivity:=appEnv^.NewGlobalRef(appEnv,activity);
   mainView:=appEnv^.NewGlobalRef(appEnv,view);

   if appEnv^.GetJavaVM(appEnv,curVM)<>0 then ForceLogMessage('Failed to get JavaVM');

   // JNI call: Resources resources = activity.getResources()
   appResources:=appEnv^.CallObjectMethod(appEnv,curActivity,
     GetMethodID('android/content/Context','getResources','()Landroid/content/res/Resources;'));
   NewGlobalRef(appResources);

   // JNI call: Assetmanager assetManager = resources.getAssets()
   appAssetManager:=appEnv^.CallObjectMethod(appEnv,appResources,
     GetMethodID('android/content/res/Resources','getAssets','()Landroid/content/res/AssetManager;'));
   NewGlobalRef(appAssetManager);

   // Get native asset manager from Java asset manager
   aMgr:=AAssetManager_fromJava(env,appAssetManager);
   if aMgr=nil then raise EError.Create('Android JNI Asset Manager is nil!');

   // JNI call: File fObj=context.getCacheDir();
   fObj:=appEnv^.CallObjectMethod(appEnv,curActivity,
     GetMethodID('android/content/Context','getCacheDir','()Ljava/io/File;'));

   // JNI call: String sObj=fObj.getCanonicalPath();
   sObj:=appEnv^.CallObjectMethod(appEnv,fObj,
     GetMethodID('java/io/File','getCanonicalPath','()Ljava/lang/String;'));

   appCacheDir:=StringFromJavaString(sObj);
   LogMessage('AppCacheDir: '+appCacheDir);

   // JNI call: File fObj=context.getDir('Data');
   args[0].l:=JavaString('Data');
   args[1].i:=0;
   fObj:=appEnv^.CallObjectMethodA(appEnv,curActivity,
     GetMethodID('android/content/Context','getDir','(Ljava/lang/String;I)Ljava/io/File;'),@args);

   // JNI call: String sObj=fObj.getCanonicalPath();
   sObj:=appEnv^.CallObjectMethod(appEnv,fObj,
     GetMethodID('java/io/File','getCanonicalPath','()Ljava/lang/String;'));

   appDataDir:=StringFromJavaString(sObj);
   LogMessage('AppDataDir: '+appDataDir);

   // JNI call: String sObj=context.getPackageName();
   sObj:=appEnv^.CallObjectMethod(appEnv,curActivity,
     GetMethodID('android/content/Context','getPackageName','()Ljava/lang/String;'));
   appPackageName:=StringFromJavaString(sObj);
   LogMessage('AppPackage: '+appPackageName);

   DebugMessage('InitAndroid done!');
  end;

 function AndroidListDir(dirName:string):StringArr;
  var
   dir:pointer;
   pc:PChar;
  begin
   SetLength(result,0);
   dir:=AAssetManager_openDir(aMgr,PChar(dirName));
   if dir=nil then exit;
   pc:=AAssetDir_getNextFileName(dir);
   while pc<>nil do begin
    AddString(result,pc);
    pc:=AAssetDir_getNextFileName(dir);
   end;
   AAssetDir_close(dir);
  end;

 function AndroidFileExists(fname:string):boolean;
  var
   asset:PAAsset;
  begin
   result:=false;
   asset:=AAssetManager_open(aMgr,PChar(fname),AASSET_MODE_RANDOM);
   if asset=nil then exit;
   result:=true;
   AAsset_close(asset);
  end;

 function AndroidLoadFile2(fname:string):ByteArray;
  var
   st:string;
  begin
   SetLength(result,0);
   st:=AndroidLoadFile(fname);
   if st<>'' then begin
    SetLength(result,length(st));
    move(st[1],result[0],length(st));
   end;
  end;

 function AndroidLoadFile(fname:string):string;
 var
  asset:PAAsset;
  size:integer;
  i:integer;
 begin
  ASSERT(length(fname)>0);
  SetLength(result,0);
  asset:=AAssetManager_open(aMgr,PChar(fname),AASSET_MODE_BUFFER);
  if asset=nil then begin
   // try change case
   i:=LastDelimiter('/',fname)+1;
   if (i>1) and (i<length(fname)) then begin
    if fname[i] in ['A'..'Z'] then fname[i]:=sysutils.LowerCase(fname[i])[1]
     else fname[i]:=UpperCase(fname[i])[1];
    LogMessage('Trying '+fname);
    asset:=AAssetManager_open(aMgr,PChar(fname),AASSET_MODE_BUFFER);
    if asset=nil then exit;
   end else
    exit;
  end;
  size:=AAsset_getLength(asset);
  if size>0 then begin
   SetLength(result,size);
   AAsset_read(asset,@result[1],size);
  end;
  AAsset_close(asset);
  end;

 function AndroidOpenFile(fname:string):pointer;
  begin

  end;

 function AndroidReadFile(f:pointer;var buf;size:integer):integer;
  begin

  end;

 procedure AndroidCloseFile(f:pointer);
  begin

  end;

 procedure AndroidInitThread;
  begin
   if curVM^.AttachCurrentThread(curVM,@appEnv,nil)<>JNI_OK then
    ForceLogMessage('ERROR! Failed to attach thread!');
   LogMessage('New Android thread registered');
  end;

 procedure AndroidDoneThread;
  begin
   if appEnv<>nil then begin
    curVM^.DetachCurrentThread(curVM);
    appEnv:=nil;
   end;
  end;

 function CopyAssetFile(fName:string):string;
  var
   dir,newName:string;
   data:ByteArray;
  begin
   newname:=appDataDir+'/'+fName;
   result:=newName;
   if FileExists(newName) then exit;
   try
    LogMessage('Copying asset file '+fName+' to '+newName);
    data:=AndroidLoadFile2(fname);
    dir:=ExtractFileDir(newName);
    if not DirectoryExists(dir) then CreateDir(dir);
    SaveFile(newName,@data[0],length(data));
   except
    on e:exception do ForceLogMessage('Failed to copy file: '+fname);
   end;
  end;

 procedure HandleException(context:string='');
  var
   e:jthrowable;
   s:jobject;
  begin
   e:=appEnv^.ExceptionOccurred(appEnv);
   if e<>nil then begin
    appEnv^.ExceptionClear(appEnv);
    s:=appEnv^.CallObjectMethod(appEnv,e,GetMethodID('java/lang/Throwable','toString','()Ljava/lang/String;'));
    raise EWarning.Create('JAVA exception: '+StringFromJavaString(s)+' context: '+context);
   end;
  end;

 procedure ShowVirtualKeyboard(kTyte:TKeyboardType);
  var
   imm:jobject;
  begin
   LogMessage('Show virtual keyboard');
   imm:=CallMethod(curActivity,'android/content/Context',
    'getSystemService','(Ljava/lang/String;)Ljava/lang/Object;',[JavaString('input_method')]).l;
   CallMethod(imm,'android/view/inputmethod/InputMethodManager','toggleSoftInput',
    '(II)V',[2,0]);
  end;

 procedure HideVirtualKeyboard;
  var
   imm:jobject;
  begin
   LogMessage('Hide virtual keyboard');
   imm:=CallMethod(curActivity,'android/content/Context',
    'getSystemService','(Ljava/lang/String;)Ljava/lang/Object;',[JavaString('input_method')]).l;
   CallMethod(imm,'android/view/inputmethod/InputMethodManager','toggleSoftInput',
    '(II)V',[0,0]);
  end;

 procedure UpdateVirtualKeyboard(view:jobject;selStart,selEnd:integer);
  var
   imm:jobject;
  begin
   DebugMessage(Format('Update virtual keyboard: %d..%d',[selStart,selEnd]));
   imm:=CallMethod(curActivity,'android/content/Context',
    'getSystemService','(Ljava/lang/String;)Ljava/lang/Object;',[JavaString('input_method')]).l;
   CallMethod(imm,'android/view/inputmethod/InputMethodManager','updateSelection',
    '(Landroid/view/View;IIII)V',[view,selStart,selEnd,0,0]);
  end;

 {$ENDIF}
end.

