/*-
 * Copyright (c) 2003 Peter Wemm.
 * Copyright (c) 1993 The Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $FreeBSD$
 */

#include "opt_ddb.h"

#include <machine/asmacros.h>
#include <machine/specialreg.h>
#include <machine/pmap.h>

#include "assym.inc"

	.text

/* Address: %rdi */
ENTRY(pagezero_std)
	PUSH_FRAME_POINTER
	movq	$PAGE_SIZE/8,%rcx
	xorl	%eax,%eax
	rep
	stosq
	POP_FRAME_POINTER
	ret
END(pagezero_std)

ENTRY(pagezero_erms)
	PUSH_FRAME_POINTER
	movq	$PAGE_SIZE,%rcx
	xorl	%eax,%eax
	rep
	stosb
	POP_FRAME_POINTER
	ret
END(pagezero_erms)

/*
 * pagecopy(%rdi=from, %rsi=to)
 */
ENTRY(pagecopy)
	PUSH_FRAME_POINTER
	movq	$PAGE_SIZE/8,%rcx
	movq	%rdi,%r9
	movq	%rsi,%rdi
	movq	%r9,%rsi
	rep
	movsq
	POP_FRAME_POINTER
	ret
END(pagecopy)

/* Address: %rdi */
ENTRY(sse2_pagezero)
	PUSH_FRAME_POINTER
	movq	$-PAGE_SIZE,%rdx
	subq	%rdx,%rdi
	xorl	%eax,%eax
	jmp	1f
	/*
	 * The loop takes 29 bytes.  Ensure that it doesn't cross a 32-byte
	 * cache line.
	 */
	.p2align 5,0x90
1:
	movnti	%rax,(%rdi,%rdx)
	movnti	%rax,8(%rdi,%rdx)
	movnti	%rax,16(%rdi,%rdx)
	movnti	%rax,24(%rdi,%rdx)
	addq	$32,%rdx
	jne	1b
	sfence
	POP_FRAME_POINTER
	ret
END(sse2_pagezero)

/*
 * memmove(dst, src, cnt)
 *         rdi, rsi, rdx
 * Adapted from bcopy written by:
 *  ws@tools.de     (Wolfgang Solfrank, TooLs GmbH) +49-228-985800
 */
ENTRY(memmove_std)
	PUSH_FRAME_POINTER
	movq	%rdi,%r9
	movq	%rdx,%rcx

	movq	%rdi,%rax
	subq	%rsi,%rax
	cmpq	%rcx,%rax			/* overlapping && src < dst? */
	jb	1f

	shrq	$3,%rcx				/* copy by 64-bit words */
	rep
	movsq
	movq	%rdx,%rcx
	andq	$7,%rcx				/* any bytes left? */
	jne	2f
	movq	%r9,%rax
	POP_FRAME_POINTER
	ret
2:
	rep
	movsb
	movq	%r9,%rax
	POP_FRAME_POINTER
	ret

	/* ALIGN_TEXT */
1:
	addq	%rcx,%rdi			/* copy backwards */
	addq	%rcx,%rsi
	decq	%rdi
	decq	%rsi
	andq	$7,%rcx				/* any fractional bytes? */
	std
	rep
	movsb
	movq	%rdx,%rcx			/* copy remainder by 32-bit words */
	shrq	$3,%rcx
	subq	$7,%rsi
	subq	$7,%rdi
	rep
	movsq
	cld
	movq	%r9,%rax
	POP_FRAME_POINTER
	ret
END(memmove_std)

ENTRY(memmove_erms)
	PUSH_FRAME_POINTER
	movq	%rdi,%r9
	movq	%rdx,%rcx

	movq	%rdi,%rax
	subq	%rsi,%rax
	cmpq	%rcx,%rax			/* overlapping && src < dst? */
	jb	1f

	rep
	movsb
	movq	%r9,%rax
	POP_FRAME_POINTER
	ret

1:
	addq	%rcx,%rdi			/* copy backwards */
	addq	%rcx,%rsi
	decq	%rdi
	decq	%rsi
	std
	rep
	movsb
	cld
	movq	%r9,%rax
	POP_FRAME_POINTER
	ret
END(memmove_erms)

/*
 * memcpy(dst, src, len)
 *        rdi, rsi, rdx
 *
 * Note: memcpy does not support overlapping copies
 */
ENTRY(memcpy_std)
	PUSH_FRAME_POINTER
	movq	%rdi,%rax
	movq	%rdx,%rcx
	shrq	$3,%rcx				/* copy by 64-bit words */
	rep
	movsq
	movq	%rdx,%rcx
	andq	$7,%rcx				/* any bytes left? */
	jne	1f
	POP_FRAME_POINTER
	ret
1:
	rep
	movsb
	POP_FRAME_POINTER
	ret
END(memcpy_std)

ENTRY(memcpy_erms)
	PUSH_FRAME_POINTER
	movq	%rdi,%rax
	movq	%rdx,%rcx
	rep
	movsb
	POP_FRAME_POINTER
	ret
END(memcpy_erms)

/*
 * memset(dst, c,   len)
 *        rdi, rsi, rdx
 */
ENTRY(memset_std)
	PUSH_FRAME_POINTER
	movq	%rdi,%r9
	movq	%rdx,%rcx
	movzbq	%sil,%r8
	movabs	$0x0101010101010101,%rax
	imulq	%r8,%rax
	shrq	$3,%rcx
	rep
	stosq
	movq	%rdx,%rcx
	andq	$7,%rcx
	jne	1f
	movq	%r9,%rax
	POP_FRAME_POINTER
	ret
1:
	rep
	stosb
	movq	%r9,%rax
	POP_FRAME_POINTER
	ret
END(memset_std)

ENTRY(memset_erms)
	PUSH_FRAME_POINTER
	movq	%rdi,%r9
	movq	%rdx,%rcx
	movb	%sil,%al
	rep
	stosb
	movq	%r9,%rax
	POP_FRAME_POINTER
	ret
END(memset_erms)

/* fillw(pat, base, cnt) */
/*       %rdi,%rsi, %rdx */
ENTRY(fillw)
	PUSH_FRAME_POINTER
	movq	%rdi,%rax
	movq	%rsi,%rdi
	movq	%rdx,%rcx
	rep
	stosw
	POP_FRAME_POINTER
	ret
END(fillw)

/*****************************************************************************/
/* copyout and fubyte family                                                 */
/*****************************************************************************/
/*
 * Access user memory from inside the kernel. These routines should be
 * the only places that do this.
 *
 * These routines set curpcb->pcb_onfault for the time they execute. When a
 * protection violation occurs inside the functions, the trap handler
 * returns to *curpcb->pcb_onfault instead of the function.
 */

/*
 * copyout(from_kernel, to_user, len)
 *         %rdi,        %rsi,    %rdx
 */
ENTRY(copyout_nosmap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rax
	movq	$copyout_fault,PCB_ONFAULT(%rax)
	testq	%rdx,%rdx			/* anything to do? */
	jz	done_copyout

	/*
	 * Check explicitly for non-user addresses.  This check is essential
	 * because it prevents usermode from writing into the kernel.  We do
	 * not verify anywhere else that the user did not specify a rogue
	 * address.
	 */
	/*
	 * First, prevent address wrapping.
	 */
	movq	%rsi,%rax
	addq	%rdx,%rax
	jc	copyout_fault
/*
 * XXX STOP USING VM_MAXUSER_ADDRESS.
 * It is an end address, not a max, so every time it is used correctly it
 * looks like there is an off by one error, and of course it caused an off
 * by one error in several places.
 */
	movq	$VM_MAXUSER_ADDRESS,%rcx
	cmpq	%rcx,%rax
	ja	copyout_fault

	xchgq	%rdi,%rsi
	/* bcopy(%rsi, %rdi, %rdx) */
	movq	%rdx,%rcx

	shrq	$3,%rcx
	rep
	movsq
	movb	%dl,%cl
	andb	$7,%cl
	je	done_copyout
	rep
	movsb

	jmp	done_copyout
END(copyout_nosmap)

ENTRY(copyout_smap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rax
	/* Trap entry clears PSL.AC */
	movq	$copyout_fault,PCB_ONFAULT(%rax)
	testq	%rdx,%rdx			/* anything to do? */
	jz	done_copyout

	/*
	 * Check explicitly for non-user addresses.  If 486 write protection
	 * is being used, this check is essential because we are in kernel
	 * mode so the h/w does not provide any protection against writing
	 * kernel addresses.
	 */

	/*
	 * First, prevent address wrapping.
	 */
	movq	%rsi,%rax
	addq	%rdx,%rax
	jc	copyout_fault
/*
 * XXX STOP USING VM_MAXUSER_ADDRESS.
 * It is an end address, not a max, so every time it is used correctly it
 * looks like there is an off by one error, and of course it caused an off
 * by one error in several places.
 */
	movq	$VM_MAXUSER_ADDRESS,%rcx
	cmpq	%rcx,%rax
	ja	copyout_fault

	xchgq	%rdi,%rsi
	/* bcopy(%rsi, %rdi, %rdx) */
	movq	%rdx,%rcx

	shrq	$3,%rcx
	stac
	rep
	movsq
	movb	%dl,%cl
	andb	$7,%cl
	je	1f
	rep
	movsb
1:	clac

done_copyout:
	xorl	%eax,%eax
	movq	PCPU(CURPCB),%rdx
	movq	%rax,PCB_ONFAULT(%rdx)
	POP_FRAME_POINTER
	ret

	ALIGN_TEXT
copyout_fault:
	movq	PCPU(CURPCB),%rdx
	movq	$0,PCB_ONFAULT(%rdx)
	movq	$EFAULT,%rax
	POP_FRAME_POINTER
	ret
END(copyout_smap)

/*
 * copyin(from_user, to_kernel, len)
 *        %rdi,      %rsi,      %rdx
 */
ENTRY(copyin_nosmap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rax
	movq	$copyin_fault,PCB_ONFAULT(%rax)
	testq	%rdx,%rdx			/* anything to do? */
	jz	done_copyin

	/*
	 * make sure address is valid
	 */
	movq	%rdi,%rax
	addq	%rdx,%rax
	jc	copyin_fault
	movq	$VM_MAXUSER_ADDRESS,%rcx
	cmpq	%rcx,%rax
	ja	copyin_fault

	xchgq	%rdi,%rsi
	movq	%rdx,%rcx
	movb	%cl,%al
	shrq	$3,%rcx				/* copy longword-wise */
	rep
	movsq
	movb	%al,%cl
	andb	$7,%cl				/* copy remaining bytes */
	je	done_copyin
	rep
	movsb

	jmp	done_copyin
END(copyin_nosmap)

ENTRY(copyin_smap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rax
	movq	$copyin_fault,PCB_ONFAULT(%rax)
	testq	%rdx,%rdx			/* anything to do? */
	jz	done_copyin

	/*
	 * make sure address is valid
	 */
	movq	%rdi,%rax
	addq	%rdx,%rax
	jc	copyin_fault
	movq	$VM_MAXUSER_ADDRESS,%rcx
	cmpq	%rcx,%rax
	ja	copyin_fault

	xchgq	%rdi,%rsi
	movq	%rdx,%rcx
	movb	%cl,%al
	shrq	$3,%rcx				/* copy longword-wise */
	stac
	rep
	movsq
	movb	%al,%cl
	andb	$7,%cl				/* copy remaining bytes */
	je	1f
	rep
	movsb
1:	clac

done_copyin:
	xorl	%eax,%eax
	movq	PCPU(CURPCB),%rdx
	movq	%rax,PCB_ONFAULT(%rdx)
	POP_FRAME_POINTER
	ret
END(copyin_smap)

	ALIGN_TEXT
copyin_fault:
	movq	PCPU(CURPCB),%rdx
	movq	$0,PCB_ONFAULT(%rdx)
	movq	$EFAULT,%rax
	POP_FRAME_POINTER
	ret

/*
 * casueword32.  Compare and set user integer.  Returns -1 on fault,
 *        0 if access was successful.  Old value is written to *oldp.
 *        dst = %rdi, old = %esi, oldp = %rdx, new = %ecx
 */
ENTRY(casueword32_nosmap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%r8
	movq	$fusufault,PCB_ONFAULT(%r8)

	movq	$VM_MAXUSER_ADDRESS-4,%rax
	cmpq	%rax,%rdi			/* verify address is valid */
	ja	fusufault

	movl	%esi,%eax			/* old */
#ifdef SMP
	lock
#endif
	cmpxchgl %ecx,(%rdi)			/* new = %ecx */

	/*
	 * The old value is in %eax.  If the store succeeded it will be the
	 * value we expected (old) from before the store, otherwise it will
	 * be the current value.  Save %eax into %esi to prepare the return
	 * value.
	 */
	movl	%eax,%esi
	xorl	%eax,%eax
	movq	%rax,PCB_ONFAULT(%r8)

	/*
	 * Access the oldp after the pcb_onfault is cleared, to correctly
	 * catch corrupted pointer.
	 */
	movl	%esi,(%rdx)			/* oldp = %rdx */
	POP_FRAME_POINTER
	ret
END(casueword32_nosmap)

ENTRY(casueword32_smap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%r8
	movq	$fusufault,PCB_ONFAULT(%r8)

	movq	$VM_MAXUSER_ADDRESS-4,%rax
	cmpq	%rax,%rdi			/* verify address is valid */
	ja	fusufault

	movl	%esi,%eax			/* old */
	stac
#ifdef SMP
	lock
#endif
	cmpxchgl %ecx,(%rdi)			/* new = %ecx */
	clac

	/*
	 * The old value is in %eax.  If the store succeeded it will be the
	 * value we expected (old) from before the store, otherwise it will
	 * be the current value.  Save %eax into %esi to prepare the return
	 * value.
	 */
	movl	%eax,%esi
	xorl	%eax,%eax
	movq	%rax,PCB_ONFAULT(%r8)

	/*
	 * Access the oldp after the pcb_onfault is cleared, to correctly
	 * catch corrupted pointer.
	 */
	movl	%esi,(%rdx)			/* oldp = %rdx */
	POP_FRAME_POINTER
	ret
END(casueword32_smap)

/*
 * casueword.  Compare and set user long.  Returns -1 on fault,
 *        0 if access was successful.  Old value is written to *oldp.
 *        dst = %rdi, old = %rsi, oldp = %rdx, new = %rcx
 */
ENTRY(casueword_nosmap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%r8
	movq	$fusufault,PCB_ONFAULT(%r8)

	movq	$VM_MAXUSER_ADDRESS-4,%rax
	cmpq	%rax,%rdi			/* verify address is valid */
	ja	fusufault

	movq	%rsi,%rax			/* old */
#ifdef SMP
	lock
#endif
	cmpxchgq %rcx,(%rdi)			/* new = %rcx */

	/*
	 * The old value is in %rax.  If the store succeeded it will be the
	 * value we expected (old) from before the store, otherwise it will
	 * be the current value.
	 */
	movq	%rax,%rsi
	xorl	%eax,%eax
	movq	%rax,PCB_ONFAULT(%r8)
	movq	%rsi,(%rdx)
	POP_FRAME_POINTER
	ret
END(casueword_nosmap)

ENTRY(casueword_smap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%r8
	movq	$fusufault,PCB_ONFAULT(%r8)

	movq	$VM_MAXUSER_ADDRESS-4,%rax
	cmpq	%rax,%rdi			/* verify address is valid */
	ja	fusufault

	movq	%rsi,%rax			/* old */
	stac
#ifdef SMP
	lock
#endif
	cmpxchgq %rcx,(%rdi)			/* new = %rcx */
	clac

	/*
	 * The old value is in %rax.  If the store succeeded it will be the
	 * value we expected (old) from before the store, otherwise it will
	 * be the current value.
	 */
	movq	%rax,%rsi
	xorl	%eax,%eax
	movq	%rax,PCB_ONFAULT(%r8)
	movq	%rsi,(%rdx)
	POP_FRAME_POINTER
	ret
END(casueword_smap)

/*
 * Fetch (load) a 64-bit word, a 32-bit word, a 16-bit word, or an 8-bit
 * byte from user memory.
 * addr = %rdi, valp = %rsi
 */

ENTRY(fueword_nosmap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-8,%rax
	cmpq	%rax,%rdi			/* verify address is valid */
	ja	fusufault

	xorl	%eax,%eax
	movq	(%rdi),%r11
	movq	%rax,PCB_ONFAULT(%rcx)
	movq	%r11,(%rsi)
	POP_FRAME_POINTER
	ret
END(fueword_nosmap)

ENTRY(fueword_smap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-8,%rax
	cmpq	%rax,%rdi			/* verify address is valid */
	ja	fusufault

	xorl	%eax,%eax
	stac
	movq	(%rdi),%r11
	clac
	movq	%rax,PCB_ONFAULT(%rcx)
	movq	%r11,(%rsi)
	POP_FRAME_POINTER
	ret
END(fueword_smap)

ENTRY(fueword32_nosmap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-4,%rax
	cmpq	%rax,%rdi			/* verify address is valid */
	ja	fusufault

	xorl	%eax,%eax
	movl	(%rdi),%r11d
	movq	%rax,PCB_ONFAULT(%rcx)
	movl	%r11d,(%rsi)
	POP_FRAME_POINTER
	ret
END(fueword32_nosmap)

ENTRY(fueword32_smap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-4,%rax
	cmpq	%rax,%rdi			/* verify address is valid */
	ja	fusufault

	xorl	%eax,%eax
	stac
	movl	(%rdi),%r11d
	clac
	movq	%rax,PCB_ONFAULT(%rcx)
	movl	%r11d,(%rsi)
	POP_FRAME_POINTER
	ret
END(fueword32_smap)

ENTRY(fuword16_nosmap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-2,%rax
	cmpq	%rax,%rdi
	ja	fusufault

	movzwl	(%rdi),%eax
	movq	$0,PCB_ONFAULT(%rcx)
	POP_FRAME_POINTER
	ret
END(fuword16_nosmap)

ENTRY(fuword16_smap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-2,%rax
	cmpq	%rax,%rdi
	ja	fusufault

	stac
	movzwl	(%rdi),%eax
	clac
	movq	$0,PCB_ONFAULT(%rcx)
	POP_FRAME_POINTER
	ret
END(fuword16_smap)

ENTRY(fubyte_nosmap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-1,%rax
	cmpq	%rax,%rdi
	ja	fusufault

	movzbl	(%rdi),%eax
	movq	$0,PCB_ONFAULT(%rcx)
	POP_FRAME_POINTER
	ret
END(fubyte_nosmap)

ENTRY(fubyte_smap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-1,%rax
	cmpq	%rax,%rdi
	ja	fusufault

	stac
	movzbl	(%rdi),%eax
	clac
	movq	$0,PCB_ONFAULT(%rcx)
	POP_FRAME_POINTER
	ret
END(fubyte_smap)

	ALIGN_TEXT
	/* Fault entry clears PSL.AC */
fusufault:
	movq	PCPU(CURPCB),%rcx
	xorl	%eax,%eax
	movq	%rax,PCB_ONFAULT(%rcx)
	decq	%rax
	POP_FRAME_POINTER
	ret

/*
 * Store a 64-bit word, a 32-bit word, a 16-bit word, or an 8-bit byte to
 * user memory.
 * addr = %rdi, value = %rsi
 */
ENTRY(suword_nosmap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-8,%rax
	cmpq	%rax,%rdi			/* verify address validity */
	ja	fusufault

	movq	%rsi,(%rdi)
	xorl	%eax,%eax
	movq	PCPU(CURPCB),%rcx
	movq	%rax,PCB_ONFAULT(%rcx)
	POP_FRAME_POINTER
	ret
END(suword_nosmap)

ENTRY(suword_smap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-8,%rax
	cmpq	%rax,%rdi			/* verify address validity */
	ja	fusufault

	stac
	movq	%rsi,(%rdi)
	clac
	xorl	%eax,%eax
	movq	PCPU(CURPCB),%rcx
	movq	%rax,PCB_ONFAULT(%rcx)
	POP_FRAME_POINTER
	ret
END(suword_smap)

ENTRY(suword32_nosmap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-4,%rax
	cmpq	%rax,%rdi			/* verify address validity */
	ja	fusufault

	movl	%esi,(%rdi)
	xorl	%eax,%eax
	movq	PCPU(CURPCB),%rcx
	movq	%rax,PCB_ONFAULT(%rcx)
	POP_FRAME_POINTER
	ret
END(suword32_nosmap)

ENTRY(suword32_smap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-4,%rax
	cmpq	%rax,%rdi			/* verify address validity */
	ja	fusufault

	stac
	movl	%esi,(%rdi)
	clac
	xorl	%eax,%eax
	movq	PCPU(CURPCB),%rcx
	movq	%rax,PCB_ONFAULT(%rcx)
	POP_FRAME_POINTER
	ret
END(suword32_smap)

ENTRY(suword16_nosmap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-2,%rax
	cmpq	%rax,%rdi			/* verify address validity */
	ja	fusufault

	movw	%si,(%rdi)
	xorl	%eax,%eax
	movq	PCPU(CURPCB),%rcx		/* restore trashed register */
	movq	%rax,PCB_ONFAULT(%rcx)
	POP_FRAME_POINTER
	ret
END(suword16_nosmap)

ENTRY(suword16_smap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-2,%rax
	cmpq	%rax,%rdi			/* verify address validity */
	ja	fusufault

	stac
	movw	%si,(%rdi)
	clac
	xorl	%eax,%eax
	movq	PCPU(CURPCB),%rcx		/* restore trashed register */
	movq	%rax,PCB_ONFAULT(%rcx)
	POP_FRAME_POINTER
	ret
END(suword16_smap)

ENTRY(subyte_nosmap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-1,%rax
	cmpq	%rax,%rdi			/* verify address validity */
	ja	fusufault

	movl	%esi,%eax
	movb	%al,(%rdi)
	xorl	%eax,%eax
	movq	PCPU(CURPCB),%rcx		/* restore trashed register */
	movq	%rax,PCB_ONFAULT(%rcx)
	POP_FRAME_POINTER
	ret
END(subyte_nosmap)

ENTRY(subyte_smap)
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%rcx
	movq	$fusufault,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS-1,%rax
	cmpq	%rax,%rdi			/* verify address validity */
	ja	fusufault

	movl	%esi,%eax
	stac
	movb	%al,(%rdi)
	clac
	xorl	%eax,%eax
	movq	PCPU(CURPCB),%rcx		/* restore trashed register */
	movq	%rax,PCB_ONFAULT(%rcx)
	POP_FRAME_POINTER
	ret
END(subyte_smap)

/*
 * copyinstr(from, to, maxlen, int *lencopied)
 *           %rdi, %rsi, %rdx, %rcx
 *
 *	copy a string from 'from' to 'to', stop when a 0 character is reached.
 *	return ENAMETOOLONG if string is longer than maxlen, and
 *	EFAULT on protection violations. If lencopied is non-zero,
 *	return the actual length in *lencopied.
 */
ENTRY(copyinstr_nosmap)
	PUSH_FRAME_POINTER
	movq	%rdx,%r8			/* %r8 = maxlen */
	movq	%rcx,%r9			/* %r9 = *len */
	xchgq	%rdi,%rsi			/* %rdi = from, %rsi = to */
	movq	PCPU(CURPCB),%rcx
	movq	$cpystrflt,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS,%rax

	/* make sure 'from' is within bounds */
	subq	%rsi,%rax
	jbe	cpystrflt

	/* restrict maxlen to <= VM_MAXUSER_ADDRESS-from */
	cmpq	%rdx,%rax
	jae	1f
	movq	%rax,%rdx
	movq	%rax,%r8
1:
	incq	%rdx

2:
	decq	%rdx
	jz	copyinstr_toolong

	lodsb
	stosb
	orb	%al,%al
	jnz	2b

	jmp	copyinstr_succ
END(copyinstr_nosmap)

ENTRY(copyinstr_smap)
	PUSH_FRAME_POINTER
	movq	%rdx,%r8			/* %r8 = maxlen */
	movq	%rcx,%r9			/* %r9 = *len */
	xchgq	%rdi,%rsi			/* %rdi = from, %rsi = to */
	movq	PCPU(CURPCB),%rcx
	movq	$cpystrflt,PCB_ONFAULT(%rcx)

	movq	$VM_MAXUSER_ADDRESS,%rax

	/* make sure 'from' is within bounds */
	subq	%rsi,%rax
	jbe	cpystrflt

	stac

	/* restrict maxlen to <= VM_MAXUSER_ADDRESS-from */
	cmpq	%rdx,%rax
	jae	1f
	movq	%rax,%rdx
	movq	%rax,%r8
1:
	incq	%rdx

2:
	decq	%rdx
	jz	copyinstr_toolong_smap

	lodsb
	stosb
	orb	%al,%al
	jnz	2b

	clac

copyinstr_succ:
	/* Success -- 0 byte reached */
	decq	%rdx
	xorl	%eax,%eax

cpystrflt_x:
	/* set *lencopied and return %eax */
	movq	PCPU(CURPCB),%rcx
	movq	$0,PCB_ONFAULT(%rcx)

	testq	%r9,%r9
	jz	1f
	subq	%rdx,%r8
	movq	%r8,(%r9)
1:
	POP_FRAME_POINTER
	ret
	/* Fault entry clears PSL.AC */
cpystrflt:
	movq	$EFAULT,%rax
	jmp	cpystrflt_x

copyinstr_toolong_smap:
	clac
copyinstr_toolong:
	/* rdx is zero - return ENAMETOOLONG or EFAULT */
	movq	$VM_MAXUSER_ADDRESS,%rax
	cmpq	%rax,%rsi
	jae	cpystrflt
	movq	$ENAMETOOLONG,%rax
	jmp	cpystrflt_x

END(copyinstr_smap)

/*
 * copystr(from, to, maxlen, int *lencopied)
 *         %rdi, %rsi, %rdx, %rcx
 */
ENTRY(copystr)
	PUSH_FRAME_POINTER
	movq	%rdx,%r8			/* %r8 = maxlen */

	xchgq	%rdi,%rsi
	incq	%rdx
1:
	decq	%rdx
	jz	4f
	lodsb
	stosb
	orb	%al,%al
	jnz	1b

	/* Success -- 0 byte reached */
	decq	%rdx
	xorl	%eax,%eax
	jmp	6f
4:
	/* rdx is zero -- return ENAMETOOLONG */
	movq	$ENAMETOOLONG,%rax

6:

	testq	%rcx,%rcx
	jz	7f
	/* set *lencopied and return %rax */
	subq	%rdx,%r8
	movq	%r8,(%rcx)
7:
	POP_FRAME_POINTER
	ret
END(copystr)

/*
 * Handling of special amd64 registers and descriptor tables etc
 */
/* void lgdt(struct region_descriptor *rdp); */
ENTRY(lgdt)
	/* reload the descriptor table */
	lgdt	(%rdi)

	/* flush the prefetch q */
	jmp	1f
	nop
1:
	movl	$KDSEL,%eax
	movl	%eax,%ds
	movl	%eax,%es
	movl	%eax,%fs	/* Beware, use wrmsr to set 64 bit base */
	movl	%eax,%gs
	movl	%eax,%ss

	/* reload code selector by turning return into intersegmental return */
	popq	%rax
	pushq	$KCSEL
	pushq	%rax
	MEXITCOUNT
	lretq
END(lgdt)

/*****************************************************************************/
/* setjump, longjump                                                         */
/*****************************************************************************/

ENTRY(setjmp)
	movq	%rbx,0(%rdi)			/* save rbx */
	movq	%rsp,8(%rdi)			/* save rsp */
	movq	%rbp,16(%rdi)			/* save rbp */
	movq	%r12,24(%rdi)			/* save r12 */
	movq	%r13,32(%rdi)			/* save r13 */
	movq	%r14,40(%rdi)			/* save r14 */
	movq	%r15,48(%rdi)			/* save r15 */
	movq	0(%rsp),%rdx			/* get rta */
	movq	%rdx,56(%rdi)			/* save rip */
	xorl	%eax,%eax			/* return(0); */
	ret
END(setjmp)

ENTRY(longjmp)
	movq	0(%rdi),%rbx			/* restore rbx */
	movq	8(%rdi),%rsp			/* restore rsp */
	movq	16(%rdi),%rbp			/* restore rbp */
	movq	24(%rdi),%r12			/* restore r12 */
	movq	32(%rdi),%r13			/* restore r13 */
	movq	40(%rdi),%r14			/* restore r14 */
	movq	48(%rdi),%r15			/* restore r15 */
	movq	56(%rdi),%rdx			/* get rta */
	movq	%rdx,0(%rsp)			/* put in return frame */
	xorl	%eax,%eax			/* return(1); */
	incl	%eax
	ret
END(longjmp)

/*
 * Support for reading MSRs in the safe manner.  (Instead of panic on #gp,
 * return an error.)
 */
ENTRY(rdmsr_safe)
/* int rdmsr_safe(u_int msr, uint64_t *data) */
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%r8
	movq	$msr_onfault,PCB_ONFAULT(%r8)
	movl	%edi,%ecx
	rdmsr			/* Read MSR pointed by %ecx. Returns
				   hi byte in edx, lo in %eax */
	salq	$32,%rdx	/* sign-shift %rdx left */
	movl	%eax,%eax	/* zero-extend %eax -> %rax */
	orq	%rdx,%rax
	movq	%rax,(%rsi)
	xorq	%rax,%rax
	movq	%rax,PCB_ONFAULT(%r8)
	POP_FRAME_POINTER
	ret

/*
 * Support for writing MSRs in the safe manner.  (Instead of panic on #gp,
 * return an error.)
 */
ENTRY(wrmsr_safe)
/* int wrmsr_safe(u_int msr, uint64_t data) */
	PUSH_FRAME_POINTER
	movq	PCPU(CURPCB),%r8
	movq	$msr_onfault,PCB_ONFAULT(%r8)
	movl	%edi,%ecx
	movl	%esi,%eax
	sarq	$32,%rsi
	movl	%esi,%edx
	wrmsr			/* Write MSR pointed by %ecx. Accepts
				   hi byte in edx, lo in %eax. */
	xorq	%rax,%rax
	movq	%rax,PCB_ONFAULT(%r8)
	POP_FRAME_POINTER
	ret

/*
 * MSR operations fault handler
 */
	ALIGN_TEXT
msr_onfault:
	movq	$0,PCB_ONFAULT(%r8)
	movl	$EFAULT,%eax
	POP_FRAME_POINTER
	ret

/*
 * void pmap_pti_pcid_invalidate(uint64_t ucr3, uint64_t kcr3);
 * Invalidates address space addressed by ucr3, then returns to kcr3.
 * Done in assembler to ensure no other memory accesses happen while
 * on ucr3.
 */
	ALIGN_TEXT
ENTRY(pmap_pti_pcid_invalidate)
	pushfq
	cli
	movq	%rdi,%cr3	/* to user page table */
	movq	%rsi,%cr3	/* back to kernel */
	popfq
	retq

/*
 * void pmap_pti_pcid_invlpg(uint64_t ucr3, uint64_t kcr3, vm_offset_t va);
 * Invalidates virtual address va in address space ucr3, then returns to kcr3.
 */
	ALIGN_TEXT
ENTRY(pmap_pti_pcid_invlpg)
	pushfq
	cli
	movq	%rdi,%cr3	/* to user page table */
	invlpg	(%rdx)
	movq	%rsi,%cr3	/* back to kernel */
	popfq
	retq

/*
 * void pmap_pti_pcid_invlrng(uint64_t ucr3, uint64_t kcr3, vm_offset_t sva,
 *     vm_offset_t eva);
 * Invalidates virtual addresses between sva and eva in address space ucr3,
 * then returns to kcr3.
 */
	ALIGN_TEXT
ENTRY(pmap_pti_pcid_invlrng)
	pushfq
	cli
	movq	%rdi,%cr3	/* to user page table */
1:	invlpg	(%rdx)
	addq	$PAGE_SIZE,%rdx
	cmpq	%rdx,%rcx
	ja	1b
	movq	%rsi,%cr3	/* back to kernel */
	popfq
	retq

	.altmacro
	.macro	ibrs_seq_label l
handle_ibrs_\l:
	.endm
	.macro	ibrs_call_label l
	call	handle_ibrs_\l
	.endm
	.macro	ibrs_seq count
	ll=1
	.rept	\count
	ibrs_call_label	%(ll)
	nop
	ibrs_seq_label %(ll)
	addq	$8,%rsp
	ll=ll+1
	.endr
	.endm

/* all callers already saved %rax, %rdx, and %rcx */
ENTRY(handle_ibrs_entry)
	cmpb	$0,hw_ibrs_active(%rip)
	je	1f
	movl	$MSR_IA32_SPEC_CTRL,%ecx
	rdmsr
	orl	$(IA32_SPEC_CTRL_IBRS|IA32_SPEC_CTRL_STIBP),%eax
	orl	$(IA32_SPEC_CTRL_IBRS|IA32_SPEC_CTRL_STIBP)>>32,%edx
	wrmsr
	movb	$1,PCPU(IBPB_SET)
	testl	$CPUID_STDEXT_SMEP,cpu_stdext_feature(%rip)
	jne	1f
	ibrs_seq 32
1:	ret
END(handle_ibrs_entry)

ENTRY(handle_ibrs_exit)
	cmpb	$0,PCPU(IBPB_SET)
	je	1f
	movl	$MSR_IA32_SPEC_CTRL,%ecx
	rdmsr
	andl	$~(IA32_SPEC_CTRL_IBRS|IA32_SPEC_CTRL_STIBP),%eax
	andl	$~((IA32_SPEC_CTRL_IBRS|IA32_SPEC_CTRL_STIBP)>>32),%edx
	wrmsr
	movb	$0,PCPU(IBPB_SET)
1:	ret
END(handle_ibrs_exit)

/* registers-neutral version, but needs stack */
ENTRY(handle_ibrs_exit_rs)
	cmpb	$0,PCPU(IBPB_SET)
	je	1f
	pushq	%rax
	pushq	%rdx
	pushq	%rcx
	movl	$MSR_IA32_SPEC_CTRL,%ecx
	rdmsr
	andl	$~(IA32_SPEC_CTRL_IBRS|IA32_SPEC_CTRL_STIBP),%eax
	andl	$~((IA32_SPEC_CTRL_IBRS|IA32_SPEC_CTRL_STIBP)>>32),%edx
	wrmsr
	popq	%rcx
	popq	%rdx
	popq	%rax
	movb	$0,PCPU(IBPB_SET)
1:	ret
END(handle_ibrs_exit_rs)

	.noaltmacro

/*
 * Flush L1D cache.  Load enough of the data from the kernel text
 * to flush existing L1D content.
 *
 * N.B. The function does not follow ABI calling conventions, it corrupts %rbx.
 * The vmm.ko caller expects that only %rax, %rdx, %rbx, %rcx, %r9, and %rflags
 * registers are clobbered.  The NMI handler caller only needs %r13 preserved.
 */
ENTRY(flush_l1d_sw)
#define	L1D_FLUSH_SIZE	(64 * 1024)
	movq	$KERNBASE, %r9
	movq	$-L1D_FLUSH_SIZE, %rcx
	/*
	 * pass 1: Preload TLB.
	 * Kernel text is mapped using superpages.  TLB preload is
	 * done for the benefit of older CPUs which split 2M page
	 * into 4k TLB entries.
	 */
1:	movb	L1D_FLUSH_SIZE(%r9, %rcx), %al
	addq	$PAGE_SIZE, %rcx
	jne	1b
	xorl	%eax, %eax
	cpuid
	movq	$-L1D_FLUSH_SIZE, %rcx
	/* pass 2: Read each cache line. */
2:	movb	L1D_FLUSH_SIZE(%r9, %rcx), %al
	addq	$64, %rcx
	jne	2b
	lfence
	ret
#undef	L1D_FLUSH_SIZE
END(flush_l1d_sw)
