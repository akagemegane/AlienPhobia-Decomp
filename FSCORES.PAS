unit FScores;
{$G+}{$S+}{$R-}{$Q-}
interface
type THighScore=record Score:Word; Name:String end;
 THighScores=array[1..10] of THighScore;
var LastMessage:String; LastName:String[7]; LastRank:Integer;
procedure ShowScores(var Scores:THighScores);
function ScoreScreen:Boolean;
implementation
uses Crt,FCore,FRecover,FInput;
procedure PutText(Value:String;X,Y:Integer;Animated:Boolean);
var T:TText;
begin T.X:=X; T.Y:=Y; RenderText(Value,Animated,T) end;
procedure ReadScores(var Scores:THighScores);
var F:Text; I:Integer;
begin
 Assign(F,'alien.da1'); Reset(F);
 for I:=1 to 10 do begin ReadLn(F,Scores[I].Name); ReadLn(F,Scores[I].Score) end;
 Close(F)
end;
procedure WriteScores(var Scores:THighScores);
var F:Text; I:Integer;
begin
 Assign(F,'alien.da1'); Rewrite(F);
 for I:=1 to 10 do begin WriteLn(F,Scores[I].Name); WriteLn(F,Scores[I].Score) end;
 Close(F)
end;
procedure ShowScores(var Scores:THighScores);
var Number:String; I,Level:Integer;
begin
 Move(Frame^,DisplayFrame^,64000); Str(Kills,Number); LastMessage:='';
 case Kills of
  0..50:LastMessage:=Number+' Aliens killed. Poor.';
  51..100:LastMessage:=Number+' kills Mr. Average?';
  101..150:LastMessage:=Number+' aliens got new asshole';
  151..200:LastMessage:=' Killed '+Number+' fucking aliens';
  201..400:LastMessage:=' YEAH! '+Number+' aliens died';
  401..550:LastMessage:='Excellent! '+Number+' kills.';
  551..10000:LastMessage:=' Kills '+Number+' Born to kill'
 end;
 if LastMessage<>'' then PutText(LastMessage,310,192,True);
 PutText('TOP 10 troopers',220,13,True); ReadScores(Scores);
 for I:=1 to 10 do begin
  PutText(Scores[I].Name,70,(I-1)*16+30,False);
  Str(Scores[I].Score,Number); PutText(Number,220,(I-1)*16+30,False)
 end;
 for I:=1 to 10 do begin
  Level:=Scores[I].Score div 80; if Level>14 then Level:=14;
  RawSprite(120,(I-1)*16+30,Level+61)
 end;
 PresentFrame
end;
procedure RestoreRect(X1,Y1,X2,Y2:Integer);
var Row:Integer;
begin
 for Row:=Y1 to Y2 do
  Move(Frame^[320*Row+X1-1],DisplayFrame^[320*Row+X1-1],X2-X1)
end;
function ScoreScreen:Boolean;
const Suffix:array[1..10] of String[2]=('st','nd','rd','th','th','th','th','th','th','th');
var Scores:THighScores; Name:String[7]; Rank,I:Integer; Key:Char; Number:String;
begin
 while FInput.FireKey or FInput.UpKey or FInput.LeftKey or FInput.RightKey do;
 FInput.RestoreKeyboard;
 FRecover.LoadBackdrop('p1.dat',FRecover.PScreen(Frame)^,FRecover.PScreen(DisplayFrame)^);
 ShowScores(Scores); LastName:=''; LastRank:=0;
 if (Kills>=0) and (Kills>Scores[10].Score) then begin
  RestoreRect(5,20,310,180); Rank:=1;
  while (Rank<=10) and (Kills<=Scores[Rank].Score) do Inc(Rank);
  while KeyPressed do Key:=ReadKey;
  Str(Rank,Number); PutText('You made '+Number+Suffix[Rank]+' highscore',270,100,True);
  PutText('What is your name trooper?',290,120,True); Name:='';
  repeat
   PresentFrame; Key:=ReadKey;
   if (Key<>#13) and (Key<>#8) and (Length(Name)<7) then begin
    PlayEffect(8); Name:=Name+Key
   end;
   if Key=#8 then Delete(Name,Length(Name),1);
   RestoreRect(5,130,190,150); PutText(Name,170,140,False); PresentFrame
  until Key=#13;
  for I:=10 downto Rank+1 do Scores[I]:=Scores[I-1];
  Scores[Rank].Score:=Word(Kills); Scores[Rank].Name:=Name;
  LastName:=Name; LastRank:=Rank; WriteScores(Scores); ShowScores(Scores)
 end;
 RawSprite(270,125,102); PutText('D',270,140,False); RawSprite(270,155,104);
 RawSprite(270,35,102); PutText('N',270,50,False); RawSprite(270,65,103); PresentFrame;
 repeat Key:=ReadKey until Key in ['d','D','n','N'];
 ScoreScreen:=Key in ['n','N']
end;
end.
