program Phobia;
{$M 16384,0,655360}
uses FApp;
var Results:Text;
begin
 if (ParamStr(1)='/SMOKE') or (ParamStr(2)='/SMOKE') then begin
  RunGame(60);
  if CompletedFrames<60 then Halt(1);
  Assign(Results,'GAME.RES'); Rewrite(Results);
  WriteLn(Results,'PASS 0000:380A'); WriteLn(Results,'FRAMES ',CompletedFrames); Close(Results)
 end
 else RunGame(0)
end.
