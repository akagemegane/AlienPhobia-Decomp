unit FRecover;
{$G+}{$S+}{$R-}{$Q-}
interface
type
 TScreen=array[1..64000] of Byte;
 PScreen=^TScreen;
 TPalette=array[1..768] of Byte;
 TTag=array[1..8] of Char;
 TEnemy=record
  X,Y,VX,VY,Spare,Rate,Other:Integer;
  Active,Marked,Flag1,Flag2:Byte
 end;
function UpperString(Name:String):String;
procedure LoadBackdrop(Name:String;var Source,Dest:TScreen);
procedure LoadPalette(Name:String;var Palette:TPalette);
procedure OverlayBackdrop(Name:String;var Source,Dest:TScreen);
procedure SpawnEnemy(var Enemy:TEnemy);
function ParseField(Text:String;Key:Char;Hexadecimal:Boolean):Word;
function ReadBlaster(var Address:Word;var IRQ,DMA,HighDMA:Byte):Boolean;
function HexWord(Value:Word):String;
function EqualTag(A,B:TTag):Boolean;
implementation
uses Dos;
function UpperString(Name:String):String;
var I:Integer;
begin
 for I:=1 to Length(Name) do Name[I]:=UpCase(Name[I]);
 UpperString:=Name
end;
procedure LoadBackdrop(Name:String;var Source,Dest:TScreen);
var F:File;
begin
 Assign(F,Name); Reset(F,1);
 BlockRead(F,Source,SizeOf(Source));
 Move(Source,Dest,SizeOf(Source)); Close(F)
end;
procedure LoadPalette(Name:String;var Palette:TPalette);
var F:File of Byte; I:Integer;
begin
 Assign(F,Name); Reset(F);
 for I:=1 to 768 do Read(F,Palette[I]);
 Close(F)
end;
procedure OverlayBackdrop(Name:String;var Source,Dest:TScreen);
var F:File; I:LongInt;
begin
 Assign(F,Name); Reset(F,1);
 BlockRead(F,Source,SizeOf(Source));
 for I:=1 to 64000 do
  if Source[I]<>0 then Dest[I]:=Source[I];
 Close(F)
end;
procedure SpawnEnemy(var Enemy:TEnemy);
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
function ParseField(Text:String;Key:Char;Hexadecimal:Boolean):Word;
var Value,Code:Integer;
begin
 if Pos(Key,Text)=0 then ParseField:=255
 else begin
  Delete(Text,1,Pos(Key,Text));
  Delete(Text,Pos(' ',Text),255);
  if Hexadecimal then Insert('$',Text,1);
  Val(Text,Value,Code);
  if Code=0 then ParseField:=Word(Value) else ParseField:=255
 end
end;
function ReadBlaster(var Address:Word;var IRQ,DMA,HighDMA:Byte):Boolean;
var Text:String;
begin
 Text:=UpperString(GetEnv('BLASTER'));
 Address:=ParseField(Text,'A',True);
 IRQ:=Byte(ParseField(Text,'I',False));
 DMA:=Byte(ParseField(Text,'D',False));
 HighDMA:=Byte(ParseField(Text,'H',False));
 ReadBlaster:=(Text<>'') and (Address<>255) and (IRQ<>255) and (DMA<>255)
end;
function HexWord(Value:Word):String;
const Digits:String[16]='0123456789ABCDEF';
var S:String[4]; I:Integer;
begin
 S:='0000';
 for I:=4 downto 1 do begin
  S[I]:=Digits[(Value and 15)+1]; Value:=Value shr 4
 end;
 HexWord:=S
end;
function EqualTag(A,B:TTag):Boolean;
var I:Integer; Same:Boolean;
begin
 Same:=True;
 for I:=1 to 8 do if A[I]<>B[I] then Same:=False;
 EqualTag:=Same
end;
end.
