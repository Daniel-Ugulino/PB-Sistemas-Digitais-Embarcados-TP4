.equ SYS_OPENAT, 56
.equ SYS_WRITE,  64
.equ SYS_CLOSE,  57
.equ AT_FDCWD,   -100

.equ O_WRONLY,   0x0001
.equ O_CREAT,    0x0040
.equ O_APPEND,   0x0400

.equ MODE_0644,  0x1A4

.section .data
log_path: .asciz "log.txt"
newline:  .ascii "\n"

msg_vel_inc: .ascii "Vel. max aumentada para "
msg_vel_inc_len: .quad . - msg_vel_inc
msg_vel_dec: .ascii "Vel. max reduzida para "
msg_vel_dec_len: .quad . - msg_vel_dec
msg_vel_unit: .ascii " km/h"
msg_vel_unit_len: .quad . - msg_vel_unit

msg_risk_inc: .ascii "Zona de risco aumentada: livre="
msg_risk_inc_len: .quad . - msg_risk_inc
msg_risk_dec: .ascii "Zona de risco reduzida: livre="
msg_risk_dec_len: .quad . - msg_risk_dec
msg_mid_att: .ascii " m atencao="
msg_mid_att_len: .quad . - msg_mid_att
msg_mid_unit: .ascii " m"
msg_mid_unit_len: .quad . - msg_mid_unit

msg_tang_speed: .ascii "Vel. Tang: "
msg_tang_speed_len: .quad . - msg_tang_speed
msg_dist_e: .ascii " km/h | E="
msg_dist_e_len: .quad . - msg_dist_e
msg_dist_c: .ascii " C="
msg_dist_c_len: .quad . - msg_dist_c
msg_dist_d: .ascii " D="
msg_dist_d_len: .quad . - msg_dist_d
msg_dir: .ascii " cm | dir="
msg_dir_len: .quad . - msg_dir

msg_dir_frente: .ascii "frente"
msg_dir_frente_len: .quad . - msg_dir_frente
msg_dir_esq: .ascii "esquerda"
msg_dir_esq_len: .quad . - msg_dir_esq
msg_dir_dir: .ascii "direita"
msg_dir_dir_len: .quad . - msg_dir_dir
msg_dir_blk: .ascii "tras"
msg_dir_blk_len: .quad . - msg_dir_blk

.equ STX,        0x02
.equ ETX,        0x03
.equ TYPE_SPEED, 0x20
.equ SPEED_LEN,  8

.extern cfg_dist_free
.extern cfg_dist_att
.extern cfg_vel_max
.extern spi_read_buf

.section .bss
.align 8
log_fd: .skip 8
log_byte_buf: .skip 8
log_line_buf: .skip 80
.global speed_pkt
speed_pkt: .skip 8
last_tel: .skip 5

.section .text

// void log_init(void) -> abre/cria o arquivo em modo append
.global log_init
log_init:
    stp x29, x30, [sp, #-16]!

    mov x0, #AT_FDCWD
    ldr x1, =log_path
    mov x2, #O_WRONLY
    orr x2, x2, #O_CREAT
    orr x2, x2, #O_APPEND
    mov x3, #MODE_0644
    mov x8, #SYS_OPENAT
    svc #0

    ldr x1, =log_fd
    str x0, [x1]

    ldr x1, =last_tel
    mov w2, #0xFF
    strb w2, [x1]
    strb w2, [x1, #1]
    strb w2, [x1, #2]
    strb w2, [x1, #3]
    strb w2, [x1, #4]

    ldp x29, x30, [sp], #16
    ret

// void log_write_byte(uint8_t byte) -> byte vem em w0, grava o byte + \n
.global log_write_byte
log_write_byte:
    stp x29, x30, [sp, #-16]!

    ldr x1, =log_byte_buf
    strb w0, [x1]

    ldr x1, =log_fd
    ldr x0, [x1]
    ldr x1, =log_byte_buf
    mov x2, #1
    mov x8, #SYS_WRITE
    svc #0

    ldr x1, =log_fd
    ldr x0, [x1]
    ldr x1, =newline
    mov x2, #1
    mov x8, #SYS_WRITE
    svc #0

    ldp x29, x30, [sp], #16
    ret

// void log_write(const char *buf, size_t len) — x0=buf, x1=len
.global log_write
log_write:
    stp     x29, x30, [sp, #-32]!
    stp     x0, x1, [sp, #16]

    ldr     x2, =log_fd
    ldr     x0, [x2]
    ldp     x1, x2, [sp, #16]
    mov     x8, #SYS_WRITE
    svc     #0

    ldr     x2, =log_fd
    ldr     x0, [x2]
    ldr     x1, =newline
    mov     x2, #1
    mov     x8, #SYS_WRITE
    svc     #0

    ldp     x29, x30, [sp], #32
    ret

// copia w3 bytes de [x2] para [x1]; retorna x1 avancado
log_copy_n:
    cbz     w3, log_copy_n_done
log_copy_n_loop:
    ldrb    w4, [x2], #1
    strb    w4, [x1], #1
    subs    w3, w3, #1
    b.ne    log_copy_n_loop
log_copy_n_done:
    ret

// w0 = 0..255, x1 = dest; retorna x1 avancado
log_format_byte:
    mov     w2, w0

    mov     w4, #100
    udiv    w5, w2, w4
    msub    w2, w5, w4, w2
    mov     w4, #10
    udiv    w6, w2, w4
    msub    w7, w6, w4, w2

    cbz     w5, log_format_byte_no_hund
    add     w5, w5, #'0'
    strb    w5, [x1], #1
    b       log_format_byte_tens

log_format_byte_no_hund:
    cbz     w6, log_format_byte_ones

log_format_byte_tens:
    add     w6, w6, #'0'
    strb    w6, [x1], #1

log_format_byte_ones:
    add     w7, w7, #'0'
    strb    w7, [x1], #1
    ret

.section .rodata
.align 3
log_dir_table:
    .quad msg_dir_frente
    .quad msg_dir_frente_len
    .quad msg_dir_esq
    .quad msg_dir_esq_len
    .quad msg_dir_dir
    .quad msg_dir_dir_len
    .quad msg_dir_blk
    .quad msg_dir_blk_len

log_action_table:
    .quad log_action_vel_inc    // 1
    .quad log_action_vel_dec    // 2
    .quad log_action_risk_inc   // 3
    .quad log_action_risk_dec   // 4
.equ LOG_ACTION_MAX, 3

.section .text

.global log_control_action
log_control_action:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]

    mov     w19, w0
    adr     x20, log_line_buf
    mov     x1, x20

    sub     w2, w19, #1
    cmp     w2, #LOG_ACTION_MAX
    b.hi    log_action_done

    ldr     x3, =log_action_table
    ldr     x3, [x3, w2, uxtw #3]
    br      x3

log_action_vel_inc:
    ldr     x2, =msg_vel_inc
    ldr     x3, =msg_vel_inc_len
    ldr     w3, [x3]
    bl      log_copy_n
    b       log_action_vel_value

log_action_vel_dec:
    ldr     x2, =msg_vel_dec
    ldr     x3, =msg_vel_dec_len
    ldr     w3, [x3]
    bl      log_copy_n

log_action_vel_value:
    adr     x9, cfg_vel_max
    ldrb    w0, [x9]
    bl      log_format_byte
    ldr     x2, =msg_vel_unit
    ldr     x3, =msg_vel_unit_len
    ldr     w3, [x3]
    bl      log_copy_n
    b       log_action_emit

log_action_risk_inc:
    ldr     x2, =msg_risk_inc
    ldr     x3, =msg_risk_inc_len
    ldr     w3, [x3]
    bl      log_copy_n
    b       log_action_risk_values

log_action_risk_dec:
    ldr     x2, =msg_risk_dec
    ldr     x3, =msg_risk_dec_len
    ldr     w3, [x3]
    bl      log_copy_n

log_action_risk_values:
    adr     x9, cfg_dist_free
    ldrb    w0, [x9]
    bl      log_format_byte
    ldr     x2, =msg_mid_att
    ldr     x3, =msg_mid_att_len
    ldr     w3, [x3]
    bl      log_copy_n
    adr     x9, cfg_dist_att
    ldrb    w0, [x9]
    bl      log_format_byte
    ldr     x2, =msg_mid_unit
    ldr     x3, =msg_mid_unit_len
    ldr     w3, [x3]
    bl      log_copy_n

log_action_emit:
    sub     x1, x1, x20
    mov     x0, x20
    bl      log_write

log_action_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// void log_speed_poll(void) — le STX|0x20|speed|E|C|D|dir|ETX e grava se mudou
.global log_speed_poll
log_speed_poll:
    stp     x29, x30, [sp, #-64]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]

    ldr     x0, =speed_pkt
    str     xzr, [x0]
    mov     x1, #SPEED_LEN
    bl      spi_read_buf

    ldr     x9, =speed_pkt
    ldrb    w0, [x9]
    cmp     w0, #STX
    b.ne    log_speed_done
    ldrb    w0, [x9, #1]
    cmp     w0, #TYPE_SPEED
    b.ne    log_speed_done
    ldrb    w0, [x9, #7]
    cmp     w0, #ETX
    b.ne    log_speed_done

    ldrb    w19, [x9, #2]
    ldrb    w20, [x9, #3]
    ldrb    w21, [x9, #4]
    ldrb    w22, [x9, #5]
    ldrb    w23, [x9, #6]
    and     w23, w23, #0x03

    ldr     x0, =last_tel
    ldrb    w1, [x0]
    cmp     w19, w1
    b.ne    log_speed_changed
    ldrb    w1, [x0, #1]
    cmp     w20, w1
    b.ne    log_speed_changed
    ldrb    w1, [x0, #2]
    cmp     w21, w1
    b.ne    log_speed_changed
    ldrb    w1, [x0, #3]
    cmp     w22, w1
    b.ne    log_speed_changed
    ldrb    w1, [x0, #4]
    cmp     w23, w1
    beq     log_speed_ok

log_speed_changed:
    ldr     x0, =last_tel
    strb    w19, [x0]
    strb    w20, [x0, #1]
    strb    w21, [x0, #2]
    strb    w22, [x0, #3]
    strb    w23, [x0, #4]

    adr     x24, log_line_buf
    mov     x1, x24

    ldr     x2, =msg_tang_speed
    ldr     x3, =msg_tang_speed_len
    ldr     w3, [x3]
    bl      log_copy_n

    mov     w0, w19
    bl      log_format_byte

    ldr     x2, =msg_dist_e
    ldr     x3, =msg_dist_e_len
    ldr     w3, [x3]
    bl      log_copy_n

    mov     w0, w20
    bl      log_format_byte

    ldr     x2, =msg_dist_c
    ldr     x3, =msg_dist_c_len
    ldr     w3, [x3]
    bl      log_copy_n

    mov     w0, w21
    bl      log_format_byte

    ldr     x2, =msg_dist_d
    ldr     x3, =msg_dist_d_len
    ldr     w3, [x3]
    bl      log_copy_n

    mov     w0, w22
    bl      log_format_byte

    ldr     x2, =msg_dir
    ldr     x3, =msg_dir_len
    ldr     w3, [x3]
    bl      log_copy_n

    ldr     x3, =log_dir_table
    lsl     w0, w23, #4
    add     x3, x3, x0
    ldr     x2, [x3]
    ldr     x3, [x3, #8]
    ldr     w3, [x3]
    bl      log_copy_n

    sub     x1, x1, x24
    mov     x0, x24
    bl      log_write

log_speed_ok:
    mov     w0, #0
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

log_speed_done:
    mov     w0, #-1
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// void log_close(void)
.global log_close
log_close:
    ldr x1, =log_fd
    ldr x0, [x1]
    mov x8, #SYS_CLOSE
    svc #0
    ret
