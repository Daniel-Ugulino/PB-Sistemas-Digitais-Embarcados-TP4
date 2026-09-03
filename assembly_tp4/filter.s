// Media NEON/SIMD das ultimas 50 amostras do payload SPI (config_tx.v):
//   speed | dist_e | dist_c | dist_d | vel_e | vel_c | vel_d | dir
//
// speed + 3 distancias: media unsigned (uaddw + fdiv em 4 pistas)
// 3 velocidades:        media signed   (saddw + fdiv em 4 pistas)
// dir:                  moda (mais frequente; empate = amostra mais nova)
//
// void filt_push(const uint8_t *pay)   // 8 bytes do payload
// uint8_t filt_pkt[11]                 // STX|0x20|medias|moda|ETX
// uint8_t filt_out[8]                  // so o payload filtrado

.arch armv8-a

.equ FILT_WIN, 50

.section .data
.align 16
.global filt_pkt
filt_pkt:
    .byte   0x02, 0x20
.global filt_out
filt_out:
    .byte   0, 0, 0, 0, 0, 0, 0, 0
    .byte   0x03

.section .bss
.align 16
filt_hist:      .skip 400
.global filt_n
filt_n:         .skip 1
filt_ptr:       .skip 1

.section .text

// void filt_push(const uint8_t *pay)
.global filt_push
filt_push:
    stp     x29, x30, [sp, #-16]!

    ldr     x1, =filt_hist
    ldr     x2, =filt_ptr
    ldrb    w3, [x2]
    add     x4, x1, w3, uxtw #3
    ldr     x5, [x0]
    str     x5, [x4]

    add     w3, w3, #1
    cmp     w3, #FILT_WIN
    csel    w3, wzr, w3, hs
    strb    w3, [x2]

    ldr     x2, =filt_n
    ldrb    w3, [x2]
    cmp     w3, #FILT_WIN
    add     w4, w3, #1
    csel    w3, w3, w4, hs
    strb    w3, [x2]

    bl      filt_compute
    ldp     x29, x30, [sp], #16
    ret

// Recalcula filt_out a partir de hist[0 .. n-1] (n<=50, janela ja linear)
filt_compute:
    ldr     x0, =filt_hist
    ldr     x1, =filt_n
    ldrb    w1, [x1]
    cbz     w1, filt_done

    movi    v0.8h, #0
    movi    v1.8h, #0
    mov     w2, wzr
    sub     sp, sp, #16
    str     xzr, [sp]

filt_sum:
    cmp     w2, w1
    b.hs    filt_avg

    ld1     {v2.8b}, [x0], #8
    uaddw   v0.8h, v0.8h, v2.8b
    saddw   v1.8h, v1.8h, v2.8b

    umov    w3, v2.b[7]
    and     w3, w3, #3
    ldrb    w4, [sp, w3, uxtw]
    add     w4, w4, #1
    strb    w4, [sp, w3, uxtw]

    add     w2, w2, #1
    b       filt_sum

filt_avg:
    dup     v3.4s, w1
    ucvtf   v3.4s, v3.4s

    uxtl    v4.4s, v0.4h
    ucvtf   v4.4s, v4.4s
    fdiv    v4.4s, v4.4s, v3.4s
    fcvtnu  v4.4s, v4.4s
    xtn     v4.4h, v4.4s
    xtn     v4.8b, v4.8h

    ext     v5.16b, v1.16b, v1.16b, #8
    sxtl    v5.4s, v5.4h
    scvtf   v5.4s, v5.4s
    fdiv    v5.4s, v5.4s, v3.4s
    fcvtns  v5.4s, v5.4s
    sqxtn   v5.4h, v5.4s
    sqxtn   v5.8b, v5.8h

    ins     v4.b[4], v5.b[0]
    ins     v4.b[5], v5.b[1]
    ins     v4.b[6], v5.b[2]

    ldr     x0, =filt_ptr
    ldrb    w2, [x0]
    cbz     w2, filt_newest_wrap
    sub     w2, w2, #1
    b       filt_newest_ok
filt_newest_wrap:
    mov     w2, #(FILT_WIN - 1)
filt_newest_ok:
    ldr     x0, =filt_hist
    add     x0, x0, w2, uxtw #3
    ldrb    w3, [x0, #7]
    and     w3, w3, #3
    ldrb    w4, [sp, w3, uxtw]
    mov     w5, wzr
filt_dir_scan:
    cmp     w5, #4
    b.hs    filt_dir_done
    ldrb    w6, [sp, w5, uxtw]
    cmp     w6, w4
    b.ls    filt_dir_next
    mov     w4, w6
    mov     w3, w5
filt_dir_next:
    add     w5, w5, #1
    b       filt_dir_scan
filt_dir_done:
    ins     v4.b[7], w3

    ldr     x0, =filt_out
    str     d4, [x0]
    add     sp, sp, #16

filt_done:
    ret
