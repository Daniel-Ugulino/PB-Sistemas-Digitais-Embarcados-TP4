.equ STEP_DIST, 5
.equ STEP_VEL,  5

.extern cfg_dist_free
.extern cfg_dist_att
.extern cfg_vel_max

.section .rodata
.align 3
key_table:
    .quad increase_risk_zone // a
    .quad control_ignore // b
    .quad control_ignore // c
    .quad reduce_risk_zone // d
    .quad control_ignore // e
    .quad control_ignore // f
    .quad control_ignore // g
    .quad control_ignore // h
    .quad control_ignore // i
    .quad control_ignore // j
    .quad control_ignore // k
    .quad control_ignore // l
    .quad control_ignore // m
    .quad control_ignore // n
    .quad control_ignore // o
    .quad control_ignore // p
    .quad control_ignore // q
    .quad control_ignore // r
    .quad reduce_max_speed // s
    .quad control_ignore // t
    .quad control_ignore // u
    .quad control_ignore // v
    .quad increase_max_speed // w
.equ KEY_TABLE_MAX, 22

.section .text

.global control

control:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]

    orr     w0, w0, #0x20 // Faz um OR bit a bit entre w0 e #0x20 forcando toda letra a virar minuscula
    sub     w1, w0, #'a' // Subtrai o codigo asci do caracter a do valor que esta em w0, para conseguir o index da look up table, EX d: 100 - 97 = 3
    cmp     w1, #KEY_TABLE_MAX
    b.hi    control_ignore

    ldr     x2, =key_table
    ldr     x3, [x2, w1, uxtw #3] // Instrucao que acessa a tabela, deslocando w1 3 bits para esquerda, o mesmo que multiplicar por 8 devido ao quad da tabela
    br      x3

control_ignore:
    mov     w0, #0
    b       control_ret

increase_max_speed:
    mov     w1, #STEP_VEL
    mov     w19, #0x01
    b       apply_speed

reduce_max_speed:
    mov     w1, #-STEP_VEL
    mov     w19, #0x02

apply_speed:
    adr     x9, cfg_vel_max
    bl      adjust_byte
    b       control_log

increase_risk_zone:
    mov     w1, #STEP_DIST
    mov     w19, #0x03
    b       apply_risk_zone

reduce_risk_zone:
    mov     w1, #-STEP_DIST
    mov     w19, #0x04

apply_risk_zone:
    adr     x9, cfg_dist_free
    bl      adjust_byte
    adr     x9, cfg_dist_att
    bl      adjust_byte

control_log:
    mov     w0, w19
    bl      log_control_action
    bl      config_init
    mov     w0, w19

control_ret:
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// saturando em 0..255
adjust_byte:
    ldrb    w2, [x9] // Le 1 byte (8 bits) do endereco apontado por x9 e guarda no registrador w2.
    add     w2, w2, w1 // Soma o valor do passo
    cmp     w2, #255 // compara com 255
    mov     w3, #255 // coloca 255 em w3
    csel    w2, w2, w3, le // Caso w2 for menor que 255 mentem seu valor, caso contrario e substituido pelo valor de w3
    cmp     w2, #0
    csel    w2, w2, wzr, ge // Caso w2 for maior igual a zero mantem seu resultado, contrario substitui pelo registrador wzr, que sempre vale 0
    strb    w2, [x9]
    ret
