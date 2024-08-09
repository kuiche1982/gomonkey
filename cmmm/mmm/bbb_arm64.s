#include "textflag.h"

#define DMBnshld WORD $0xd50335bf
#define DMBsy WORD $0xd5033fbf
#define NOP64 WORD $0x1f2003d5; WORD $0x1f2003d5;
#define NOP512 NOP64; NOP64; NOP64; NOP64; NOP64; NOP64; NOP64; NOP64;
#define NOP4096 NOP512; NOP512; NOP512; NOP512; NOP512; NOP512; NOP512; NOP512;
#define NOP16384 NOP4096; NOP4096; NOP4096; NOP4096; NOP4096; NOP4096; NOP4096; NOP4096;

#define protRW $(0x1|0x2|0x10)
#define mProtect $(0x2000000+74)

TEXT ·BBBB(SB),NOSPLIT,$0
    //ADMB nshld
    // d50335bf    	dmb	nshld
    //BYTE $0xd5; BYTE $0x03; BYTE $0x35; BYTE $0xbf
    //BYTE $0xbf; BYTE $0x35; BYTE $0x03; BYTE $0xd5
    DMBsy
    RET

TEXT ·write(SB),NOSPLIT,$24
    DMBsy
    B START
    DMBsy
    NOP16384
START:
    MOVD    mProtect, R16
    MOVD    page+24(FP), R0
    MOVD    pageSize+32(FP), R1
    MOVD    protRW, R2
    SVC     $0x80
    CMP     $0, R0
    BEQ     PROTECT_OK
    CALL    mach_task_self(SB)
    MOVD    target+0(FP), R1
    MOVD    len+16(FP), R2
    MOVD    $0, R3
    MOVD    protRW, R4
    CALL    mach_vm_protect(SB)
    CMP     $0, R0
    BNE     RETURN
PROTECT_OK:
    MOVD    target+0(FP), R0
    MOVD    data+8(FP), R1
    MOVD    len+16(FP), R2
    MOVD    R0, to-24(SP)
    MOVD    R1, from-16(SP)
    MOVD    R2, n-8(SP)
    CALL    runtime·memmove(SB)
    MOVD    mProtect, R16
    MOVD    page+24(FP), R0
    MOVD    pageSize+32(FP), R1
    MOVD    oriProt+40(FP), R2
    SVC     $0x80
    B       RETURN
    NOP16384
RETURN:
    MOVD R0, ret+48(FP)
    RET
