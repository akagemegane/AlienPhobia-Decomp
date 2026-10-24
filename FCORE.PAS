unit FCore;
{$G+}{$S+}{$R-}{$Q-}
interface
type
 TPoint=record X,Y:Integer end;
 TVertices=array[1..255] of TPoint;
 TGrid=array[1..160,1..100] of Integer;
 PGrid=^TGrid;
 TClock=record Hour,Minute,Second,Hundredth,NextTick,LastSecond:Word end;
 TPixels=array[0..63999] of Byte;
 PPixels=^TPixels;
 TSample=record Handle:Word; Offset,Length:LongInt end;
 PSample=^TSample;
 TVoice=record Data:PSample; Enabled:Byte; Position:LongInt; Volume:Byte end;
 TFragment=record X,Y,VX,VY,Angle,Rate,Other:Integer end;
 TEnemy=record
  X,Y,VX,VY,Angle,Rate,Other:Integer;
  Active,Marked,Flag1,Flag2:Byte; Fragments:array[1..5] of TFragment
 end;
 TShot=record X,Y,VX,VY,Angle,Rate,Other:Integer; Active,Age:Byte end;
 TSoundState=record Enabled,Sample:Byte; Spare:Word; Value:Integer end;
 TText=record Text:String; X,Y:Integer end;
 TParticle=record X,Y,VX,VY,Angle,Rate,Other:Integer; Active:Byte end;
 TEffects=record Particles:array[1..30] of TParticle;
  Bolts:array[1..100] of TShot; Mode,Limit:Byte end;
 TPlayer=record X,Y,VX,VY,Angle,Rate,Other,Health,Sprite,Cooldown,Stage:Integer;
  Active,Firing,Hit:Byte; Effects:TEffects end;
var Widths,Heights:array[0..150] of Byte;
 Images:array[0..150] of PPixels; Frame:PPixels;
 VoiceFlags:array[0..3] of Byte; Voices:array[0..3] of TVoice;
 ActiveVoices:Byte;
 GameAngles:TVertices; CollisionGrid:PGrid; Enemies:array[1..400] of TEnemy;
 GameSound:TSoundState; SoundMode:Byte; Kills:Integer;
 Samples:array[0..255] of PSample;
 DisplayFrame:PPixels;
 Bonus1Active,Bonus2Active,GameOver:Byte;
 Bonus1,Bonus2:TShot; EnemyLimit:Word; SoundIndicators:Byte;
procedure GridWrite(X,Y,Kind,Number:Integer;var Grid:PGrid);
function GridHit(var Kind:Integer;X,Y,Size:Integer;var Grid:PGrid):Integer;
procedure InitVertices(var V:TVertices);
function Direction(X1,Y1,X2,Y2:Integer;var V:TVertices):Integer;
procedure DrawClipped(X,Y,Index:Integer);
function ClockAt(var C:TClock;H,M,S,HS:Word):Boolean;
function ClockReady(var C:TClock):Boolean;
procedure StartSample(P:PSample;Mode,Volume:Byte);
procedure LoadSprites(Name:String;Index:Integer);
procedure EnemyDeath(Kind:Byte;var Enemy:TEnemy);
procedure EnemyMove(var Enemy:TEnemy);
procedure ParticleHit(var Shot:TShot);
procedure BoltHit(var Shot:TShot);
procedure RenderNumber(Number:Integer;var Text:TText);
procedure RenderText(Value:String;Animated:Boolean;var Text:TText);
procedure DrawEnemy(var Enemy:TEnemy);
procedure EmitEffects(X,Y,Angle:Integer;var Effects:TEffects);
procedure FirePlayer(var Player:TPlayer);
procedure CheckPlayerCollision(var Player:TPlayer);
procedure DrawPlayer(var Player:TPlayer);
procedure SpawnWave;
procedure DrawHUD(Health:Integer);
procedure RawSprite(X,Y,Index:Integer);
procedure PresentFrame;
function Rotate(A,B:Integer):Integer;
procedure PlayEffect(Channel:Byte);
implementation
uses Dos;
procedure GridWrite(X,Y,Kind,Number:Integer;var Grid:PGrid);
begin
 if (X>0) and (X<320) and (Y>0) and (Y<200) then
  case Kind of
   1:Grid^[X div 2,Y div 2]:=Number;
   2:Grid^[X div 2,Y div 2]:=Number+1;
   3:Grid^[X div 2,Y div 2]:=Number+401;
   4:Grid^[X div 2,Y div 2]:=Number+402
  end
end;
function GridHit(var Kind:Integer;X,Y,Size:Integer;var Grid:PGrid):Integer;
var I,J,Value,Found:Integer;
begin
 Found:=0;
 if (X>=320) or (Y>=200) or (X<=0) or (Y<=0) or
  (X div 2-(Size div 2+2)<2) or (Y div 2-(Size div 2+2)<2) then begin
  Kind:=0; GridHit:=0; Exit
 end;
 for I:=0 to Size div 2+1 do
  for J:=0 to Size div 2+1 do begin
   Value:=Grid^[X div 2-I,Y div 2-J];
   case Value of
    1:begin Found:=1; Kind:=1 end;
    2..401:begin Found:=Value-1; Kind:=2 end;
    402:begin Found:=1; Kind:=3 end;
    403:begin Found:=1; Kind:=4 end
   end
  end;
 GridHit:=Found
end;
procedure InitVertices(var V:TVertices);
const X:array[1..10] of Integer=(-7,-7,-7,-6,-6,-5,-4,-3,-2,-1);
 Y:array[1..10] of Integer=(0,-1,-2,-3,-4,-5,-6,-6,-7,-7);
var I:Integer;
begin
 for I:=1 to 10 do begin
  V[I].X:=X[I]; V[I].Y:=Y[I];
  V[I+10].X:=-Y[I]; V[I+10].Y:=X[I];
  V[I+20].X:=-X[I]; V[I+20].Y:=-Y[I];
  V[I+30].X:=Y[I]; V[I+30].Y:=-X[I]
 end
end;
function Direction(X1,Y1,X2,Y2:Integer;var V:TVertices):Integer;
var DX,DY,N,Result:Integer; Q:Real; Magnitude:LongInt;
begin
 DX:=X1-X2; DY:=Y1-Y2;
 if DY=0 then DY:=1;
 if DX=0 then DX:=2;
 Q:=DX/DY;
 if Q<0 then Magnitude:=Round(Q*1000)
 else Magnitude:=Round(DY/DX*1000);
 if Magnitude<0 then Magnitude:=-Magnitude;
 if Magnitude>10000 then Magnitude:=9000;
 N:=0;
 case Integer(Magnitude) of
  0..150:N:=1; 151..300:N:=2; 301..550:N:=3; 551..750:N:=4;
  751..1000:N:=5; 1001..1400:N:=6; 1401..1950:N:=7;
  1951..2500:N:=8; 2501..3600:N:=9; 3601..10000:N:=10
 end;
 Result:=N;
 if (DY<0) and (DX<=0) then Result:=N+20;
 if (DY>=0) and (DX<0) then Result:=N+10;
 if (DY<0) and (DX>=0) then Result:=N+30;
 Direction:=Result
end;
procedure DrawClipped(X,Y,Index:Integer);
var Row,Col:Integer; Offset:Word; Pixel:Byte;
begin
 if (X<1) or (X>319) then Exit;
 for Row:=0 to Integer(Heights[Index])-1 do
  for Col:=1 to Widths[Index] do begin
   Pixel:=Images[Index]^[Row*Widths[Index]+Col-1];
   if Pixel<>0 then begin
    Offset:=Word((Row+Y-Heights[Index] div 2)*320+Col+X-Widths[Index] div 2);
    if (Offset>0) and (Offset<64000) then Frame^[Offset-1]:=Pixel
   end
  end
end;
function ClockAt(var C:TClock;H,M,S,HS:Word):Boolean;
var Ready:Boolean;
begin
 C.Hour:=H; C.Minute:=M; C.Second:=S; C.Hundredth:=HS;
 Ready:=((HS>C.NextTick) and (S=C.LastSecond)) or
  ((Word(HS+100)>C.NextTick) and (S<>C.LastSecond));
 if Ready then begin C.NextTick:=HS+2; C.LastSecond:=S end;
 ClockAt:=Ready
end;
function ClockReady(var C:TClock):Boolean;
var H,M,S,HS:Word;
begin
 GetTime(H,M,S,HS); ClockReady:=ClockAt(C,H,M,S,HS)
end;
procedure StartSample(P:PSample;Mode,Volume:Byte);
var I,Selected:Byte;
begin
 Selected:=255; I:=0;
 repeat
  if VoiceFlags[I]=0 then Selected:=I;
  Inc(I)
 until (Selected<>255) or (I=4);
 if Selected<>255 then begin
  Inc(ActiveVoices); Voices[Selected].Data:=P;
  Voices[Selected].Enabled:=Mode; Voices[Selected].Position:=0;
  Voices[Selected].Volume:=Volume; VoiceFlags[Selected]:=1
 end
end;
procedure LoadSprites(Name:String;Index:Integer);
var F:File; Count:Word;
begin
 if Widths[Index]<>0 then FreeMem(Images[Index],Word(Widths[Index])*Heights[Index]);
 Assign(F,Name); Reset(F,1);
 repeat
  BlockRead(F,Widths[Index],1); BlockRead(F,Heights[Index],1);
  Inc(Widths[Index]); Inc(Heights[Index]);
  Count:=Word(Widths[Index])*Heights[Index];
  GetMem(Images[Index],Count); BlockRead(F,Images[Index]^,Count);
  Inc(Index)
 until Eof(F);
 Close(F)
end;
procedure PlayEffect(Channel:Byte);
begin
 if GameSound.Sample<>0 then StartSample(Samples[Channel],1,0)
end;
procedure EnemyDeath(Kind:Byte;var Enemy:TEnemy);
var I,DirectionIndex:Integer;
begin
 with Enemy do begin
  if Marked<>0 then begin
   if Flag2=0 then
    for I:=1 to 5 do begin
     Fragments[I].X:=X; Fragments[I].Y:=Y;
     DirectionIndex:=Random(10)-5+23+Enemy.Angle;
     if DirectionIndex>40 then Dec(DirectionIndex,40);
     if DirectionIndex<1 then Inc(DirectionIndex,40);
     Fragments[I].Angle:=DirectionIndex;
     Fragments[I].VX:=GameAngles[Byte(DirectionIndex)].X;
     Fragments[I].VY:=GameAngles[Byte(DirectionIndex)].Y;
     Fragments[I].Rate:=1
    end
   else for I:=1 to 5 do with Fragments[I] do begin
    if Rate>0 then begin
     Inc(X,VX*2 div Rate); Inc(Y,VY*2 div Rate);
     if X>310 then X:=310; if X<10 then X:=10;
     if Y>190 then Y:=190; if Y<10 then Y:=10
    end;
    Inc(Rate)
   end;
   if Flag2<7 then Inc(Flag2)
   else begin Marked:=0; Flag1:=0; Active:=0; Flag2:=0 end
  end;
  if Active<>0 then begin
   if (GameSound.Enabled<>0) and (GameSound.Value<300) then GameSound.Value:=300;
   if SoundMode=1 then
    if Random(3)=2 then PlayEffect(6) else PlayEffect(5);
   if SoundMode=2 then PlayEffect(6);
   PlayEffect(6); Active:=0; Marked:=1;
   if Kind<>0 then Flag1:=1;
   Inc(Kills)
  end
 end
end;
procedure EnemyMove(var Enemy:TEnemy);
var Kind,Number:Integer;
begin
 if Enemy.Marked<>0 then EnemyDeath(0,Enemy);
 with Enemy do if (Active<>0) and (Rate>0) then begin
  Number:=GridHit(Kind,X+VX*2,Y+VY*2,3,CollisionGrid);
  if Kind<>2 then begin
   Inc(X,VX div Rate); Inc(Y,VY div Rate);
   if X>300 then X:=300; if X<10 then X:=10;
   if Y>180 then Y:=180; if Y<10 then Y:=10
  end
 end
end;
procedure CheckProjectile(var Shot:TShot;Mode:Byte);
var I,X,Y,Kind,Number:Integer;
begin
 with Shot do begin
  if (Y>190) or (Y<10) or (X<10) or (X>310) then Active:=0;
  if (Mode<>0) and (Age>5) then Active:=0;
  if Active=0 then Exit
 end;
 for I:=1 to 3 do begin
  X:=Shot.X; Y:=Shot.Y;
  if I=2 then begin
   Inc(X,GameAngles[Byte(Shot.Angle)].X div 2);
   Inc(Y,GameAngles[Byte(Shot.Angle)].Y div 2)
  end;
  if I=3 then begin
   Inc(X,GameAngles[Byte(Shot.Angle)].X);
   Inc(Y,GameAngles[Byte(Shot.Angle)].Y)
  end;
  Number:=GridHit(Kind,X,Y,10,CollisionGrid);
  if (Number>0) and (Kind=2) then begin
   EnemyDeath(Mode,Enemies[Number]); Shot.Active:=0; Exit
  end
 end
end;
procedure ParticleHit(var Shot:TShot);
begin CheckProjectile(Shot,0) end;
procedure BoltHit(var Shot:TShot);
begin CheckProjectile(Shot,1) end;
procedure RawSprite(X,Y,Index:Integer);
var Row,Col:Word; Dest:Word; Pixel:Byte;
begin
 for Row:=0 to Heights[Index]-1 do begin
  Dest:=Word(X+(Integer(Row)+Y-Heights[Index] div 2)*320-Widths[Index] div 2-1);
  for Col:=0 to Widths[Index]-1 do begin
   Pixel:=Images[Index]^[Row*Widths[Index]+Col];
   if Pixel<>0 then DisplayFrame^[Dest]:=Pixel;
   Inc(Dest)
  end
 end
end;
procedure PresentFrame;
begin
 while Port[$3DA] and 8<>0 do;
 while Port[$3DA] and 8=0 do;
 Move(Mem[Seg(DisplayFrame^):Ofs(DisplayFrame^)-1],Mem[$A000:0],63999)
end;
procedure RenderNumber(Number:Integer;var Text:TText);
var I,N,Sprite:Integer;
begin
 Str(Number,Text.Text); N:=Length(Text.Text);
 for I:=N downto 1 do begin
  Sprite:=-1;
  case Text.Text[I] of
   '1'..':':Sprite:=Ord(Text.Text[I])-1;
   '0':Sprite:=57
  end;
  if Sprite>=0 then RawSprite(Text.X-N*10+I*10,Text.Y,Sprite)
 end
end;
procedure RenderText(Value:String;Animated:Boolean;var Text:TText);
var I,N,Sprite:Integer;
begin
 GameSound.Spare:=GameSound.Spare and $00FF;
 Text.Text:=Value; N:=Length(Text.Text);
 for I:=1 to N do begin
  Sprite:=-1;
  case Text.Text[I] of
   '1'..':':Sprite:=Ord(Text.Text[I])-1;
   'a'..'z':Sprite:=Ord(Text.Text[I])-96+75;
   'A'..'Z':Sprite:=Ord(Text.Text[I])+11;
   '0':Sprite:=57
  end;
  if Sprite>=0 then RawSprite(Text.X-N*10+I*10,Text.Y,Sprite);
  if Animated then begin PlayEffect(8); PresentFrame end
 end
end;
function Rotate(A,B:Integer):Integer;
begin
 Inc(A,B); if A>40 then Dec(A,40); if A<1 then Inc(A,40); Rotate:=A
end;
procedure DrawEnemy(var Enemy:TEnemy);
var Index,Piece,I,J:Integer;
begin
 with Enemy do begin
  if Active<>0 then begin
   RawSprite(X,Y,6);
   if Random(5)=1 then Index:=Angle div 5+25 else Index:=Angle div 5+17;
   RawSprite(X+GameAngles[Byte(Angle)].X,Y+GameAngles[Byte(Angle)].Y,Index);
   Index:=Rotate(Angle,Random(3)+20);
   RawSprite(X+GameAngles[Byte(Index)].X,Y+GameAngles[Byte(Index)].Y,7);
   Index:=Rotate(Index,Random(3));
   RawSprite(X+GameAngles[Byte(Index)].X*2,Y+GameAngles[Byte(Index)].Y*2,8);
   Index:=Rotate(Angle,5); Piece:=Index div 5; if Piece>7 then Piece:=7;
   RawSprite(X+GameAngles[Byte(Index)].X,Y+GameAngles[Byte(Index)].Y,Piece+9);
   Index:=Rotate(Angle,35); Piece:=Index div 5; if Piece>7 then Piece:=7;
   RawSprite(X+GameAngles[Byte(Index)].X,Y+GameAngles[Byte(Index)].Y,Piece+9)
  end;
  if Marked<>0 then begin
   if Flag2=1 then for I:=1 to 7 do begin
    Index:=Rotate(Angle,Random(8)+16);
    for J:=1 to 5 do
     DrawClipped(X+GameAngles[Byte(Index)].X*J,Y+GameAngles[Byte(Index)].Y*J,Random(6)+38)
   end;
   for I:=1 to 5 do begin
    if Random(3)=1 then DrawClipped(Fragments[I].X,Fragments[I].Y,Random(6)+38);
    RawSprite(Fragments[I].X,Fragments[I].Y,I+32);
    if Flag1<>0 then RawSprite(Fragments[I].X,Fragments[I].Y-3,Random(2)+107)
   end;
   if Flag2=7 then for I:=1 to 5 do DrawClipped(Fragments[I].X,Fragments[I].Y,I+32)
  end
 end
end;
procedure RaiseTone(Value:Integer);
begin
 if (GameSound.Enabled<>0) and (Value>GameSound.Value) then GameSound.Value:=Value
end;
procedure EmitEffects(X,Y,Angle:Integer;var Effects:TEffects);
var I,J,DirectionIndex:Integer;
begin
 if Effects.Mode=1 then begin
  I:=1;
  while (I<>31) and (Effects.Particles[I].Active<>0) do Inc(I);
  if I<31 then begin
   Effects.Particles[I].X:=X; Effects.Particles[I].Y:=Y;
   Effects.Particles[I].Angle:=Angle;
   with Effects.Particles[I] do begin
    VX:=GameAngles[Byte(Angle)].X; VY:=GameAngles[Byte(Angle)].Y;
    Rate:=1; Active:=1
   end
  end
 end else if Effects.Mode=2 then begin
  for J:=1 to 5 do begin
   I:=1; while (I<>101) and (Effects.Bolts[I].Active<>0) do Inc(I);
   if I<101 then begin
    DirectionIndex:=Rotate(Random(3)-1,Angle);
    Effects.Bolts[I].X:=X+GameAngles[Byte(DirectionIndex)].X;
    Effects.Bolts[I].Y:=Y+GameAngles[Byte(DirectionIndex)].Y;
    Effects.Bolts[I].Angle:=DirectionIndex;
    with Effects.Bolts[I] do begin
     VX:=GameAngles[Byte(DirectionIndex)].X; VY:=GameAngles[Byte(DirectionIndex)].Y;
     Rate:=1; Active:=1; Age:=0
    end
   end;
   if Effects.Limit<1 then Effects.Mode:=1
  end;
  Dec(Effects.Limit)
 end
end;
procedure FirePlayer(var Player:TPlayer);
begin
 if Player.Effects.Mode=1 then begin RaiseTone(30); PlayEffect(1) end;
 if Player.Effects.Mode=2 then begin RaiseTone(50); PlayEffect(2) end;
 if Player.Stage<4 then Inc(Player.Stage) else Player.Stage:=1;
 if Player.Stage<4 then Player.Sprite:=Player.Stage+33 else Player.Sprite:=35;
 EmitEffects(Player.X,Player.Y,Rotate(Player.Sprite,Player.Angle),Player.Effects);
 Player.Firing:=1;
 if Player.Effects.Mode=1 then
  asm in al,$61; and al,$FC; out $61,al end
end;
procedure ChangeHealth(Value:Integer;var Player:TPlayer);
begin
 Inc(Player.Health,Value);
 if Player.Health<0 then begin GameOver:=1; Player.Health:=0 end;
 if Player.Health>70 then Player.Health:=70
end;
procedure CheckPlayerCollision(var Player:TPlayer);
var Kind,Number:Integer;
begin
 Player.Hit:=0; Kind:=0;
 Number:=GridHit(Kind,Player.X+7,Player.Y+7,15,CollisionGrid);
 if (Number>0) and (Kind=2) then begin
  RaiseTone(500); PlayEffect(3); ChangeHealth(-5,Player); Player.Hit:=1
 end;
 if (Number=1) and (Kind=3) then begin
  RaiseTone(1500); PlayEffect(4); ChangeHealth(23,Player); Bonus2Active:=0; Bonus2.Active:=0
 end;
 if (Number=1) and (Kind=4) then begin
  Player.Effects.Mode:=2; Player.Effects.Limit:=40; Bonus1Active:=0; Bonus1.Active:=0
 end;
 asm in al,$61; and al,$FC; out $61,al end
end;
procedure DrawPlayer(var Player:TPlayer);
var A,BaseX,BaseY,I,J,Distance,PX,PY,Image:Integer;
begin
 with Player do begin
  A:=Rotate(10,Angle); BaseX:=Player.X+GameAngles[Byte(A)].X div 2;
  BaseY:=Player.Y+GameAngles[Byte(A)].Y div 2;
  if Firing=0 then A:=Rotate(35,Angle) else A:=Rotate(Sprite,Angle);
  Distance:=20;
  for I:=1 to 6 do begin
   Dec(Distance,2);
   RawSprite(BaseX+GameAngles[Byte(A)].X*10 div Distance,BaseY+GameAngles[Byte(A)].Y*10 div Distance,4)
  end;
  if Effects.Mode=2 then RawSprite(BaseX+GameAngles[Byte(A)].X*10 div 6,BaseY+GameAngles[Byte(A)].Y*10 div 6,Random(3)+107);
  A:=Rotate(10,Angle);
  RawSprite(Player.X+GameAngles[Byte(A)].X div 2,Player.Y+GameAngles[Byte(A)].Y div 2,3);
  A:=Rotate(30,Angle);
  RawSprite(Player.X+GameAngles[Byte(A)].X div 2,Player.Y+GameAngles[Byte(A)].Y div 2,2);
  RawSprite(Player.X,Player.Y,1);
  if Hit<>0 then for I:=1 to 10 do begin
   PX:=Player.X+Random(20)-10; PY:=Player.Y+Random(20)-10;
   Image:=Random(3)+58; DrawClipped(PX,PY,Image)
  end;
  for I:=1 to 30 do if Effects.Particles[I].Active<>0 then with Effects.Particles[I] do begin
   RawSprite(X,Y,5);
   RawSprite(X+GameAngles[Byte(Angle)].X div 4,Y+GameAngles[Byte(Angle)].Y div 4,5);
   RawSprite(X+GameAngles[Byte(Angle)].X div 2,Y+GameAngles[Byte(Angle)].Y div 2,5)
  end;
  for I:=1 to 100 do if Effects.Bolts[I].Active<>0 then
   for J:=1 to 3 do begin
    PX:=Effects.Bolts[I].X+Random(5)-2; PY:=Effects.Bolts[I].Y+Random(5)-2;
    Image:=Random(4)+107; RawSprite(PX,PY,Image)
   end
 end
end;
procedure InitBonus(var Bonus:TShot);
begin
 Bonus.X:=Random(290)+10; Bonus.Y:=Random(170)+10;
 Bonus.Active:=1; Bonus.Rate:=0; Bonus.Age:=0
end;
procedure SpawnWave;
var I,Edge:Integer;
begin
 if (Kills>0) and (Kills mod 100=0) and (Bonus2Active=0) then begin
  InitBonus(Bonus2); Bonus2Active:=1
 end;
 if (Kills>0) and (Kills mod 20=0) and (Bonus1Active=0) then begin
  InitBonus(Bonus1); Bonus1Active:=1
 end;
 I:=1;
 while (I<=EnemyLimit) and ((Enemies[I].Active<>0) or (Enemies[I].Marked<>0)) do Inc(I);
 if I<=EnemyLimit then begin
  if Kills>6 then EnemyLimit:=Kills div 4;
  if EnemyLimit>400 then EnemyLimit:=400;
  Edge:=Random(4);
  with Enemies[I] do begin
   case Edge of
    1:begin X:=Random(300)+10; Y:=5 end;
    2:begin X:=315; Y:=Random(180)+10 end;
    3:begin X:=Random(300)+10; Y:=195 end;
    0,4:begin X:=10; Y:=Random(180)+10 end
   end;
   Rate:=3; Active:=1; Marked:=0; Flag1:=0; Flag2:=0
  end
 end
end;
procedure DrawHUD(Health:Integer);
var I,Level:Integer;
begin
 Level:=Kills div 80; if Word(Level)>14 then Level:=14;
 RawSprite(230,190,Level+61);
 if SoundMode=2 then for I:=1 to SoundIndicators do RawSprite(I*5+10,190,107);
 if Health>23 then Level:=23 else Level:=Health;
 for I:=1 to Level do RawSprite(I*3+7,196,45);
 if Health>23 then begin
  if Health>46 then Level:=46 else Level:=Health;
  for I:=23 to Level do RawSprite(I*3+7,196,46)
 end;
 if Health>46 then for I:=46 to Health do RawSprite(I*3+7,196,47)
end;
begin
 FillChar(Widths,SizeOf(Widths),0); FillChar(Heights,SizeOf(Heights),0);
 FillChar(Images,SizeOf(Images),0); Frame:=nil;
 FillChar(VoiceFlags,SizeOf(VoiceFlags),0); ActiveVoices:=0
end.
