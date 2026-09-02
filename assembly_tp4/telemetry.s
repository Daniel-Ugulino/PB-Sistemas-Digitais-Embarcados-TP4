// Le o pacote de telemetria FPGA -> Pi (config_tx.v) via SPI.
//
//   STX | 0x20 | speed | dist_e | dist_c | dist_d | vel_e | vel_c | vel_d | dir | ETX
//
// Sem checksum: o CS do SPI ja delimita o quadro. O master precisa clocar
// os 11 bytes numa unica transacao. MOSI vai zerado, entao config_rx ignora
// o quadro por nao comecar em STX.
//
// So grava no log quando speed, distancia, vel ou dir mudam, para nao encher
// o arquivo a cada loop. Devolve 0 se o pacote for valido, -1 caso contrario

.equ STX,      0x02
.equ ETX,      0x03
.equ TYPE_TEL, 0x20
.equ TEL_LEN,  11
.equ TEL_PAY,  8

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

    ldr     x10, =tel_seen
    ldrb    w3, [x10]
    cbz     w3, tel_novo

    ldr     x11, =tel_last_pay
    mov     w13, #0
tel_cmp:
    cmp     w13, #TEL_PAY
    b.ge    tel_ok
    add     x12, x9, #2
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
    mov     w13, #0
tel_save:
    cmp     w13, #TEL_PAY
    b.ge    tel_saved
    add     x12, x9, #2
    ldrb    w0, [x12, w13, uxtw]
    strb    w0, [x11, w13, uxtw]
    add     w13, w13, #1
    b       tel_save

tel_saved:
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
