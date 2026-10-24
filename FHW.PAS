unit FHw;
{$G+}{$S+}{$F+}{$R-}{$Q-}
interface
var Version:Real; AutoInit,Wide,Installed:Boolean; Ticks:LongInt;
 ResetPort,DataPort,WritePort,StatusPort,AckPort,PicPort:Word;
 MaskPort,FlipPort,ModePort,AddressPort,CountPort,PagePort:Word;
 IRQVector,IRQMask,IRQClear,DmaMask,DmaEnable,DmaMode:Byte;
 BlockSize,AllocationSize:Word; RawBuffer,BaseBuffer:Pointer;
 Buffers:array[1..2] of Pointer; Pages:array[1..2] of Byte;
 Offsets:array[1..2] of Word; Selected:Byte;
function ConfigureSound(Base:Word;IRQ,DMA,HighDMA:Byte):Boolean;
procedure StartDMA;
procedure StartBuffers;
procedure StopSound;
implementation
uses Dos,Crt,FCore,FSound;
type PWords=^TWords; TWords=array[0..255] of Integer;
 PBytes=^TBytes; TBytes=array[0..511] of Byte;
var Mixer:TWords; Clip:array[-512..512] of Byte;
 OldIRQ,SavedExit:Pointer; BasePage:Byte; BaseOffset:Word;
procedure WriteDSP(Value:Byte);
begin while Port[WritePort] and $80<>0 do; Port[WritePort]:=Value end;
function ReadDSP:Byte;
begin while Port[StatusPort] and $80=0 do; ReadDSP:=Port[DataPort] end;
function ResetDSP:Boolean;
var N:Byte;
begin
 Port[ResetPort]:=1; Delay(1); Port[ResetPort]:=0; N:=100;
 while (ReadDSP<>$AA) and (N>0) do Dec(N);
 ResetDSP:=N>0
end;
function Physical(P:Pointer):LongInt;
begin Physical:=LongInt(Seg(P^))*16+Ofs(P^) end;
function Normalize(P:Pointer):Pointer;
var A:LongInt;
begin A:=Physical(P); Normalize:=Ptr(A div 16,A mod 16) end;
procedure ProgramDMA(Page:Byte;Offset:Word);
begin
 Port[MaskPort]:=DmaMask; Port[FlipPort]:=0; Port[ModePort]:=DmaMode;
 Port[AddressPort]:=Lo(Offset); Port[AddressPort]:=Hi(Offset);
 Port[CountPort]:=Lo(BlockSize-1); Port[CountPort]:=Hi(BlockSize-1);
 Port[PagePort]:=Page; Port[MaskPort]:=DmaEnable
end;
procedure StartDMA;
begin
 ProgramDMA(BasePage,BaseOffset);
 if Wide then begin
  WriteDSP($41); WriteDSP($55); WriteDSP($F0);
  WriteDSP($B6); WriteDSP($10); WriteDSP($FF); WriteDSP(0)
 end else begin
  WriteDSP($D1); WriteDSP($40); WriteDSP(256-1000000 div 22000);
  if AutoInit then begin WriteDSP($48); WriteDSP($FF); WriteDSP(0); WriteDSP($1C) end
  else begin WriteDSP($14); WriteDSP($FF); WriteDSP(0) end
 end
end;
procedure ConvertMixer;
var I:Integer;
begin
 if Wide then for I:=0 to 255 do PWords(Buffers[Selected])^[I]:=Mixer[I] shl 5
 else for I:=0 to 255 do PBytes(Buffers[Selected])^[I]:=Clip[Mixer[I]];
 if Selected=1 then Selected:=2 else Selected:=1
end;
procedure PrepareMixer;
var I,J:Integer; N:Word; P:FSound.PSample;
begin
 for I:=0 to 3 do if VoiceFlags[I]<>0 then
  if Voices[I].Position>=Voices[I].Data^.Length then begin
   VoiceFlags[I]:=0; FillChar(Voices[I],SizeOf(Voices[I]),0); Dec(ActiveVoices)
  end;
 FillChar(Mixer,SizeOf(Mixer),0);
 for I:=0 to 3 do if VoiceFlags[I]<>0 then begin
  P:=FSound.PSample(Voices[I].Data);
  if (Voices[I].Volume<>0) or (P^.Length-Voices[I].Position>256) then N:=256
  else N:=Word(P^.Length-Voices[I].Position);
  FSound.ReadStream(P^,Voices[I].Position,N,Voices[I].Volume);
  for J:=0 to N-1 do Inc(Mixer[J],ShortInt(FSound.Buffer[J]))
 end
end;
procedure IRQHandler; interrupt;
var SavedCheck:Boolean; Ignored:Byte;
begin
 SavedCheck:=CheckBreak; CheckBreak:=False; Inc(Ticks);
 if not AutoInit then begin
  ProgramDMA(Pages[Selected],Offsets[Selected]);
  WriteDSP($14); WriteDSP($FF); WriteDSP(0); ConvertMixer
 end;
 PrepareMixer;
 if AutoInit then ConvertMixer;
 CheckBreak:=SavedCheck; Ignored:=Port[AckPort]; Port[$A0]:=$20; Port[$20]:=$20
end;
procedure StopSound;
begin
 if not Installed then Exit;
 if Wide then WriteDSP($D5) else begin WriteDSP($D0); WriteDSP($D3) end;
 Port[MaskPort]:=DmaMask;
 asm cli end;
 Port[PicPort]:=Port[PicPort] or IRQMask; SetIntVec(IRQVector,OldIRQ);
 asm sti end;
 Installed:=False;
 if RawBuffer<>nil then begin FreeMem(RawBuffer,AllocationSize); RawBuffer:=nil end
end;
procedure ExitSound;
begin ExitProc:=SavedExit; StopSound end;
function ConfigureSound(Base:Word;IRQ,DMA,HighDMA:Byte):Boolean;
var Major,Minor:Byte;
begin
 ResetPort:=Base+6; DataPort:=Base+10; WritePort:=Base+12; StatusPort:=Base+14;
 if not ResetDSP then begin ConfigureSound:=False; Exit end;
 WriteDSP($E1); Major:=ReadDSP; Minor:=ReadDSP;
 Version:=Major+Minor/100; AutoInit:=Version>2;
 Wide:=(Version>4) and (HighDMA<>255) and (HighDMA>3);
 if IRQ<=7 then begin IRQVector:=IRQ+8; PicPort:=$21 end
 else begin IRQVector:=IRQ+$70-8; PicPort:=$A1 end;
 IRQMask:=1 shl (IRQ mod 8); IRQClear:=not IRQMask;
 if Wide then begin
  MaskPort:=$D4; FlipPort:=$D8; ModePort:=$D6;
  AddressPort:=$C0+(HighDMA-4)*4; CountPort:=$C2+(HighDMA-4)*4;
  case HighDMA of 5:PagePort:=$8B; 6:PagePort:=$89; 7:PagePort:=$8A end;
  DmaMask:=HighDMA; DmaEnable:=HighDMA-4; DmaMode:=$58+HighDMA-4; AckPort:=Base+15
 end else begin
  MaskPort:=$0A; FlipPort:=$0C; ModePort:=$0B;
  AddressPort:=DMA*2; CountPort:=DMA*2+1;
  case DMA of 0:PagePort:=$87; 1:PagePort:=$83; 2:PagePort:=$81; 3:PagePort:=$82 end;
  DmaMask:=DMA+4; DmaEnable:=DMA;
  if AutoInit then DmaMode:=$58+DMA else DmaMode:=$48+DMA;
  AckPort:=Base+14
 end;
 if AutoInit then BlockSize:=512 else BlockSize:=256;
 asm cli end;
 Port[PicPort]:=Port[PicPort] or IRQMask;
 GetIntVec(IRQVector,OldIRQ); SetIntVec(IRQVector,@IRQHandler);
 Port[PicPort]:=Port[PicPort] and IRQClear;
 asm sti end;
 Installed:=True; SavedExit:=ExitProc; ExitProc:=@ExitSound; ConfigureSound:=True
end;
procedure StartBuffers;
var I,V:Integer; A:LongInt; Span:Word;
begin
 FillChar(VoiceFlags,SizeOf(VoiceFlags),0); FillChar(Voices,SizeOf(Voices),0); ActiveVoices:=0;
 if Wide then begin AllocationSize:=2048; Span:=512 end
 else begin AllocationSize:=1024; Span:=256 end;
 GetMem(RawBuffer,AllocationSize); A:=Physical(RawBuffer);
 if Wide then begin
  if A div 2 mod 65536+512>=65536 then Inc(A,1024)
 end else if A mod 65536+512>=65536 then Inc(A,512);
 BaseBuffer:=Ptr(A div 16,A mod 16);
 for I:=1 to 2 do begin
  Buffers[I]:=Ptr((A+LongInt(I-1)*Span) div 16,(A+LongInt(I-1)*Span) mod 16);
  Pages[I]:=Physical(Buffers[I]) div 65536;
  if Wide then Offsets[I]:=Physical(Buffers[I]) div 2 mod 65536
  else Offsets[I]:=Physical(Buffers[I]) mod 65536
 end;
 BasePage:=A div 65536;
 if Wide then BaseOffset:=A div 2 mod 65536 else BaseOffset:=A mod 65536;
 if Wide then FillChar(BaseBuffer^,1024,0)
 else begin
  FillChar(BaseBuffer^,512,128);
  for I:=-512 to 512 do begin V:=I; if V< -128 then V:=-128; if V>127 then V:=127; Clip[I]:=V+128 end
 end;
 FillChar(Mixer,SizeOf(Mixer),0); Selected:=1; Ticks:=0; StartDMA
end;
begin
 Installed:=False; RawBuffer:=nil
end.
