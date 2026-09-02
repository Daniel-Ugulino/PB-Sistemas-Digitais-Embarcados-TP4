.equ SYS_READ,  63 // ID da syscall sys_read no Linux ARM64 (para ler dados).
.equ SYS_IOCTL, 29 // ID da syscall sys_ioctl (para controlar dispositivos de E/S).
.equ TCGETS,    0x5401 // Comando ioctl para obter o estado atual do terminal.
.equ TCSETS,    0x5402 // Comando ioctl para aplicar um novo estado no terminal.
.equ ICANON,    0x0002 // Mascara de bit do Modo Canonico (espera o Enter para enviar entrada).
.equ ECHO,      0x0008 // Mascara de bit do Eco (exibe na tela a tecla digitada)
.equ STDIN,     0 // File Descriptor da Entrada Padrao (Standard Input)

.section .bss
.align 8
orig_termios: .skip 64 // terminal original
raw_termios:  .skip 64 // novo terminal
key_buf:      .skip 8 // tecla pressionada

.section .text

.global keyboard_init
keyboard_init:
    stp x29, x30, [sp, #-16]!

    mov x0, #STDIN
    mov x1, #TCGETS
    ldr x2, =orig_termios
    mov x8, #SYS_IOCTL
    svc #0

    ldr x0, =orig_termios
    ldr x1, =raw_termios
    mov x2, #64
kb_copy_loop: // Desativa o modo canonico do terminal linux e copia seu estado
    ldrb w3, [x0], #1
    strb w3, [x1], #1
    subs x2, x2, #1
    bne kb_copy_loop // copia orig terminos para raw_termios

    ldr x0, =raw_termios
    ldr w1, [x0, #12]
    mov w2, #ICANON
    orr w2, w2, #ECHO
    bic w1, w1, w2
    str w1, [x0, #12] // junta as duas mascaras e faz um bit clear e salva modificada em raw_terios, desativa o echo e o modo canonico do terminal

    mov w1, #0 // seta 0 para a as configs de VMIN, quantidade minima de caracteres, e VTIME, tempo limite de espera
    strb w1, [x0, #17 + 6]
    strb w1, [x0, #17 + 5]

    // aplica nova configuracao
    mov x0, #STDIN
    mov x1, #TCSETS
    ldr x2, =raw_termios // ponteiro da nova struct
    mov x8, #SYS_IOCTL
    svc #0

    ldp x29, x30, [sp], #16
    ret

.global keyboard_restore
keyboard_restore: // restaura o modo original do terminal
    mov x0, #STDIN
    mov x1, #TCSETS
    ldr x2, =orig_termios
    mov x8, #SYS_IOCTL
    svc #0
    ret

// retorna a tecla pressionada em w0, ou -1 se nada disponivel
.global keyboard_read
keyboard_read:
    stp x29, x30, [sp, #-16]!

    mov x0, #STDIN
    ldr x1, =key_buf
    mov x2, #1
    mov x8, #SYS_READ
    svc #0

    cmp x0, #1
    bne kb_nothing

    ldr x1, =key_buf
    ldrb w0, [x1]

    cmp w0, #0x0A // caso seja /n sai para kb_nothing
    beq kb_nothing
    cmp w0, #0x0D // caso seja /r sai para kb_nothing
    beq kb_nothing

    b kb_read_done

kb_nothing:
    mov w0, #-1

kb_read_done:
    ldp x29, x30, [sp], #16
    ret
