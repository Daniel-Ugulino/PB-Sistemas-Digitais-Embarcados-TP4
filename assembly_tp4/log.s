.equ SYS_OPENAT, 56
.equ SYS_WRITE,  64
.equ SYS_CLOSE,  57
.equ AT_FDCWD,   -100

.equ O_WRONLY,   0x0001
.equ O_CREAT,    0x0040
.equ O_APPEND,   0x0400

.equ MODE_0644,  0x1A4

.section .data
log_path: .asciz "spi_log.txt"
newline:  .ascii "\n"

msg_vel_inc:    .ascii "Vel. max aumentada para "
msg_vel_inc_len: .quad . - msg_vel_inc
msg_vel_dec:    .ascii "Vel. max reduzida para "
msg_vel_dec_len: .quad . - msg_vel_dec
msg_vel_unit:   .ascii " km/h"
msg_vel_unit_len: .quad . - msg_vel_unit

msg_risk_inc:   .ascii "Zona de risco aumentada: livre="
msg_risk_inc_len: .quad . - msg_risk_inc
msg_risk_dec:   .ascii "Zona de risco reduzida: livre="
msg_risk_dec_len: .quad . - msg_risk_dec
msg_mid_att:    .ascii " m atencao="
msg_mid_att_len: .quad . - msg_mid_att
msg_mid_unit:   .ascii " m"
msg_mid_unit_len: .quad . - msg_mid_unit

msg_log_pre:    .ascii "Log - "
msg_log_pre_len: .quad . - msg_log_pre
msg_avg_pre:    .ascii "AVG - "
msg_avg_pre_len: .quad . - msg_avg_pre
msg_tel_vel:    .ascii "vel="
msg_tel_vel_len: .quad . - msg_tel_vel
msg_tel_e:      .ascii " dist_e="
msg_tel_e_len:  .quad . - msg_tel_e
msg_tel_c:      .ascii " dist_c="
msg_tel_c_len:  .quad . - msg_tel_c
msg_tel_d:      .ascii " dist_d="
msg_tel_d_len:  .quad . - msg_tel_d
msg_tel_dir:    .ascii " dir="
msg_tel_dir_len: .quad . - msg_tel_dir

// LUT dir_fuga (assist_control.v): indice = 2 bits do pacote
dir_str_frente:   .ascii "frente"
dir_len_frente:   .quad . - dir_str_frente
dir_str_esquerda: .ascii "esquerda"
dir_len_esquerda: .quad . - dir_str_esquerda
dir_str_direita:  .ascii "direita"
dir_len_direita:  .quad . - dir_str_direita
dir_str_tras:     .ascii "tras"
dir_len_tras:     .quad . - dir_str_tras

.align 3
dir_lut_ptr:
    .quad dir_str_frente
    .quad dir_str_esquerda
    .quad dir_str_direita
    .quad dir_str_tras
dir_lut_len:
    .quad dir_len_frente
    .quad dir_len_esquerda
    .quad dir_len_direita
    .quad dir_len_tras
        
msg_tel_ve:     .ascii " vel_e="
msg_tel_ve_len: .quad . - msg_tel_ve
msg_tel_vc:     .ascii " vel_c="
msg_tel_vc_len: .quad . - msg_tel_vc
msg_tel_vd:     .ascii " vel_d="
msg_tel_vd_len: .quad . - msg_tel_vd
msg_session:    .ascii "---------------NEW INIT -------------------"
msg_session_len: .quad . - msg_session
msg_sep:        .ascii "----------------------------------------------------------------------------------"
msg_sep_len:    .quad . - msg_sep

.extern cfg_dist_free
.extern cfg_dist_att
.extern cfg_vel_max
.extern filt_pkt

.section .bss
.align 8
log_fd:       .skip 8
log_line_buf: .skip 128

.section .text

.global log_init
log_init:
    stp     x29, x30, [sp, #-16]!

    mov     x0, #AT_FDCWD
    ldr     x1, =log_path
    mov     x2, #O_WRONLY
    orr     x2, x2, #O_CREAT
    orr     x2, x2, #O_APPEND
    mov     x3, #MODE_0644
    mov     x8, #SYS_OPENAT
    svc     #0

    ldr     x1, =log_fd
    str     x0, [x1]

    ldr     x0, =msg_session
    ldr     x1, =msg_session_len
    ldr     x1, [x1]
    bl      log_write

    ldp     x29, x30, [sp], #16
    ret

.global log_write
log_write:
    stp     x29, x30, [sp, #-32]!
    stp     x0, x1, [sp, #16]

    ldr     x2, =log_fd
    ldr     x0, [x2]
    cmp     x0, #0
    b.lt    log_write_skip
    ldp     x1, x2, [sp, #16]
    mov     x8, #SYS_WRITE
    svc     #0

    ldr     x2, =log_fd
    ldr     x0, [x2]
    ldr     x1, =newline
    mov     x2, #1
    mov     x8, #SYS_WRITE
    svc     #0
log_write_skip:
    ldp     x29, x30, [sp], #32
    ret

log_copy_n:
    cbz     w3, log_copy_n_done
log_copy_n_loop:
    ldrb    w4, [x2], #1
    strb    w4, [x1], #1
    subs    w3, w3, #1
    b.ne    log_copy_n_loop
log_copy_n_done:
    ret

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

log_format_sbyte:
    sxtb    w0, w0
    tbz     w0, #31, log_format_byte
    mov     w2, #'-'
    strb    w2, [x1], #1
    neg     w0, w0
    b       log_format_byte

// w0 = dir_fuga 0..3; x1 = dest. LUT: 0 frente, 1 esquerda, 2 direita, 3 tras
log_format_dir:
    and     w0, w0, #3
    ldr     x2, =dir_lut_ptr
    ldr     x2, [x2, w0, uxtw #3]
    ldr     x3, =dir_lut_len
    ldr     x3, [x3, w0, uxtw #3]
    ldr     w3, [x3]
    b       log_copy_n

// x19 = pkt 11 bytes, x1 = dest; devolve x1 avancado
log_format_fields:
    stp     x29, x30, [sp, #-16]!

    ldr     x2, =msg_tel_vel
    ldr     x3, =msg_tel_vel_len
    ldr     w3, [x3]
    bl      log_copy_n
    ldrb    w0, [x19, #2]
    bl      log_format_byte
    ldr     x2, =msg_vel_unit
    ldr     x3, =msg_vel_unit_len
    ldr     w3, [x3]
    bl      log_copy_n

    ldr     x2, =msg_tel_e
    ldr     x3, =msg_tel_e_len
    ldr     w3, [x3]
    bl      log_copy_n
    ldrb    w0, [x19, #3]
    bl      log_format_byte

    ldr     x2, =msg_tel_c
    ldr     x3, =msg_tel_c_len
    ldr     w3, [x3]
    bl      log_copy_n
    ldrb    w0, [x19, #4]
    bl      log_format_byte

    ldr     x2, =msg_tel_d
    ldr     x3, =msg_tel_d_len
    ldr     w3, [x3]
    bl      log_copy_n
    ldrb    w0, [x19, #5]
    bl      log_format_byte

    ldr     x2, =msg_tel_ve
    ldr     x3, =msg_tel_ve_len
    ldr     w3, [x3]
    bl      log_copy_n
    ldrb    w0, [x19, #6]
    bl      log_format_sbyte

    ldr     x2, =msg_tel_vc
    ldr     x3, =msg_tel_vc_len
    ldr     w3, [x3]
    bl      log_copy_n
    ldrb    w0, [x19, #7]
    bl      log_format_sbyte

    ldr     x2, =msg_tel_vd
    ldr     x3, =msg_tel_vd_len
    ldr     w3, [x3]
    bl      log_copy_n
    ldrb    w0, [x19, #8]
    bl      log_format_sbyte

    ldr     x2, =msg_tel_dir
    ldr     x3, =msg_tel_dir_len
    ldr     w3, [x3]
    bl      log_copy_n
    ldrb    w0, [x19, #9]
    bl      log_format_dir

    ldp     x29, x30, [sp], #16
    ret

.section .rodata
.align 3
log_action_table:
    .quad log_action_vel_inc
    .quad log_action_vel_dec
    .quad log_action_risk_inc
    .quad log_action_risk_dec
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

// void log_telemetry(const uint8_t *raw_pkt)
//   Log - vel=.. dist_e=.. ... dir=frente|esquerda|direita|tras
//   AVG - vel=.. dist_e=.. ... dir=frente|esquerda|direita|tras
//   ----------------------------------------------------------------------------------
.global log_telemetry
log_telemetry:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]

    mov     x19, x0
    adr     x20, log_line_buf
    mov     x1, x20
    ldr     x2, =msg_log_pre
    ldr     x3, =msg_log_pre_len
    ldr     w3, [x3]
    bl      log_copy_n
    bl      log_format_fields
    sub     x1, x1, x20
    mov     x0, x20
    bl      log_write

    ldr     x19, =filt_pkt
    adr     x20, log_line_buf
    mov     x1, x20
    ldr     x2, =msg_avg_pre
    ldr     x3, =msg_avg_pre_len
    ldr     w3, [x3]
    bl      log_copy_n
    bl      log_format_fields
    sub     x1, x1, x20
    mov     x0, x20
    bl      log_write

    ldr     x0, =msg_sep
    ldr     x1, =msg_sep_len
    ldr     x1, [x1]
    bl      log_write

    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.global log_close
log_close:
    ldr     x1, =log_fd
    ldr     x0, [x1]
    cmp     x0, #0
    b.lt    log_close_skip
    mov     x8, #SYS_CLOSE
    svc     #0
log_close_skip:
    ret
