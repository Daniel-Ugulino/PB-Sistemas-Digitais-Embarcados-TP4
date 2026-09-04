// Envia pacote de configuracao Pi -> FPGA (config_rx.v) via SPI
//
//   STX | 0x10 | dist_free | dist_att | vel_max | ETX
//
// Sem checksum: o CS do SPI ja delimita o quadro.
// O pacote e montado inteiro em cfg_pkt e sai em uma unica chamada de
// spi_write_buf — uma escrita por byte viraria seis transacoes distintas.

.equ STX,      0x02
.equ ETX,      0x03
.equ TYPE_CFG, 0x10
.equ CFG_LEN,  6

.section .data
.global cfg_dist_free
.global cfg_dist_att
.global cfg_vel_max
cfg_dist_free:       .byte 50
cfg_dist_att:        .byte 30
cfg_vel_max:         .byte 120

.section .bss
.align 8
cfg_pkt: .skip 8

.section .text

// void config_init(void) — monta e envia dist_free, dist_att e vel_max
.global config_init
.global config_send
config_init:
config_send:
    stp     x29, x30, [sp, #-16]!

    adr     x9, cfg_dist_free       // os 3 campos sao contiguos em .data
    ldr     x10, =cfg_pkt

    mov     w0, #STX
    strb    w0, [x10]
    mov     w0, #TYPE_CFG
    strb    w0, [x10, #1]

    mov     w13, #0

cfg_campo:
    cmp     w13, #3
    b.ge    cfg_final

    ldrb    w0, [x9, x13]
    add     x11, x10, #2
    strb    w0, [x11, x13]

    add     w13, w13, #1
    b       cfg_campo

cfg_final:
    mov     w0, #ETX
    strb    w0, [x10, #5]

    mov     x0, x10
    mov     x1, #CFG_LEN
    bl      spi_write_buf

    ldp     x29, x30, [sp], #16
    ret
