// Steam integration test (Apus.Engine.SteamAPI).
// Without the steam_api library or a running client (CI) it checks that Steam reports
// itself unavailable and every query answers false. With the library from the SDK
// redistributable_bin next to the exe, steam_appid.txt and the Steam client running
// it prints the user, the language and ownership of the AppIDs given on the command
// line, e.g.: TestSteam 22510 22520 22521 (with 22500 in steam_appid.txt)
{$APPTYPE CONSOLE}
program TestSteam;
uses
  SysUtils,
  Apus.Core,
  Apus.EventMan,
  Apus.Engine.SteamAPI;

{$I ..\Base\tests\Test.inc}

procedure TestUnavailable;
 var
  achieved:boolean;
 begin
  StartTest('Steam unavailable');
  Check(not Steam.available,'not available');
  Check(not (Steam.initResult in [TSteamInitResult.NotInitialized,TSteamInitResult.OK]),'initResult tells why');
  Check(Steam.initError<>'','initError is filled');
  Check(not Steam.IsDlcInstalled(22510),'IsDlcInstalled is false');
  Check(not Steam.IsSubscribedApp(22500),'IsSubscribedApp is false');
  Check(not Steam.GetAchievement('ACH_TEST',achieved) and not achieved,'GetAchievement is false');
  Check(not Steam.SetAchievement('ACH_TEST'),'SetAchievement is false');
  Check(not Steam.StoreStats,'StoreStats is false');
  Check(Steam.userName='','no user name');
  Signal('Engine\Frame\Begin'); // the frame pump must ignore an unavailable Steam
  Steam.Shutdown;
  Check(Steam.initResult=TSteamInitResult.NotInitialized,'Shutdown resets initResult');
  Check(not Steam.Init,'second Init fails too');
  EndTest;
  writeln('  reason: ',ord(Steam.initResult),' (1=OK 2=NoLibrary 3=NoClient 4=ClientOutdated 5=Failed): ',Steam.initError);
 end;

procedure TestAvailable;
 var
  i:integer;
  appID:integer;
 begin
  StartTest('Steam available');
  Check(Steam.initResult=TSteamInitResult.OK,'initResult is OK');
  Check(Steam.userID<>0,'SteamID is known');
  Check(Steam.gameLanguage<>'','game language is known');
  for i:=1 to 10 do Signal('Engine\Frame\Begin'); // dispatch pending callbacks
  EndTest;
  writeln('  user: ',Steam.userName,' (',Steam.userID,'), language: ',Steam.gameLanguage);
  for i:=1 to ParamCount do
   if TryStrToInt(ParamStr(i),appID) then
    writeln('  app ',appID,': subscribed=',Steam.IsSubscribedApp(appID),
      ' dlcInstalled=',Steam.IsDlcInstalled(appID));
  Steam.Shutdown;
 end;

begin
  if Steam.Init then
    TestAvailable
  else
    TestUnavailable;
  writeln;
  if testsFailed=0 then
    writeln('All tests passed ('+IntToStr(testsTotal)+')')
  else begin
    writeln('FAILED: '+IntToStr(testsFailed)+' of '+IntToStr(testsTotal));
    ExitCode:=1;
  end;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
