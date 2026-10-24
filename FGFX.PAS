unit FGfx;
{$G+}{$S+}{$R-}{$Q-}
interface
uses FCore;
type TPalette=array[1..768] of Byte; PPalette=^TPalette;
var Palette,Fading:PPalette; Keys:array[1..10] of Word;
procedure InitGraphics;
procedure CloseGraphics;
procedure FadePalette(Period:Integer);
implementation
uses Dos;
procedure InitGraphics;
var I:Integer;
begin
 for I:=1 to 10 do Keys[I]:=0;
 for I:=1 to 150 do begin Widths[I]:=0; Heights[I]:=0 end;
 GetMem(DisplayFrame,64000); New(Palette); New(Fading);
 GetMem(Frame,64000); FillChar(Frame^,64000,0)
end;
procedure CloseGraphics;
var I:Integer; Count:Word;
begin
 for I:=1 to 10 do Keys[I]:=0;
 Dispose(Palette); Dispose(Fading);
 for I:=1 to 150 do begin
  Count:=Word(Widths[I])*Heights[I];
  if Count<>0 then FreeMem(Images[I],Count)
 end;
 FreeMem(DisplayFrame,64000); FreeMem(Frame,64000)
end;
procedure FadePalette(Period:Integer);
var I:Integer; Done:Boolean; H,M,S,HS,Previous:Word;
begin
 Fading^:=Palette^; Previous:=65535;
 repeat
  Done:=True;
  repeat GetTime(H,M,S,HS) until HS div Period<>Previous;
  Previous:=HS div 5;
  Port[$3C8]:=1;
  for I:=4 to 768 do Port[$3C9]:=Fading^[I];
  for I:=1 to 768 do if Fading^[I]>0 then begin
   Dec(Fading^[I]); Done:=False
  end
 until Done
end;
end.
