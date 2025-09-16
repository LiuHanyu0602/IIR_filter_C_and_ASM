    .syntax unified
    .cpu   cortex-m4
    .fpu   softvfp
    .thumb
    .equ   N_MAX, 10

    .section .bss
    .align 2
X_list:       .space 4*N_MAX      @ x 的历史（int32）
Y_list:       .space 4*N_MAX      @ y 的历史（未/100 的 y_full）
inited_flag:  .space 4            @ 首次清零标志：0 未清、1 已清

    .section .text
    .align 2
    .global iir
    @ int iir(int N, int* b, int* a, int x_n);
    @ R0=N, R1=b*, R2=a*, R3=x_n；返回值放 R0

@ 寄存器分配（尽量少占)：
@  R4 : 循环计数 j
@  R5 : 累加器 y_full（未/100的）
@  R3 : a0（循环内保持不变）
@  R6 : x_cur 保存“当前旧的 X[j]”
@  R8 : y_cur 保存“当前旧的 Y[j]”
@  R12: 临时/偏移
@  stack：
@   [sp+0]  : x_n
@   [sp+4]  : b*
@   [sp+8]  : a*
@   [sp+12] : &X_list
@   [sp+16] : &Y_list
@  仅保留 {R4, R5, LR}

iir:
    PUSH    {R4, R5, LR}
    SUB     SP, SP, #20
    MOV     R12, R0                 @ copy备份 N
    STR     R1,  [SP, #4]           @ 存 b*
    STR     R2,  [SP, #8]           @ 存 a*
    STR     R3,  [SP, #0]           @ 存 x_n
    LDR     R0, =X_list
    STR     R0,  [SP, #12]
    LDR     R0, =Y_list
    STR     R0,  [SP, #16]

    @ initial一次性清零
    LDR     R0, =inited_flag
    LDR     R1, [R0]
    CMP     R1, #0
    BNE     init_done
    MOVS    R4, #0
clear_loop:
    CMP     R4, #N_MAX
    BGE     set_inited
    LSLS    R1, R4, #2
    MOVS    R2, #0
    LDR     R3, [SP, #12]           @ &X
    STR     R2, [R3, R1]
    LDR     R3, [SP, #16]           @ &Y
    STR     R2, [R3, R1]
    ADDS    R4, R4, #1
    B       clear_loop
set_inited:
    MOVS    R2, #1
    STR     R2, [R0]
init_done:
    @ a0 装入 R3
    LDR     R0, [SP, #8]            @ r0 = a*
    LDR     R3, [R0]                @ r3 = a0
    @ 基项 y_n = (x_n*b0)/a0
    LDR     R0, [SP, #0]            @ x_n
    LDR     R1, [SP, #4]            @ &b
    LDR     R1, [R1]                @ b0
    MUL     R5, R0, R1
    SDIV    R5, R5, R3              @ r5 =  y_n（未/100）
    @  合并循环：j = N-1 .. 1，先sum后shift
    MOV     R4, R12
    SUBS    R4, R4, #1              @ j = N-1
    BLE     do_j0                   @ 若 N<=1，直接处理 j=0
    @ 预取 j=N-1 处的旧值
    LSL     R0, R4, #2              @ r0 = offset_j = 4*j
    LDR     R1, [SP, #12]           @ &X
    LDR     R6, [R1, R0]            @ x_cur = X[j]
    LDR     R1, [SP, #16]           @ &Y
    LDR     R8, [R1, R0]            @ y_cur = Y[j]

sumshift_loop: @ ---- 求和（使用“旧值”）
    @  1.(b[j+1]*x_cur)/a0
    ADD     R12, R0, #4             @ r12 = offset_j+1
    LDR     R1, [SP, #4]            @ &b
    LDR     R1, [R1, R12]           @ b[j+1]
    MUL     R2, R1, R6
    SDIV    R2, R2, R3              @ r2 = term1
    @  2.(a[j+1]*y_cur)/a0
    LDR     R1, [SP, #8]            @ &a
    LDR     R1, [R1, R12]           @ a[j+1]
    MUL     R1, R1, R8
    SDIV    R1, R1, R3              @ r1 = term2
    SUB     R2, R2, R1              @ 1 - 2
    ADD     R5, R5, R2              @ y_n += 上式
    @ 右移一格（仍使用“旧值”）
    @ 右移：把 j-1 的旧值搬到 j
    SUB     R12, R0, #4             @ r12 = offset_prev = 4*(j-1)
    LDR     R1, [SP, #12]           @ &X
    LDR     R6, [R1, R12]           @ x_next = X[j-1]（旧）
    STR     R6, [R1, R0]            @ X[j]   = x_next
    LDR     R1, [SP, #16]           @ &Y
    LDR     R8, [R1, R12]           @ y_next = Y[j-1]（旧）
    STR     R8, [R1, R0]            @ Y[j]   = y_next
    @ 用 next 作为下一轮的“旧值”
    @ 下一轮：j--，offset_j ← offset_prev，x_cur/y_cur ← next
    MOV     R0, R12                 @ offset_j = offset_prev
    SUBS    R4, R4, #1              @ j--
    BGT     sumshift_loop           @ 仍 >0 则继续

    @ 退出后此时 j==0，x_cur/y_cur 已等于 X[0]/Y[0]（旧）
do_j0:
    @ 再读一次 X[0]/Y[0] 的旧值
    LDR     R1, [SP, #12]           @ &X
    LDR     R6, [R1]                @ x_cur = X[0]
    LDR     R1, [SP, #16]           @ &Y
    LDR     R8, [R1]                @ y_cur = Y[0]
    @ 把 j=0 的项补上：用 b[1]/a[1] 与 x_cur/y_cur
    MOVS    R12, #4                 @ off_{0+1} = 4
    LDR     R1, [SP, #4]            @ &b
    LDR     R1, [R1, R12]           @ b[1]
    MUL     R2, R1, R6
    SDIV    R2, R2, R3              @ term1
    LDR     R1, [SP, #8]            @ &a
    LDR     R1, [R1, R12]           @ a[1]
    MUL     R1, R1, R8
    SDIV    R1, R1, R3              @ term2
    SUBS    R2, R2, R1
    ADDS    R5, R5, R2              @ y_n 完成
    @ 写入最新一轮
    LDR     R0, [SP, #12]           @ &X
    LDR     R1, [SP, #16]           @ &Y
    LDR     R2, [SP, #0]            @ x_n
    STR     R2, [R0]                @ X[0] = x_n
    STR     R5, [R1]                @ Y[0] = y_n
    @ 返回 y = y_n / 100
    MOVS    R1, #100
    SDIV    R0, R5, R1

    ADD     SP, SP, #20
    POP     {R4, R5, PC}
