.arm
.align 2
.syntax unified

.macro FUNCTION_BEGIN name
    .section .text.\name, "ax", %progbits
    .global \name
    .type \name, %function
    .cfi_startproc
\name:
.endm

.macro FUNCTION_END
    .cfi_endproc
.endm

FUNCTION_BEGIN xmemcpy
    push    {r0, lr}
    bl      x__aeabi_memcpy
    // Return dst pointer
    pop     {r0, lr}
    bx      lr
FUNCTION_END

FUNCTION_BEGIN x__aeabi_memcpy
    // If there are less than 4 bytes to copy, copy them
    // and return
    cmp     r2, #3
    bls     4f

    // If dst is already aligned, no need to adjust
    ands    r12, r0, #3
    beq     1f

    // Copy the non-aligned bytes of dst first, so that
    // it becomes aligned (and hopefully src stays or 
    // becomes aligned after that)
    ldrb    r3, [r1], #1
    cmp     r12, #2
    add     r2, r2, r12
    ldrbls  r12, [r1], #1
    strb    r3, [r0], #1
    ldrbcc  r3, [r1], #1
    strbls  r12, [r0], #1
    sub     r2, r2, #4
    strbcc  r3, [r0], #1

1:
    // If both dst and src are aligned, tail-call a highly
    // optimized function
    ands    r3, r1, #3
    beq     x__aeabi_memcpy4 // tail call

    // Otherwise, copy 2x 32-bit words at a time, using
    // unaligned access support
    subs    r2, r2, #8
2:
    bcc     3f
    ldr     r3, [r1], #4
    subs    r2, r2, #8
    ldr     r12, [r1], #4
    stm     r0!, {r3, r12}
    b       2b

3:
    adds    r2, r2, #4
    ldrpl   r3, [r1], #4
    strpl   r3, [r0], #4
    nop

    // Copy the remaining bytes
4:
    movs    r2, r2, lsl#31
    ldrbcs  r3, [r1], #1
    ldrbcs  r12, [r1], #1
    ldrbmi  r2, [r1], #1
    strbcs  r3, [r0], #1
    strbcs  r12, [r0], #1
    strbmi  r2, [r0], #1

    bx      lr
FUNCTION_END

FUNCTION_BEGIN x__aeabi_memcpy4
    push    {r4-r10, lr}
    subs    r2, r2, #32
    bcc     2f

    // Copy 32 bytes at at time
    ldm     r1!, {r3-r6}
    pld     [r1, #64]
    ldm     r1!, {r7-r10}
1:
    stm     r0!, {r3-r6}
    subs    r2, r2, #32
    bcc     2f
    stm     r0!, {r7-r10}
    ldmcs   r1!, {r3-r6}
    pld     [r1, #64]
    ldmcs   r1!, {r7-r10}
    bcs     1b

    // Copy the remainder
2:
    movs    r12, r2, lsl#28
    ldmcs   r1!, {r3, r4, r12, lr}
    stmcs   r0!, {r3, r4, r12, lr}
    ldmmi   r1!, {r3, r4}
    stmmi   r0!, {r3, r4}
    pop     {r4-r10, lr}
    movs    r12, r2, lsl#30
    ldrcs   r3, [r1], #4
    strcs   r3, [r0], #4
    bxeq    lr
    movs    r2, r2, lsl#31
    ldrhcs  r3, [r1], #2
    ldrbmi  r2, [r1], #1
    strhcs  r3, [r0], #2
    strbmi  r2, [r0], #1

    bx      lr
FUNCTION_END

FUNCTION_BEGIN x__aeabi_memcpy_v4
    // If there are less than 4 bytes to copy, copy them
    // and return
    cmp     r2, #3
    bls     5f

    // If dst is already aligned, no need to adjust
    ands    r12, r0, #3
    beq     1f

    // Copy the non-aligned bytes of dst first, so that
    // it becomes aligned (and hopefully src stays or 
    // becomes aligned after that)
    ldrb    r3, [r1], #1
    cmp     r12, #2
    add     r2, r2, r12
    ldrbls  r12, [r1], #1
    strb    r3, [r0], #1
    ldrbcc  r3, [r1], #1
    strbls  r12, [r0], #1
    sub     r2, r2, #4
    strbcc  r3, [r0], #1

1:
    // If both dst and src are aligned, tail-call a highly
    // optimized function
    ands    r3, r1, #3
    beq     x__aeabi_memcpy4_v4 // tail call

    // Otherwise, try to copy 4 bytes at a time, taking
    // misalignment into account
    subs    r2, r2, #4
    bcc     5f
    ldr     r12, [r1, -r3]!
    cmp     r3, #2
    beq     3f
    bhi     4f

2:
    // Misaligned by 1
    mov     r3, r12, lsr#8
    ldr     r12, [r1, #4]!
    subs    r2, r2, #4
    orr     r3, r3, r12,lsl#24
    str     r3, [r0], #4
    bcs     2b
    add     r1, r1, #1
    b       5f

3:
    // Misaligned by 2
    mov     r3, r12, lsr#16
    ldr     r12, [r1, #4]!
    subs    r2, r2, #4
    orr     r3, r3, r12,lsl#16
    str     r3, [r0], #4
    bcs     3b
    add     r1, r1, #2
    b       5f

4:
    // Misaligned by 3
    mov     r3, r12, lsr#24
    ldr     r12, [r1, #4]!
    subs    r2, r2, #4
    orr     r3, r3, r12,lsl#8
    str     r3, [r0], #4
    bcs     4b
    add     r1, r1, #3
    nop

5:
    // Copy the remaining bytes
    movs    r2, r2, lsl#31
    ldrbcs  r3, [r1], #1
    ldrbcs  r12, [r1], #1
    ldrbmi  r2, [r1], #1
    strbcs  r3, [r0], #1
    strbcs  r12, [r0], #1
    strbmi  r2, [r0], #1

    bx      lr
FUNCTION_END

FUNCTION_BEGIN xmemcpy_v4
    push    {r0, lr}
    bl      x__aeabi_memcpy_v4
    // Return dst pointer
    pop     {r0, lr}
    bx      lr
FUNCTION_END

FUNCTION_BEGIN x__aeabi_memcpy4_v4
    push    {r4-r10, lr}
    subs    r2, r2, #32
    bcc     2f

    // Copy 32 bytes at at time
    ldm     r1!, {r3-r6}
    ldm     r1!, {r7-r10}
1:
    stm     r0!, {r3-r6}
    subs    r2, r2, #32
    bcc     2f
    stm     r0!, {r7-r10}
    ldmcs   r1!, {r3-r6}
    nop
    ldmcs   r1!, {r7-r10}
    bcs     1b

    // Copy the remainder
2:
    movs    r12, r2, lsl#28
    ldmcs   r1!, {r3, r4, r12, lr}
    stmcs   r0!, {r3, r4, r12, lr}
    ldmmi   r1!, {r3, r4}
    stmmi   r0!, {r3, r4}
    pop     {r4-r10, lr}
    movs    r12, r2, lsl#30
    ldrcs   r3, [r1], #4
    strcs   r3, [r0], #4
    bxeq    lr
    movs    r2, r2, lsl#31
    ldrhcs  r3, [r1], #2
    ldrbmi  r2, [r1], #1
    strhcs  r3, [r0], #2
    strbmi  r2, [r0], #1

    bx      lr
FUNCTION_END

FUNCTION_BEGIN xmemset
    push    {r0, lr}

    // Function takes an int as fill value, but it's meant to be a character
    // literal. Copy it 3 times
    and     r3, r1, #0xFF
    mov     r1, r2
    orr     r2, r3, r3, lsl#8
    orr     r2, r2, r2, lsl#16
    bl      x__aeabi_memset

    // Return dst pointer
    pop     {r0, lr}
    bx      lr
FUNCTION_END

FUNCTION_BEGIN x__aeabi_memset
    // If there are less than 4 bytes to fill, fill them
    // and return
    cmp     r1, #4
    bcc     1f

    // Use optimized routine if aligned (tail call)
    ands    r12, r0, #3
    beq     x__aeabi_memset4

    // Fill the non-aligned of the buffer first, so that
    // it becomes aligned
    rsb     r12, r12, #4
    cmp     r12, #2
    strbne  r2, [r0], #1
    sub     r1, r1, r12
    strhge  r2, [r0], #2

    b       x__aeabi_memset4

1:
    movs    r12, r1, lsl#31
    strbcs  r2, [r0], #1
    strbcs  r2, [r0], #1
    strbmi  r2, [r0], #1
    bx      lr
FUNCTION_END

FUNCTION_BEGIN x__aeabi_memset4
    push    {lr}

    // Use multiple regs to fill
    mov     r3, r2
    mov     r12, r2
    mov     lr, r2


    // Fill 32 bytes at a time
    subs    r1, r1, #32
1:
    stmcs   r0!, {r2, r3, r12, lr}
    stmcs   r0!, {r2, r3, r12, lr}
    subscs  r1, r1, #32
    bcs     1b

    // Fill the remainder
    movs    r1, r1, lsl#28
    stmcs   r0!, {r2, r3, r12, lr}
    stmmi   r0!, {r2, r3}
    pop     {lr}
    movs    r1, r1, lsl#2
    strcs   r2, [r0], #4
    bxeq    lr
    strhmi  r2, [r0], #2
    tst     r1, #(1 << 30)
    strbne  r2, [r0], #1
    bx      lr
FUNCTION_END
