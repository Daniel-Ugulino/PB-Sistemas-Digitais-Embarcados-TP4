.equ SYS_OPENAT, 56 // ID da syscall openat (para abrir arquivos).
.equ SYS_READ,   63 // ID da syscall read (para ler do SPI).
.equ SYS_WRITE,  64 // ID da syscall write (para enviar dados ao SPI).
.equ SYS_IOCTL,  29 // ID da syscall ioctl (para enviar comandos de controle do driver).
.equ SYS_CLOSE,  57 // ID da syscall close (para fechar o arquivo).

.equ AT_FDCWD,   -100 // Flag que indica ao openat para usar o diretório de trabalho atual como referência relativa.
.equ O_RDWR,     0x0002 // Flag para abrir o arquivo em modo de Leitura e Escrita (Read/Write).

.equ SPI_IOC_WR_MODE,          0x40016B01 // Comando ioctl para definir o modo SPI (fase e polaridade do relógio - CPOL/CPHA).
.equ SPI_IOC_WR_BITS_PER_WORD, 0x40016B03 // Comando ioctl para definir o tamanho da palavra em bits.
.equ SPI_IOC_WR_MAX_SPEED_HZ,  0x40046B04 // Comando ioctl para definir a velocidade máxima de clock em Hz.

.section .data
spi_path:  .asciz "/dev/spidev0.0" // caminho do dispositivo de hardware no Linux.
spi_mode:  .byte 0 // Define o Modo SPI como 0 (1 byte)
spi_bits:  .byte 8 // Define o tamanho da palavra como 8 bits (1 byte).
.align 2
spi_speed: .word 250000 // Define o clock do SPI em 250 kHz

.section .bss
.align 8
.global spi_fd
spi_fd: .skip 8

.section .text

.global spi_open
spi_open:
    stp x29, x30, [sp, #-16]!

    mov x0, #AT_FDCWD
    ldr x1, =spi_path
    mov x2, #O_RDWR
    mov x3, #0
    mov x8, #SYS_OPENAT
    svc #0

    ldr x1, =spi_fd
    str x0, [x1]

    ldp x29, x30, [sp], #16
    ret

// int spi_is_open(void) — 1 se fd >= 0
.global spi_is_open
spi_is_open:
    ldr x0, =spi_fd
    ldr x0, [x0]
    cmp x0, #0 // Compara o valor com 0. No Linux, um File Descriptor válido é sempre > 0. Valores < 0 indicam erro.
    cset w0, ge // Se x0 >= 0 ? 1 : 0
    ret

.global spi_configure
spi_configure:
    stp x29, x30, [sp, #-16]!

    ldr x1, =SPI_IOC_WR_MODE // Arg 2 do ioctl: Código do comando para alterar o modo.
    ldr x2, =spi_mode // Arg 3 do ioctl: Endereço da variável contendo o valor do modo (0).
    bl  spi_ioctl

    ldr x1, =SPI_IOC_WR_BITS_PER_WORD // Código do comando para alterar os bits por palavra.
    ldr x2, =spi_bits
    bl  spi_ioctl

    ldr x1, =SPI_IOC_WR_MAX_SPEED_HZ // Código para alterar o clock do barramento.
    ldr x2, =spi_speed
    bl  spi_ioctl

    ldp x29, x30, [sp], #16
    ret

spi_ioctl: // Checa se /dev/spidev0.0 esta aberto, caso sim chama a syscall
    ldr x0, =spi_fd
    ldr x0, [x0]
    cmp x0, #0
    b.lt spi_ioctl_skip
    mov x8, #SYS_IOCTL
    svc #0
spi_ioctl_skip:
    ret

.global spi_write_buf
spi_write_buf:
    stp x29, x30, [sp, #-32]!
    stp x0, x1, [sp, #16] // Salva temporariamente os argumentos x0 (ponteiro) e x1 (tamanho) no topo da pilha nos offsets de 16 a 31 bytes.

    ldr x2, =spi_fd // Pega o endereço de spi_fd.
    ldr x0, [x2] // Carrega o manipulador do arquivo em x0
    cmp x0, #0 // Verifica se o arquivo é válido.
    b.lt spi_write_fail

    ldp x1, x2, [sp, #16] // Restaura os parametros originais da pilha, x1 passa a ter os dados de x0, x2 passa a ter os dados de x1
    mov x8, #SYS_WRITE
    svc #0

    ldp x29, x30, [sp], #32
    ret

spi_write_fail:
    mov x0, #-1
    ldp x29, x30, [sp], #32
    ret

.global spi_read_buf
spi_read_buf:
    stp x29, x30, [sp, #-32]!
    stp x0, x1, [sp, #16]

    ldr x2, =spi_fd
    ldr x0, [x2]
    cmp x0, #0
    b.lt spi_read_fail

    ldp x1, x2, [sp, #16]
    mov x8, #SYS_READ
    svc #0

    ldp x29, x30, [sp], #32
    ret

spi_read_fail:
    mov x0, #-1
    ldp x29, x30, [sp], #32
    ret

.global spi_close
spi_close:
    ldr x1, =spi_fd
    ldr x0, [x1]
    cmp x0, #0
    b.lt spi_close_skip
    mov x8, #SYS_CLOSE
    svc #0
spi_close_skip:
    ret
