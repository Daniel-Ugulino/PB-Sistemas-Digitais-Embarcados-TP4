// Le o pacote de telemetria FPGA -> Pi (config_tx.v) via SPI.
//
//   STX | 0x20 | speed | dist_e | dist_c | dist_d | vel_e | vel_c | vel_d | dir | ETX
//
//
// Cada quadro valido entra no filter.s. Se o cru mudar e alguma distancia
// (e/c/d) for menor que cfg_dist_free, grava em spi_log.txt:
//   Log - <cru>
//   AVG <media/moda>

.equ STX,      0x02
.equ ETX,      0x03
.equ TYPE_TEL, 0x20
.equ TEL_LEN,  11
.equ TEL_PAY,  8

.extern filt_push
.extern cfg_dist_free

.section .bss
.align 8
.global tel_pkt
tel_pkt:      .skip 16
tel_last_pay: .skip 8
tel_seen:     .byte 0

.section .text

// int telemetry_poll(void) — 0 = pacote valido, -1 = falha
.global telemetry_poll
telemetry_poll:
    stp     x29, x30, [sp, #-16]!

    ldr     x0, =tel_pkt
    str     xzr, [x0]
    str     xzr, [x0, #8]
    mov     x1, #TEL_LEN
    bl      spi_read_buf

    cmp     x0, #TEL_LEN
    b.ne    tel_fail

    ldr     x9, =tel_pkt
    ldrb    w0, [x9]
    cmp     w0, #STX
    b.ne    tel_fail

    ldrb    w0, [x9, #1]
    cmp     w0, #TYPE_TEL
    b.ne    tel_fail

    ldrb    w0, [x9, #10]
    cmp     w0, #ETX
    b.ne    tel_fail

    add     x0, x9, #2
    bl      filt_push

    ldr     x10, =tel_seen
    ldrb    w3, [x10]
    cbz     w3, tel_novo

    ldr     x11, =tel_last_pay
    add     x12, x9, #2
    mov     w13, #0
tel_cmp:
    cmp     w13, #TEL_PAY
    b.ge    tel_ok
    ldrb    w0, [x12, w13, uxtw]
    ldrb    w1, [x11, w13, uxtw]
    cmp     w0, w1
    b.ne    tel_novo
    add     w13, w13, #1
    b       tel_cmp

tel_novo:
    mov     w3, #1
    strb    w3, [x10]

    ldr     x11, =tel_last_pay
    add     x12, x9, #2
    mov     w13, #0
tel_save:
    cmp     w13, #TEL_PAY
    b.ge    tel_saved
    ldrb    w0, [x12, w13, uxtw]
    strb    w0, [x11, w13, uxtw]
    add     w13, w13, #1
    b       tel_save

tel_saved:
    ldr     x0, =cfg_dist_free
    ldrb    w1, [x0]
    ldrb    w0, [x9, #3]
    cmp     w0, w1
    b.lo    tel_log
    ldrb    w0, [x9, #4]
    cmp     w0, w1
    b.lo    tel_log
    ldrb    w0, [x9, #5]
    cmp     w0, w1
    b.hs    tel_ok
tel_log:
    mov     x0, x9
    bl      log_telemetry

tel_ok:
    mov     w0, #0
    ldp     x29, x30, [sp], #16
    ret

tel_fail:
    mov     w0, #-1
    ldp     x29, x30, [sp], #16
    ret
