//
// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information. 
//

.intel_syntax noprefix
#include "unixasmmacros.inc"
#include "asmconstants.h"

#define real4 dword
#define real8 qword

//extern CallDescrWorkerUnwindFrameChainHandler:proc

//
//      EXTERN_C void FastCallFinalizeWorker(Object *obj, PCODE funcPtr);
//
NESTED_ENTRY FastCallFinalizeWorker, _TEXT, CallDescrWorkerUnwindFrameChainHandler
        alloc_stack     0x28     // alloc callee scratch and align the stack
        END_PROLOGUE
        
        //
        // RDI: already contains obj*
        // RSI: address of finalizer method to call
        //

        // !!!!!!!!!
        // NOTE:  you cannot tail call here because we must have the CallDescrWorkerUnwindFrameChainHandler
        //        personality routine on the stack.
        // !!!!!!!!!
        call    rsi
        xor     rax, rax
        
        // epilog
        add     rsp, 0x28
        ret


NESTED_END FastCallFinalizeWorker, _TEXT

//extern "C" void CallDescrWorkerInternal(CallDescrData * pCallDescrData);

NESTED_ENTRY CallDescrWorkerInternal, _TEXT, CallDescrWorkerUnwindFrameChainHandler
        push_nonvol_reg rbx             // save nonvolatile registers
        push_nonvol_reg rbp             // 
        set_frame rbp, 0                // set frame pointer
        lea     rsp, [rsp - 8]          // ensure proper alignment of the rsp

        END_PROLOGUE

        mov     rbx, rdi                // save pCallDescrData in rbx

        mov     ecx, dword ptr [rbx + CallDescrData__numStackSlots]

        and     ecx, ecx
        jz      NoStackArguments

        test    ecx, 1
        jz      StackAligned
        push    rax
StackAligned:

        mov     rsi, [rbx + CallDescrData__pSrc] // set source argument list address
        lea     rsi, [rsi + 8 * rcx]

StackCopyLoop:                          // copy the arguments to stack top-down to carefully probe for sufficient stack space
        sub     rsi, 8
        push    qword ptr [rsi]
        dec     ecx
        jnz     StackCopyLoop
NoStackArguments:
        // All argument registers are loaded regardless of the actual number
        // of arguments.

        mov     rax, [rbx + CallDescrData__pArgumentRegisters] 
        mov     rdi, [rax + 0] 
        mov     rsi, [rax + 8]
        mov     rdx, [rax + 16]
        mov     rcx, [rax + 24]
        mov     r8, [rax + 32]
        mov     r9, [rax + 40]

        // All float argument registers are loaded regardless of the actual number
        // of arguments.

        mov     rax, [rbx + CallDescrData__pFloatArgumentRegisters] 
        and     rax, rax
        jz      NoFloatArguments
        movsd   xmm0, [rax + 0]
        movsd   xmm1, [rax + 16]
        movsd   xmm2, [rax + 32]
        movsd   xmm3, [rax + 48]
        movsd   xmm4, [rax + 64]
        movsd   xmm5, [rax + 80]
        movsd   xmm6, [rax + 96]
        movsd   xmm7, [rax + 112]
NoFloatArguments:        
        call    qword ptr [rbx + CallDescrData__pTarget]     // call target function

        // Save FP return value

        mov     ecx, dword ptr [rbx + CallDescrData__fpReturnSize]
        test    ecx, ecx
        jz      ReturnsInt
        
        cmp     ecx, 4
        je      ReturnsFloat
        cmp     ecx, 8
        je      ReturnsDouble
        // unexpected
        jmp     Epilog

ReturnsInt:
        mov     [rbx+CallDescrData__returnValue], rax

Epilog:
        lea     rsp, 0[rbp]             // deallocate argument list
        pop     rbp                     // restore nonvolatile register
        pop     rbx                     //
        ret

ReturnsFloat:
        movss   real4 ptr [rbx+CallDescrData__returnValue], xmm0
        jmp     Epilog

ReturnsDouble:
        movsd   real8 ptr [rbx+CallDescrData__returnValue], xmm0
        jmp     Epilog

NESTED_END CallDescrWorkerInternal, _TEXT

        
