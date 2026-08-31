{$APPTYPE CONSOLE}
program TestTemplate;
// Template for new test projects
// 1. Copy this file to TestYourModule.dpr
// 2. Add necessary units to uses clause
// 3. Replace stub tests with real tests
// 4. Run: test.bat YourModule
uses
  SysUtils,
  Apus.Core;
  // add your modules here

{$INCLUDE Test.inc}

// Example test procedure
procedure TestBasicFunctionality;
begin
  StartTest('Basic functionality');

  // Add your checks here
  Check(true,'Stub test - replace with real tests');

  EndTest;
end;

// Add more test procedures here

begin
  try
    writeln('Testing [YourModule] module');
    writeln;

    // Run all tests
    TestBasicFunctionality;
    // add more test calls here

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
  except
    on e:Exception do begin
      writeln('Error: ',ExceptionMsg(e));
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then readln;
end.
