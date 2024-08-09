现象：
gomonkey替换monkey后M1平台无法稳定进行mock
怀疑内存边界或指令预读取问题导致， 参考armv8架构手册
尝试1:
https://winddoing.github.io/downloads/arm/DEN0024A_v8_architecture_PG.pdf
// 	A new concept in ARMv8 is the non-temporal load and store. These are the LDNP and STNP
	// instructions that perform a read or write of a pair of register values. They also give a hint to the
	// memory system that caching is not useful for this data. The hint does not prohibit memory
	// system activity such as caching of the address, preload, or gathering. However, it indicates that
	// caching is unlikely to increase performance. A typical use case might be streaming data, but take
	// note that effective use of these instructions requires an approach specific to the
	// microarchitecture.
	// Non-temporal loads and stores relax the memory ordering requirements. In the above case, the
	// LDNP instruction might be observed before the preceding LDR instruction, which can result in
	// reading from an uncertain address in X0.
	// For example:
	// LDR X0, [X3]
	// LDNP X2, X1, [X0] // Xo may not be loaded when the instruction executes!
	// To correct the above, you need an explicit load barrier:
	// LDR X0, [X3]
	// DMB nshld d50335bf
	// LDNP X2, X1, [X0]
   修改/Users/mobvista/gopath/src/github.com/kuiche1982/gomonkey/jmp_arm64.go 未解决问题
	res = append(res, []byte{0xBF, 0x3F, 0x03, 0xD5}...) // DMB nshld; ensure the load succeeded
	res = append(res, []byte{0x4A, 0x03, 0x40, 0xF9}...) // LDR x10, [x26]
	// res = append(res, []byte{0xBF, 0x3F, 0x03, 0xD5}...) // DMB nshld; ensure the load succeeded
	res = append(res, []byte{0x40, 0x01, 0x1F, 0xD6}...) // BR x10

尝试2: 
怀疑替换原函数指针指向数据后， 指令预取（prefetch）未娶到最新的函数指令。 
编辑/Users/mobvista/gopath/src/github.com/kuiche1982/gomonkey/write_darwin_arm64.s
加入DMB nshld指令确定内存写入成功后返回，  未解决问题。

#define DMBnshld WORD $0xd50335bf;

RETURN:
    MOVD R0, ret+48(FP)
    DMBnshld
    RET

尝试3: 
在进行尝试2过程中发现gomonkey/write_darwin_arm64.s write函数部分NOP指令在RET前 未有效执行， 
怀疑作者已经意识到M1有预取指令问题， 进行简单验证， 在write后 sleep 1ms， monkey自带测试能稳定执行
modify_binary_darwin.go
func modifyBinary(target uintptr, bytes []byte) {
	targetPage := pageStart(target)
	res := write(target, PtrOf(bytes), len(bytes), targetPage, syscall.Getpagesize(), syscall.PROT_READ|syscall.PROT_EXEC)
	if res != 0 {
		panic(fmt.Errorf("failed to write memory, code %v", res))
	}
	<-time.After(100 * time.Microsecond)
}
使用ADX代码验证， 问题解决。 

尝试4：
试图加入正确的NOP指令， 去掉<-time.After(100 * time.Microsecond) 临时验证代码
失败， 由于对汇编了解有限， 无法正确配置， 回归到尝试3的解决方案


相关参考资料：
目录cmmm 通过c asm 找到DMB相应的二进制指令，对 jmp_arm64进行修改
目录cmmm/mm2 GOARCH=amd64 golang调用asm函数的例子
目录cmmm/mmm 更改汇编函数， 加入DMB的尝试

https://go.dev/doc/asm
$ cat x.go
package main

func main() {
	println(3)
}

You can redirect the output to a file like this:

 go tool compile -S file.go > file.s
You can disable the optimization with -N:

 go tool compile -S -N file.go
Alternatively, you can use gccgo:

gccgo -S -O0 -masm=intel test.go

$ GOOS=linux GOARCH=amd64 go tool compile -S x.go        # or: go build -gcflags -S x.go
Symbols¶
Some symbols, such as R1 or LR, are predefined and refer to registers. The exact set depends on the architecture.

There are four predeclared symbols that refer to pseudo-registers. These are not real registers, but rather virtual registers maintained by the toolchain, such as a frame pointer. The set of pseudo-registers is the same for all architectures:

FP: Frame pointer: arguments and locals.
PC: Program counter: jumps and branches.
SB: Static base pointer: global symbols.
SP: Stack pointer: the highest address within the local stack frame.

https://pkg.go.dev/cmd/internal/obj/arm64
Unsupported opcodes¶
The assemblers are designed to support the compiler so not all hardware instructions are defined for all architectures: if the compiler doesn't generate it, it might not be there. If you need to use a missing instruction, there are two ways to proceed. One is to update the assembler to support that instruction, which is straightforward but only worthwhile if it's likely the instruction will be used again. Instead, for simple one-off cases, it's possible to use the BYTE and WORD directives to lay down explicit data into the instruction stream within a TEXT. Here's how the 386 runtime defines the 64-bit atomic load function.

// uint64 atomicload64(uint64 volatile* addr);
// so actually
// void atomicload64(uint64 *res, uint64 volatile *addr);
TEXT runtime·atomicload64(SB), NOSPLIT, $0-12
	MOVL	ptr+0(FP), AX
	TESTL	$7, AX
	JZ	2(PC)
	MOVL	0, AX // crash with nil ptr deref
	LEAL	ret_lo+4(FP), BX
	// MOVQ (%EAX), %MM0
	BYTE $0x0f; BYTE $0x6f; BYTE $0x00
	// MOVQ %MM0, 0(%EBX)
	BYTE $0x0f; BYTE $0x7f; BYTE $0x03
	// EMMS
	BYTE $0x0F; BYTE $0x77
	RET


    objdump -S --disassemble a.out > a.dump



    Move large constants to vector registers.

Go asm uses VMOVQ/VMOVD/VMOVS to move 128-bit, 64-bit and 32-bit constants into vector registers, respectively. And for a 128-bit integer, it take two 64-bit operands, for the low and high parts separately.

Examples:

VMOVS $0x11223344, V0
VMOVD $0x1122334455667788, V1
VMOVQ $0x1122334455667788, $0x99aabbccddeeff00, V2   // V2=0x99aabbccddeeff001122334455667788


DMB nshld


To see what gets put in the binary after linking, use go tool objdump:

$ go build -o x.exe x.go
$ go tool objdump -s main.main x.exe


https://go.dev/wiki/GcToolchainTricks   for go 1.x 
The most important step is compiling that file to file.syso (gcc -c -O3 -o file.syso file.S), and put the resulting syso in the package source directory. And then, suppose your assembly function is named Func, you need one stub cmd/asm assembly file to call it:

TEXT ·Func(SB),$0-8 // please set the correct parameter size (8) here
    JMP Func(SB)
then you just declare Func in your package and use it, go build will be able to pick up the syso and link it into the package.

examples 

https://github.com/cloudflare/bn256/blob/01bd7a1fc27c46e06e0f110f02e0c425d392734a/gfp_arm64.s#L102
TEXT ·gfpMul(SB),0,$0-24
	MOVD a+8(FP), R0
	loadBlock(0(R0), R1,R2,R3,R4)
	MOVD b+16(FP), R0
	loadBlock(0(R0), R5,R6,R7,R8)

	mul(R9,R10,R11,R12,R13,R14,R15,R16)
	gfpReduce()

	MOVD c+0(FP), R0
	storeBlock(R1,R2,R3,R4, 0(R0))
	RET

https://github.com/cloudflare/bn256/blob/01bd7a1fc27c46e06e0f110f02e0c425d392734a/gfp_decl.go
// +build amd64,!generic arm64,!generic

package bn256
//go:noescape
func gfpMul(c, a, b *gfP)



//// +build arm64
////go:build main

#include "go_asm.h"
#include "textflag.h"
#include "funcdata.h"
#include "pcdata.h"

//uint64 BBBB(addr uint64);
TEXT ·BBBB(SB), LEAF|NOFRAME|ABIInternal, $0-8
    FUNCDATA        $0, gclocals·g2BeySu+wFnoycgXfElmcg==(SB)
    FUNCDATA        $1, gclocals·g2BeySu+wFnoycgXfElmcg==(SB)
    FUNCDATA        $5, main.BBBB.arginfo1(SB)
    FUNCDATA        $6, main.BBBB.argliveinfo(SB)
    PCDATA  $3, $1
    ADD     $1, R0, R0
    RET     $1

bbb_arm64.s
github.com/agiledragon/gomonkey/v2/test/cmmm/mmm: package using cgo has Go assembly file bbb_arm64.s
always assembled .s files with the Go assembler and .S files with the system assembler,



https://go.dev/play/p/KySqFvCVz_T   but work for i386 only



another example https://github.com/EvilBytecode/Go-Assembly



-- main.go --
package main

import "fmt"

func add(x, y int64) int64
func sub(x, y int64) int64
func mul(x, y int64) int64
func div(x, y int64) int64

func main() {
    fmt.Println("Add:       ", add(10, 5))
    fmt.Println("Subtract:  ", sub(10, 5))
    fmt.Println("Multiply:  ", mul(10, 5))
    fmt.Println("Divide:    ", div(10, 5))
}

-- add.s --
#include "textflag.h"

TEXT ·add(SB), NOSPLIT, $0-24
    MOVQ x+0(FP), BX    
    MOVQ y+8(FP), BP    
    ADDQ BP, BX        
    MOVQ BX, ret+16(FP)
    RET           
-- div.s --
#include "textflag.h"

TEXT ·div(SB), NOSPLIT, $0-24
    MOVQ x+0(FP), AX    
    MOVQ y+8(FP), CX   
    CQO                 
    IDIVQ CX           
    MOVQ AX, ret+16(FP) 
    RET                 
-- mul.s --
#include "textflag.h"

TEXT ·mul(SB), NOSPLIT, $0-24
    MOVQ x+0(FP), BX    
    MOVQ y+8(FP), BP    
    IMULQ BP, BX        
    MOVQ BX, ret+16(FP) 
    RET                 
-- sub.s --
#include "textflag.h"

TEXT ·sub(SB), NOSPLIT, $0-24
    MOVQ x+0(FP), BX    
    MOVQ y+8(FP), BP    
    SUBQ BP, BX         
    MOVQ BX, ret+16(FP)
    RET                 



ARM64¶
R18 is the "platform register", reserved on the Apple platform. To prevent accidental misuse, the register is named R18_PLATFORM. R27 and R28 are reserved by the compiler and linker. R29 is the frame pointer. R30 is the link register.

Instruction modifiers are appended to the instruction following a period. The only modifiers are P (postincrement) and W (preincrement): MOVW.P, MOVW.W

Addressing modes:

R0->16
R0>>16
R0<<16
R0@>16: These are the same as on the 32-bit ARM.
$(8<<12): Left shift the immediate value 8 by 12 bits.
8(R0): Add the value of R0 and 8.
(R2)(R0): The location at R0 plus R2.
R0.UXTB
R0.UXTB<<imm: UXTB: extract an 8-bit value from the low-order bits of R0 and zero-extend it to the size of R0. R0.UXTB<<imm: left shift the result of R0.UXTB by imm bits. The imm value can be 0, 1, 2, 3, or 4. The other extensions include UXTH (16-bit), UXTW (32-bit), and UXTX (64-bit).
R0.SXTB
R0.SXTB<<imm: SXTB: extract an 8-bit value from the low-order bits of R0 and sign-extend it to the size of R0. R0.SXTB<<imm: left shift the result of R0.SXTB by imm bits. The imm value can be 0, 1, 2, 3, or 4. The other extensions include SXTH (16-bit), SXTW (32-bit), and SXTX (64-bit).
(R5, R6): Register pair for LDAXP/LDP/LDXP/STLXP/STP/STP.
Reference: Go ARM64 Assembly Instructions Reference Manual  https://pkg.go.dev/cmd/internal/obj/arm64