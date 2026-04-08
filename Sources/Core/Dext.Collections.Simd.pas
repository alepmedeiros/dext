unit Dext.Collections.Simd;

interface

uses
  System.SysUtils;

type
  TSimdCapability = (scNone, scSSE2, scSSE42, scAVX2, scNEON);

  TDextSimd = class
  private
    class var FCapability: TSimdCapability;
    class constructor Create;
  public
    class property Capability: TSimdCapability read FCapability;
    
    class function IndexOfInt32(Data: Pointer; Count: Integer; Value: Integer): Integer;
    class function IndexOfByte(Data: Pointer; Count: Integer; Value: Byte): Integer;
  end;

implementation

{$IF (defined(CPUX86) or defined(CPUX64)) and defined(MSWINDOWS)}
function HasSSE2: Boolean;
asm
  {$IFDEF CPUX86} push ebx {$ENDIF}
  {$IFDEF CPUX64} push rbx {$ENDIF}
  mov eax, 1
  cpuid
  mov eax, edx
  shr eax, 26
  and eax, 1
  {$IFDEF CPUX86} pop ebx {$ENDIF}
  {$IFDEF CPUX64} pop rbx {$ENDIF}
end;

function HasSSE42: Boolean;
asm
  {$IFDEF CPUX86} push ebx {$ENDIF}
  {$IFDEF CPUX64} push rbx {$ENDIF}
  mov eax, 1
  cpuid
  mov eax, ecx
  shr eax, 20
  and eax, 1
  {$IFDEF CPUX86} pop ebx {$ENDIF}
  {$IFDEF CPUX64} pop rbx {$ENDIF}
end;

function HasAVX2: Boolean;
asm
  {$IFDEF CPUX86} push ebx {$ENDIF}
  {$IFDEF CPUX64} push rbx {$ENDIF}
  mov eax, 7
  xor ecx, ecx
  cpuid
  mov eax, ebx
  shr eax, 5
  and eax, 1
  {$IFDEF CPUX86} pop ebx {$ENDIF}
  {$IFDEF CPUX64} pop rbx {$ENDIF}
end;
{$ELSE}
function HasSSE2: Boolean; begin Result := False; end;
function HasSSE42: Boolean; begin Result := False; end;
function HasAVX2: Boolean; begin Result := False; end;
{$ENDIF}

{$IF (defined(CPUX86) or defined(CPUX64)) and defined(MSWINDOWS)}

{$IFDEF CPUX86}
function IndexOfInt32_SSE2_32(Data: Pointer; Count: Integer; Value: Integer): Integer;
asm
  // EAX = Data, EDX = Count, ECX = Value
  test eax, eax
  jz @NotFound
  test edx, edx
  jle @NotFound

  push ebx
  push edi
  mov edi, eax
  mov ebx, edx

  // broadcast ECX to XMM0
  movd xmm0, ecx
  pshufd xmm0, xmm0, 0
  
  mov dword ptr [esp-4], ecx // Save original value temp

  xor eax, eax // offset in elements

@Loop:
  cmp ebx, 4
  jl @Scalar

  movdqu xmm1, [edi + eax*4]
  pcmpeqd xmm1, xmm0
  pmovmskb edx, xmm1
  test edx, edx
  jnz @FoundVector

  add eax, 4
  sub ebx, 4
  jmp @Loop

@FoundVector:
  bsf edx, edx
  shr edx, 2
  add eax, edx
  jmp @Done

@Scalar:
  test ebx, ebx
  jz @NotFound2
  mov ecx, dword ptr [esp-4]
  cmp dword ptr [edi + eax*4], ecx
  je @Done
  inc eax
  dec ebx
  jmp @Scalar

@NotFound2:
@NotFound:
  mov eax, -1
@Done:
  pop edi
  pop ebx
end;

function IndexOfByte_SSE2_32(Data: Pointer; Count: Integer; Value: Byte): Integer;
asm
  // EAX = Data, EDX = Count, CL = Value
  test eax, eax
  jz @NotFound
  test edx, edx
  jle @NotFound

  push ebx
  push edi
  mov edi, eax
  mov ebx, edx

  // broadcast Value (CL) to XMM0
  movzx ecx, cl
  movd xmm0, ecx
  punpcklbw xmm0, xmm0
  punpcklwd xmm0, xmm0
  pshufd xmm0, xmm0, 0

  mov byte ptr [esp-4], cl

  xor eax, eax // i = 0

@Loop:
  cmp ebx, 16
  jl @Scalar

  movdqu xmm1, [edi + eax]
  pcmpeqb xmm1, xmm0
  pmovmskb edx, xmm1
  test edx, edx
  jnz @FoundVector

  add eax, 16
  sub ebx, 16
  jmp @Loop

@FoundVector:
  bsf edx, edx
  add eax, edx
  jmp @Done

@Scalar:
  test ebx, ebx
  jz @NotFound2
  mov cl, byte ptr [esp-4]
  cmp byte ptr [edi + eax], cl
  je @Done
  inc eax
  dec ebx
  jmp @Scalar

@NotFound2:
@NotFound:
  mov eax, -1
@Done:
  pop edi
  pop ebx
end;
{$ENDIF}

{$IFDEF CPUX64}
function IndexOfInt32_SSE2_64(Data: Pointer; Count: Integer; Value: Integer): Integer;
// RCX = Data, EDX = Count, R8D = Value
asm
  test rcx, rcx
  jz @NotFound
  test edx, edx
  jle @NotFound

  movd xmm0, r8d
  pshufd xmm0, xmm0, 0

  mov r9d, r8d 

  xor rax, rax 

@Loop:
  cmp edx, 4
  jl @Scalar

  movdqu xmm1, [rcx + rax*4]
  pcmpeqd xmm1, xmm0
  pmovmskb r8d, xmm1
  test r8d, r8d
  jnz @FoundVector

  add rax, 4
  sub edx, 4
  jmp @Loop

@FoundVector:
  bsf r8d, r8d
  shr r8d, 2 
  add rax, r8
  jmp @Done

@Scalar:
  test edx, edx
  jz @NotFound
  cmp dword ptr [rcx + rax*4], r9d
  je @Done
  inc rax
  dec edx
  jmp @Scalar

@NotFound:
  mov rax, -1
@Done:
end;

function IndexOfByte_SSE2_64(Data: Pointer; Count: Integer; Value: Byte): Integer;
// RCX = Data, EDX = Count, R8B = Value
asm
  test rcx, rcx
  jz @NotFound
  test edx, edx
  jle @NotFound

  movzx r8d, r8b
  movd xmm0, r8d
  punpcklbw xmm0, xmm0
  punpcklwd xmm0, xmm0
  pshufd xmm0, xmm0, 0

  mov r9b, r8b

  xor rax, rax

@Loop:
  cmp edx, 16
  jl @Scalar

  movdqu xmm1, [rcx + rax]
  pcmpeqb xmm1, xmm0
  pmovmskb r8d, xmm1
  test r8d, r8d
  jnz @FoundVector

  add rax, 16
  sub edx, 16
  jmp @Loop

@FoundVector:
  bsf r8d, r8d
  add rax, r8
  jmp @Done

@Scalar:
  test edx, edx
  jz @NotFound
  cmp byte ptr [rcx + rax], r9b
  je @Done
  inc rax
  dec edx
  jmp @Scalar

@NotFound:
  mov rax, -1
@Done:
end;
{$ENDIF}

{$ENDIF}

function IndexOfInt32_Pascal(Data: Pointer; Count: Integer; Value: Integer): Integer;
var
  P: PInteger;
  I: Integer;
begin
  P := PInteger(Data);
  for I := 0 to Count - 1 do
  begin
    if P^ = Value then Exit(I);
    Inc(P);
  end;
  Result := -1;
end;

function IndexOfByte_Pascal(Data: Pointer; Count: Integer; Value: Byte): Integer;
var
  P: PByte;
  I: Integer;
begin
  P := PByte(Data);
  for I := 0 to Count - 1 do
  begin
    if P^ = Value then Exit(I);
    Inc(P);
  end;
  Result := -1;
end;

class constructor TDextSimd.Create;
begin
  FCapability := scNone;
  
  if HasAVX2 then
    FCapability := scAVX2
  else if HasSSE42 then
    FCapability := scSSE42
  else if HasSSE2 then
    FCapability := scSSE2;
end;

class function TDextSimd.IndexOfInt32(Data: Pointer; Count: Integer; Value: Integer): Integer;
begin
  {$IFDEF MSWINDOWS}
  if FCapability >= scSSE2 then
  begin
    {$IFDEF CPUX64}
    Result := IndexOfInt32_SSE2_64(Data, Count, Value);
    {$ELSE}
    Result := IndexOfInt32_SSE2_32(Data, Count, Value);
    {$ENDIF}
  end
  else
  {$ENDIF}
  begin
    Result := IndexOfInt32_Pascal(Data, Count, Value);
  end;
end;

class function TDextSimd.IndexOfByte(Data: Pointer; Count: Integer; Value: Byte): Integer;
begin
  {$IFDEF MSWINDOWS}
  if FCapability >= scSSE2 then
  begin
    {$IFDEF CPUX64}
    Result := IndexOfByte_SSE2_64(Data, Count, Value);
    {$ELSE}
    Result := IndexOfByte_SSE2_32(Data, Count, Value);
    {$ENDIF}
  end
  else
  {$ENDIF}
  begin
    Result := IndexOfByte_Pascal(Data, Count, Value);
  end;
end;

end.
