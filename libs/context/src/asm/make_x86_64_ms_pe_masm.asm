
;           Copyright Oliver Kowalke 2009.
;  Distributed under the Boost Software License, Version 1.0.
;     (See accompanying file LICENSE_1_0.txt or copy at
;           http://www.boost.org/LICENSE_1_0.txt)

;  ----------------------------------------------------------------------------------
;  |    0    |    1    |    2    |    3    |    4     |    5    |    6    |    7    |
;  ----------------------------------------------------------------------------------
;  |   0x0   |   0x4   |   0x8   |   0xc   |   0x10   |   0x14  |   0x18  |   0x1c  |
;  ----------------------------------------------------------------------------------
;  |        R12        |         R13       |         R14        |        R15        |
;  ----------------------------------------------------------------------------------
;  ----------------------------------------------------------------------------------
;  |    8    |    9    |   10    |   11    |    12    |    13   |    14   |    15   |
;  ----------------------------------------------------------------------------------
;  |   0x20  |   0x24  |   0x28  |  0x2c   |   0x30   |   0x34  |   0x38  |   0x3c  |
;  ----------------------------------------------------------------------------------
;  |        RDI        |        RSI        |         RBX        |        RBP        |
;  ----------------------------------------------------------------------------------
;  ----------------------------------------------------------------------------------
;  |    16   |    17   |    18   |    19   |                                        |
;  ----------------------------------------------------------------------------------
;  |   0x40  |   0x44  |   0x48  |   0x4c  |                                        |
;  ----------------------------------------------------------------------------------
;  |        RSP        |        RIP        |                                        |
;  ----------------------------------------------------------------------------------
;  ----------------------------------------------------------------------------------
;  |    20   |    21   |    22   |    23   |    24    |    25   |                   |
;  ----------------------------------------------------------------------------------
;  |   0x50  |   0x54  |   0x58  |   0x5c  |   0x60   |   0x64  |                   |
;  ----------------------------------------------------------------------------------
;  |        sp         |       size        |        limit       |                   |
;  ----------------------------------------------------------------------------------
;  ----------------------------------------------------------------------------------
;  |    26   |   27    |                                                            |
;  ----------------------------------------------------------------------------------
;  |   0x68  |   0x6c  |                                                            |
;  ----------------------------------------------------------------------------------
;  |      fbr_strg     |                                                            |
;  ----------------------------------------------------------------------------------
;  ----------------------------------------------------------------------------------
;  |    28   |   29    |    30   |    31   |                                        |
;  ----------------------------------------------------------------------------------
;  |   0x70  |   0x74  |   0x78  |   0x7c  |                                        |
;  ----------------------------------------------------------------------------------
;  | fc_mxcsr|fc_x87_cw|     <padding>     |                                        |
;  ----------------------------------------------------------------------------------
;  ----------------------------------------------------------------------------------
;  |    32    |   33   |   34    |   35    |   36     |   37    |    38   |    39   |
;  ----------------------------------------------------------------------------------
;  |   0x80   |  0x84  |  0x88   |  0x8c   |   0x90   |   0x94  |   0x98  |   0x9c  |
;  ----------------------------------------------------------------------------------
;  |                  XMM6                 |                   XMM7                 |
;  ----------------------------------------------------------------------------------
;  ----------------------------------------------------------------------------------
;  |    40    |   41   |   42    |   43    |    44    |   45    |    46   |    47   |
;  ----------------------------------------------------------------------------------
;  |   0x100  |  0x104  |  0x108  |  0x10c |   0x110  |  0x114  |  0x118  |  0x11c  |
;  ----------------------------------------------------------------------------------
;  |                  XMM8                 |                   XMM9                 |
;  ----------------------------------------------------------------------------------
;  ----------------------------------------------------------------------------------
;  |    48    |   49   |   50    |   51    |    52    |   53    |    54   |    55   |
;  ----------------------------------------------------------------------------------
;  |   0x120  |  0x124 |  0x128  |  0x12c  |   0x130  |  0x134  |   0x138 |   0x13c |
;  ----------------------------------------------------------------------------------
;  |                 XMM10                 |                  XMM11                 |
;  ----------------------------------------------------------------------------------
;  ----------------------------------------------------------------------------------
;  |    56    |   57   |   58    |   59    |    60   |    61   |    62    |    63   |
;  ----------------------------------------------------------------------------------
;  |  0x140  |  0x144  |  0x148  |  0x14c  |   0x150  |  0x154 |   0x158  |   0x15c |
;  ----------------------------------------------------------------------------------
;  |                 XMM12                 |                  XMM13                 |
;  ----------------------------------------------------------------------------------
;  ----------------------------------------------------------------------------------
;  |    64    |   65   |   66    |   67    |    68    |   69    |    70   |    71   |
;  ----------------------------------------------------------------------------------
;  |  0x160  |  0x164  |  0x168  |  0x16c  |   0x170  |  0x174  |  0x178  |   0x17c |
;  ----------------------------------------------------------------------------------
;  |                 XMM14                 |                  XMM15                 |
;  ----------------------------------------------------------------------------------

EXTERN  _exit:PROC            ; standard C library function
EXTERN  align_stack:PROC      ; stack alignment
EXTERN  seh_fcontext:PROC     ; exception handler
.code

make_fcontext PROC EXPORT FRAME  ; generate function table entry in .pdata and unwind information in
    .endprolog                   ; .xdata for a function's structured exception handling unwind behavior

    push rbp                     ; save previous frame pointer; get the stack 16 byte aligned
    mov  rbp,        rsp         ; set RBP to RSP
    sub  rsp,        040h        ; allocate stack space (contains shadow space for subroutines)

    mov  [rbp-08h],  r8          ; save 3. arg of make_fcontext, pointer to context function
    mov  [rbp-010h], rdx         ; save 2. arg of make_fcontext, context stack size
    mov  [rbp-018h], rcx         ; save 1. arg of make_fcontext, pointer to context stack (base)
    lea  rcx,        [rcx-0180h] ; reserve space for fcontext_t at top of context stack
    call align_stack             ; align context stack, RAX contains address at 16 byte boundary
                                 ; == pointer to fcontext_t and address of context stack

    mov  r8,         [rbp-08h]   ; restore pointer to context function
    mov  rdx,        [rbp-010h]  ; restore context stack size
    mov  rcx,        [rbp-018h]  ; restore pointer to context stack (base)

    mov  [rax+048h], r8          ; save address of context function in fcontext_t
    mov  [rax+058h], rdx         ; save context stack size in fcontext_t
    mov  [rax+050h], rcx         ; save address of context stack pointer (base) in fcontext_t

    neg  rdx                     ; negate stack size for LEA instruction (== substraction)
    lea  rcx,        [rcx+rdx]   ; compute bottom address of context stack (limit)
    mov  [rax+060h], rcx         ; save bottom address of context stack (limit) in fcontext_t

    stmxcsr [rax+070h]           ; save MMX control and status word
    fnstcw  [rax+074h]           ; save x87 control word

    lea  rdx,        [rax-028h]  ; reserve 32byte shadow space + return address on stack, (RSP - 0x8) % 16 == 0
    mov  [rax+040h], rdx         ; save address in RDX as stack pointer for context function

    lea  rcx,        finish      ; compute abs address of label finish
    mov  [rdx],      rcx         ; save address of finish as return address for context function
                                 ; entered after context function returns

    add  rsp,        040h        ; deallocate shadow space
    pop  rbp                     ; restore previous frame pointer

    ret

finish:
    ; RSP points to same address as RSP on entry of context function + 0x8
    xor   rcx,       rcx         ; exit code is zero
    call  _exit                  ; exit application
    hlt
make_fcontext ENDP
END
