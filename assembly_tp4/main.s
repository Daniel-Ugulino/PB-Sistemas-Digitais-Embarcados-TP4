.equ SYS_EXIT,      93
.equ SYS_NANOSLEEP, 101

.section .data
sleep_spec: .quad 0, 10000000
spi_announced: .byte 0

.section .text
.global _start

_start:
    bl keyboard_init
    bl log_init
    bl spi_open
    bl spi_configure
    bl config_init
    bl ui_init
    bl ui_show_config

    bl spi_is_open
    cmp w0, #0
    beq spi_show_fail
    bl ui_show_spi_wait
    b main_loop
spi_show_fail:
    bl ui_show_spi_fail

main_loop:
    bl keyboard_read

    cmp w0, #-1
    beq no_key

    mov w19, w0

    cmp w19, #'q'
    beq quit
    cmp w19, #'Q'
    beq quit

    mov w0, w19
    bl ui_show_key

    mov w0, w19
    bl control

    cmp w0, #0
    beq no_key

    bl ui_show_config

no_key:
    bl log_speed_poll
    mov w19, w0
    bl ui_show_spi_rx
    cmp w19, #0
    bne skip_spi_msg

    ldr x0, =spi_announced
    ldrb w1, [x0]
    cbnz w1, skip_spi_msg
    mov w1, #1
    strb w1, [x0]
    bl ui_show_spi_ok

skip_spi_msg:
    mov x0, #0
    ldr x1, =sleep_spec
    mov x2, #0
    mov x8, #SYS_NANOSLEEP
    svc #0

    b main_loop

quit:
    bl keyboard_restore
    bl ui_restore
    bl log_close
    mov x0, #0
    mov x8, #SYS_EXIT
    svc #0