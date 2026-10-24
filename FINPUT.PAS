unit FInput;
{$G-}{$S+}{$F+}
interface
uses Dos;
type TPalette=array[1..768] of Byte;
 TScreen=array[1..64000] of Byte;
var SavedKeyboardExit,SavedKeyboardVector:Pointer;
 Palette:^TPalette; PaletteIndex:Word;
 SourcePicture,DestPicture:^TScreen;
 ExitKey,K1,LeftKey,K2,UpKey,K3,RightKey,K4,FireKey:Boolean;
 CurrentScan,LastScan:Byte;
procedure SetVideoMode(Mode:Byte);
procedure RestoreKeyboard;
function NumberText(Value:LongInt):String;
procedure WritePalette;
procedure CopyRect(X1,Y1,X2,Y2:Integer);
procedure InstallKeyboard;
procedure ProcessScan(Scan:Byte);
implementation
procedure SetVideoMode(Mode:Byte);
begin
 asm
  mov ah,0
  mov al,Mode
  int 10h
 end
end;
procedure RestoreKeyboard;
begin ExitProc:=SavedKeyboardExit; SetIntVec(9,SavedKeyboardVector) end;
function NumberText(Value:LongInt):String;
var Temp:String[11];
begin Str(Value,Temp); NumberText:=Temp end;
procedure WritePalette;
begin Port[$3c8]:=1; for PaletteIndex:=4 to 768 do Port[$3c9]:=Palette^[PaletteIndex] end;
procedure CopyRect(X1,Y1,X2,Y2:Integer);
var Unused,Row:Integer;
begin
 for Row:=Y1 to Y2 do
  Move(SourcePicture^[320*Row+X1],DestPicture^[320*Row+X1],X2-X1)
end;
procedure ProcessScan(Scan:Byte);
begin
 CurrentScan:=Scan;
 if CurrentScan<>LastScan then begin
  LastScan:=CurrentScan;
  case Scan of
   1..127:case Scan of
    $1e:K1:=True; $11:K2:=True; $20:K3:=True; $0f:K4:=True;
    $4b:LeftKey:=True; $48:UpKey:=True; $4d:RightKey:=True;
    $1c:FireKey:=True; $46:ExitKey:=True
   end;
   128..255:case Scan of
    $9e:K1:=False; $91:K2:=False; $a0:K3:=False; $8f:K4:=False;
    $cb:LeftKey:=False; $c8:UpKey:=False; $cd:RightKey:=False; $9c:FireKey:=False
   end
  end
 end
end;
procedure KeyboardHandler; interrupt;
var Scan:Byte;
begin
 asm
  in al,$60
  mov Scan,al
  in al,$61
  mov ah,al
  or al,$80
  out $61,al
  xchg al,ah
  out $61,al
  mov al,$20
  out $20,al
 end;
 ProcessScan(Scan)
end;
procedure InstallKeyboard;
begin
 SavedKeyboardExit:=ExitProc; ExitProc:=@RestoreKeyboard;
 GetIntVec(9,SavedKeyboardVector); SetIntVec(9,@KeyboardHandler);
 ExitKey:=False; K1:=False; LeftKey:=False; K2:=False; UpKey:=False;
 K3:=False; RightKey:=False; K4:=False; FireKey:=False
end;
begin
end.
