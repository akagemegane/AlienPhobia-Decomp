unit FSound;
{$G+}{$S+}{$R-}{$Q-}
interface
uses RXms;
type
 TSample=record Handle:Word; Offset,Length:LongInt end;
 PSample=^TSample;
 TBuffer=array[0..511] of Byte;
var Archived,SharedXms:Boolean; ArchiveName:String;
 SharedHandle:Word; SharedOffset,SampleLength:LongInt;
 SampleFile:File; Buffer:TBuffer; Transfer:RXms.TMove;
procedure OpenSample(Name:String);
procedure LoadSample(var Sample:PSample;Name:String);
procedure ReadStream(var Sample:TSample;var Position:LongInt;Count:Word;RepeatMode:Byte);
implementation
uses FRecover;
procedure OpenSample(Name:String);
type TEntry=record Tag:TTag; Offset,Length:LongInt end;
var Tag:TTag; Entry:TEntry; Entries,I:Integer; Found:Boolean;
begin
 if Archived then begin
  for I:=1 to 8 do if I<=Length(Name) then Tag[I]:=Name[I] else Tag[I]:=#0;
  Assign(SampleFile,ArchiveName); Reset(SampleFile,1);
  BlockRead(SampleFile,Entries,2); Found:=False; I:=0;
  while (not Found) and (I<Entries) do begin
   Inc(I); BlockRead(SampleFile,Entry,16);
   Found:=EqualTag(Entry.Tag,Tag)
  end;
  if not Found then Halt(255);
  Seek(SampleFile,Entry.Offset); SampleLength:=Entry.Length
 end else begin
  Assign(SampleFile,Name); Reset(SampleFile,1); SampleLength:=FileSize(SampleFile)
 end
end;
procedure LoadSample(var Sample:PSample;Name:String);
var Chunk:array[0..2049] of Byte; Remaining:LongInt; N:Word;
begin
 OpenSample(Name); New(Sample); Sample^.Length:=SampleLength;
 if not SharedXms then begin
  Sample^.Offset:=0;
  RXms.Allocate(Sample^.Handle,Word((SampleLength+1023) div 1024))
 end else begin
  Sample^.Offset:=SharedOffset; Sample^.Handle:=SharedHandle;
  Inc(SharedOffset,SampleLength);
  RXms.Resize(SharedHandle,Word((SharedOffset+1023) div 1024))
 end;
 Transfer.SrcHandle:=0; Transfer.SrcOffset:=LongInt(Ptr(Seg(Chunk),Ofs(Chunk)));
 Transfer.DstHandle:=Sample^.Handle; Transfer.DstOffset:=Sample^.Offset;
 Remaining:=SampleLength;
 repeat
  if Remaining<2048 then N:=Word(Remaining) else N:=2048;
  BlockRead(SampleFile,Chunk,N); Chunk[N]:=0;
  Transfer.Count:=((LongInt(N)+1) div 2)*2;
  RXms.MoveBlock(Transfer); Inc(Transfer.DstOffset,Transfer.Count);
  Dec(Remaining,Transfer.Count)
 until Remaining<=0;
 Close(SampleFile)
end;
procedure ReadStream(var Sample:TSample;var Position:LongInt;Count:Word;RepeatMode:Byte);
var Remaining,N:LongInt; Dest:Word;
begin
 Remaining:=Count; Dest:=0;
 Transfer.SrcHandle:=Sample.Handle; Transfer.DstHandle:=0;
 while Remaining>0 do begin
  N:=Sample.Length-Position;
  if Remaining<N then N:=Remaining;
  Transfer.SrcOffset:=Sample.Offset+Position;
  Inc(Position,N);
  if RepeatMode<>0 then Position:=Position mod Sample.Length;
  Transfer.DstOffset:=LongInt(Ptr(Seg(Buffer),Ofs(Buffer)+Dest));
  Inc(Dest,Word(N)); Dec(Remaining,N);
  Transfer.Count:=((N+1) div 2)*2;
  RXms.MoveBlock(Transfer)
 end
end;
begin
 Archived:=False; SharedXms:=False; SharedOffset:=0
end.
