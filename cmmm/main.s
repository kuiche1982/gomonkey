	.section	__TEXT,__text,regular,pure_instructions
	.build_version macos, 14, 0	sdk_version 14, 4
	.globl	_main                           ; -- Begin function main
	.p2align	2
_main:                                  ; @main
	.cfi_startproc
; %bb.0:
	sub	sp, sp, #64
	.cfi_def_cfa_offset 64
	stp	x29, x30, [sp, #48]             ; 16-byte Folded Spill
	add	x29, sp, #48
	.cfi_def_cfa w29, 16
	.cfi_offset w30, -8
	.cfi_offset w29, -16
	mov	w0, #0
	str	w0, [sp, #20]                   ; 4-byte Folded Spill
	stur	wzr, [x29, #-4]
	adrp	x8, l___const.main.msg@PAGE
	add	x8, x8, l___const.main.msg@PAGEOFF
	ldr	x9, [x8]
	add	x1, sp, #24
	str	x1, [sp]                        ; 8-byte Folded Spill
	str	x9, [sp, #24]
	ldur	x8, [x8, #5]
	stur	x8, [x1, #5]
	mov	x2, #13
	str	x2, [sp, #8]                    ; 8-byte Folded Spill
	bl	_write
	ldr	x1, [sp]                        ; 8-byte Folded Reload
	ldr	x2, [sp, #8]                    ; 8-byte Folded Reload
	ldr	w0, [sp, #20]                   ; 4-byte Folded Reload
	; InlineAsm Start
	dmb	nshld
	; InlineAsm End
	bl	_write
	ldr	w0, [sp, #20]                   ; 4-byte Folded Reload
	bl	_exit
	.cfi_endproc
                                        ; -- End function
	.section	__TEXT,__cstring,cstring_literals
l___const.main.msg:                     ; @__const.main.msg
	.asciz	"Hello, ARM!\n"

.subsections_via_symbols
