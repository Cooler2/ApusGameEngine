// Convenient interface for Regular Expressions (wrapper of RegExpr unit)
// Written by Ivan Polyacov (ivan@apus-software.com), Copyright (C) 2019
unit MyRegExpr;
interface
 uses RegExpr;

 threadvar
  // values for matched substrings
  reMatches:array[1..9] of WideString;
  reMatchPos,reMatchLen:array[1..9] of integer;

 function REMatch(input,re:WideString;flags:string=''):boolean;
 function REReplace(input,re,replacement:WideString;flags:string=''):WideString;

implementation

 function REMatch(input,re:WideString;flags:string=''):boolean;
  var
   i:integer;
  begin
   with TRegExpr.Create do try
    if flags<>'' then
     for i:=1 to length(flags) do
      case flags[i] of
       'i':ModifierI:=true;
       'r':ModifierR:=true;
       's':ModifierS:=true;
       'g':ModifierG:=true;
       'x':ModifierX:=true;
       'm':ModifierM:=true;
      end;
    expression:=re;
    result:=Exec(input);
    if result and (pos('(',re)>0) then
     for i:=1 to 9 do begin
      reMatches[i]:=Match[i];
      reMatchPos[i]:=MatchPos[i];
      reMatchLen[i]:=MatchLen[i];
     end;
    finally Free;
   end;
  end;

 function REReplace(input,re,replacement:WideString;flags:string=''):WideString;
  var
   i:integer;
  begin
   with TRegExpr.Create do try
    if flags<>'' then
     for i:=1 to length(flags) do
      case flags[i] of
       'i':ModifierI:=true;
       'r':ModifierR:=true;
       's':ModifierS:=true;
       'g':ModifierG:=true;
       'x':ModifierX:=true;
       'm':ModifierM:=true;
      end;
    expression:=re;
    result:=Replace(input, replacement, true);
    finally Free;
   end;
  end;

end.
