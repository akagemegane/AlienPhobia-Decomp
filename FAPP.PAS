unit FApp;
{$G+}{$S+}{$F+}{$R-}{$Q-}
interface
uses FCore;
var Player:TPlayer; ScoreText:TText; FrameClock:TClock; NewGame:Boolean;
 CompletedFrames:LongInt;
function InitializeAudio:Boolean;
procedure ConfigureFlags(First,Second:String);
procedure LoadResources;
procedure Intro;
procedure InitializeRound;
procedure RunGame(FrameLimit:Word);
implementation
uses Crt,Dos,RXms,FRecover,FSound,FHw,FGfx,FInput,FScores;
type TRecoverPalette=FRecover.TPalette; PRecoverPalette=^TRecoverPalette;
procedure ReadBackdrop(Name:String);
begin FRecover.LoadBackdrop(Name,FRecover.PScreen(Frame)^,FRecover.PScreen(DisplayFrame)^) end;
procedure ReadPalette(Name:String);
begin FRecover.LoadPalette(Name,PRecoverPalette(FGfx.Palette)^) end;
procedure SetPalette;
var I:Integer;
begin Port[$3C8]:=1; for I:=4 to 768 do Port[$3C9]:=FGfx.Palette^[I] end;
function InitializeAudio:Boolean;
var Base:Word; IRQ,DMA,HDMA:Byte;
begin
 Randomize; InitializeAudio:=False;
 if not FRecover.ReadBlaster(Base,IRQ,DMA,HDMA) then Exit;
 if not ConfigureSound(Base,IRQ,DMA,HDMA) then Exit;
 if Wide then SoundMode:=2 else SoundMode:=1;
 if not RXms.Available then Exit;
 RXms.Initialize;
 if RXms.FreeKB<190 then Exit;
 InitializeAudio:=True
end;
procedure ConfigureFlags(First,Second:String);
begin
 if (First<>'NOSOUND') and (First<>'nosound') and
    (Second<>'NOSOUND') and (Second<>'nosound') then begin
  GameSound.Spare:=GameSound.Spare or 1;
  if InitializeAudio then begin GameSound.Sample:=1; GameSound.Enabled:=0 end
  else begin GameSound.Sample:=0; GameSound.Enabled:=1 end
 end else begin GameSound.Spare:=GameSound.Spare and $FF00; GameSound.Sample:=0; GameSound.Enabled:=0 end;
 if GameSound.Sample<>0 then GameSound.Spare:=GameSound.Spare and $00FF
end;
procedure LoadResources;
const Slots:array[1..12] of Integer=(1,6,9,17,33,44,48,58,61,76,102,105);
 Names:array[1..12] of String[11]=('l1.dat','l2.dat','l3.dat','l4.dat',
  'l5.dat','l6.dat','f1.dat','l7.dat','l8.dat','f2.dat','l9.dat','l10.dat');
var I:Integer; Name:String; P:FSound.PSample;
begin
 for I:=1 to 12 do LoadSprites(Names[I],Slots[I]);
 if GameSound.Sample<>0 then begin
  for I:=1 to 9 do begin
   Str(I,Name); Name:='s'+Name+'.dat'; FSound.LoadSample(P,Name);
   Samples[I]:=FCore.PSample(P)
  end;
  StartBuffers
 end
end;
procedure Intro;
var Scale,Row,Col,Previous,H,M,S,HS:Word;
begin
 ReadBackdrop('p2.dat'); ReadPalette('a1.dat'); SetPalette; PlayEffect(4); Previous:=65535;
 for Scale:=10 downto 1 do begin
  repeat GetTime(H,M,S,HS) until HS div 20<>Previous;
  Previous:=HS div 5;
  for Row:=1 to 200 div Scale do for Col:=1 to 320 div Scale do
   Mem[$A000:(100-(200 div Scale) div 2)*320+(Row-1)*320+
    160-(320 div Scale) div 2+Col]:=DisplayFrame^[(Row*Scale-1)*320+Col*Scale-1]
 end;
 ReadBackdrop('p1.dat');
 FRecover.OverlayBackdrop('p3.dat',FRecover.PScreen(Frame)^,FRecover.PScreen(DisplayFrame)^);
 PresentFrame; Delay(1000); FGfx.FadePalette(4)
end;
procedure SpawnAtEdge(var Enemy:FCore.TEnemy);
var Edge:Integer;
begin
 Edge:=Random(4);
 with Enemy do begin
  case Edge of
   1:begin X:=Random(300)+10; Y:=5 end;
   2:begin X:=315; Y:=Random(180)+10 end;
   3:begin X:=Random(300)+10; Y:=195 end;
   0,4:begin X:=10; Y:=Random(180)+10 end
  end;
  Rate:=3; Active:=1; Marked:=0; Flag1:=0; Flag2:=0
 end
end;
procedure InitializeRound;
var I:Integer;
begin
 FInput.InstallKeyboard; Intro;
 FillChar(Mem[$A000:1],64000,0); SetPalette;
 GameOver:=0; NewGame:=False; EnemyLimit:=2; InitVertices(GameAngles);
 ScoreText.X:=300; ScoreText.Y:=190;
 GetMem(CollisionGrid,32000); ReadPalette('a1.dat'); ReadBackdrop('p1.dat');
 Player.X:=160; Player.Y:=100; Player.Angle:=1;
 Player.VX:=GameAngles[1].X; Player.VY:=GameAngles[1].Y;
 Player.Rate:=1; Player.Health:=70; Player.Active:=1; Player.Firing:=0;
 Player.Cooldown:=0; Kills:=0; Player.Stage:=1; Player.Effects.Mode:=1;
 for I:=1 to 30 do Player.Effects.Particles[I].Active:=0;
 for I:=1 to 100 do begin Player.Effects.Bolts[I].Active:=0; Player.Effects.Bolts[I].Age:=0 end;
 Player.Effects.Limit:=40;
 Bonus2.X:=10; Bonus2.Y:=10; Bonus2.Rate:=0; Bonus2.Age:=0; Bonus2.Active:=0; Bonus2Active:=0;
 Bonus1.X:=10; Bonus1.Y:=10; Bonus1.Rate:=0; Bonus1.Age:=0; Bonus1.Active:=0; Bonus1Active:=0;
 for I:=1 to EnemyLimit do SpawnAtEdge(Enemies[I])
end;
procedure TurnPlayer(Delta:Integer);
begin
 Player.Angle:=Rotate(Player.Angle,Delta);
 Player.VX:=GameAngles[Byte(Player.Angle)].X; Player.VY:=GameAngles[Byte(Player.Angle)].Y
end;
procedure MoveBounded(var X,Y:Integer;VX,VY,Rate,Minimum,MaxX,MaxY:Integer);
begin
 if Rate<=0 then Exit;
 Inc(X,VX*2 div Rate); Inc(Y,VY*2 div Rate);
 if X>MaxX then X:=MaxX; if X<Minimum then X:=Minimum;
 if Y>MaxY then Y:=MaxY; if Y<Minimum then Y:=Minimum
end;
procedure MoveEffects;
type PShot=^TShot;
var I:Integer;
begin
 for I:=1 to 30 do if Player.Effects.Particles[I].Active<>0 then
  with Player.Effects.Particles[I] do begin
   Inc(X,VX*2 div Rate); Inc(Y,VY*2 div Rate);
   ParticleHit(PShot(@Player.Effects.Particles[I])^)
  end;
 for I:=1 to 100 do if Player.Effects.Bolts[I].Active<>0 then
  with Player.Effects.Bolts[I] do begin
   Inc(X,VX*2 div Rate); Inc(Y,VY*2 div Rate); Inc(Age);
   BoltHit(Player.Effects.Bolts[I])
  end
end;
procedure GameFrame;
var I,Angle:Integer;
begin
 if FInput.LeftKey then TurnPlayer(-2);
 if FInput.RightKey then TurnPlayer(2);
 if FInput.UpKey then Player.Rate:=3 else Player.Rate:=0;
 if FInput.FireKey then FirePlayer(Player);
 Move(Frame^,DisplayFrame^,64000); FillChar(CollisionGrid^,32000,0);
 if GameSound.Enabled<>0 then NoSound; GameSound.Value:=0;
 MoveBounded(Bonus2.X,Bonus2.Y,Bonus2.VX,Bonus2.VY,Bonus2.Rate,10,310,190);
 if Bonus2.Active<>0 then begin GridWrite(Bonus2.X,Bonus2.Y,3,1,CollisionGrid); RawSprite(Bonus2.X,Bonus2.Y,44) end;
 MoveBounded(Bonus1.X,Bonus1.Y,Bonus1.VX,Bonus1.VY,Bonus1.Rate,10,310,190);
 if Bonus1.Active<>0 then begin
  GridWrite(Bonus1.X,Bonus1.Y,4,1,CollisionGrid);
  if Random(3)=1 then RawSprite(Bonus1.X,Bonus1.Y-1,105) else RawSprite(Bonus1.X,Bonus1.Y,106)
 end;
 SpawnWave;
 for I:=1 to EnemyLimit do if Enemies[I].Active<>0 then
  GridWrite(Enemies[I].X,Enemies[I].Y,2,I,CollisionGrid);
 for I:=1 to EnemyLimit do begin
  if Enemies[I].Active<>0 then begin
   Angle:=Direction(Enemies[I].X,Enemies[I].Y,Player.X,Player.Y,GameAngles);
   Enemies[I].Angle:=Angle; Enemies[I].VX:=GameAngles[Byte(Angle)].X;
   Enemies[I].VY:=GameAngles[Byte(Angle)].Y
  end;
  EnemyMove(Enemies[I]); DrawEnemy(Enemies[I])
 end;
 MoveBounded(Player.X,Player.Y,Player.VX,Player.VY,Player.Rate,15,310,190);
 CheckPlayerCollision(Player); MoveEffects; DrawPlayer(Player);
 if GameSound.Enabled<>0 then Sound(GameSound.Value);
 Player.Cooldown:=Kills; DrawHUD(Player.Health); RenderNumber(Kills,ScoreText);
 repeat until ClockReady(FrameClock); PresentFrame
end;
procedure RunGame(FrameLimit:Word);
var I,Frames:Word;
begin
 WriteLn('PHOBIA'); FGfx.InitGraphics; ConfigureFlags(ParamStr(1),ParamStr(2));
 LoadResources; Delay(500); FInput.SetVideoMode($13);
 repeat
  InitializeRound; PlayEffect(7); Frames:=0;
  repeat
   GameFrame; Inc(Frames); Inc(CompletedFrames);
   if (FrameLimit<>0) and (Frames>=FrameLimit) then GameOver:=1
  until FInput.ExitKey or (GameOver<>0);
  PlayEffect(9); for I:=1 to 400 do Enemies[I].Active:=0; NoSound;
  NewGame:=FScores.ScoreScreen; FreeMem(CollisionGrid,32000)
 until not NewGame;
 FGfx.CloseGraphics; FInput.SetVideoMode(3); StopSound;
 WriteLn('PHOBIA')
end;
end.
