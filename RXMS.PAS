unit RXms;
{$G-}{$S+}{$F+}
interface
var Entry:Pointer;
type TMove=record Count:LongInt; SrcHandle:Word; SrcOffset:LongInt; DstHandle:Word; DstOffset:LongInt end;
function Available:Boolean;
procedure Initialize;
function FreeKB:Word;
procedure Allocate(var Handle:Word;Size:Word);
procedure Resize(Handle,Size:Word);
procedure MoveBlock(var Descriptor:TMove);
implementation
function Available:Boolean; assembler;
asm
 mov ax,$4300
 int $2f
 cmp al,$80
 jne @No
 mov al,1
 jmp @Done
@No:
 mov al,0
@Done:
end;
procedure Initialize; assembler;
asm
 mov ax,$4310
 int $2f
 mov word ptr Entry,bx
 mov word ptr Entry+2,es
end;
function FreeKB:Word; assembler;
asm
 mov ah,8
 call dword ptr Entry
 mov ax,dx
end;
procedure Allocate(var Handle:Word;Size:Word);
begin
 asm
  mov ah,9
  mov dx,Size
  call dword ptr Entry
  les di,Handle
  mov es:[di],dx
 end
end;
procedure Resize(Handle,Size:Word);
begin
 asm
  mov ah,$0f
  mov bx,Size
  mov dx,Handle
  call dword ptr Entry
 end
end;
procedure MoveBlock(var Descriptor:TMove);
begin
 asm
  push ds
  mov ah,$0b
  lds si,Descriptor
  call dword ptr Entry
  pop ds
 end
end;
begin
end.
