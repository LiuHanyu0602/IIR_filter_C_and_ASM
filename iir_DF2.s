    .syntax unified
    .cpu   cortex-m4
    .fpu   softvfp
    .thumb
    .equ   N_MAX, 10
    .section .bss
    .align  2
W_list:       .space 4*N_MAX        @ 只保留一个历史list：W[n-i]
head_index:   .space 4              @ 指向 W[n-1] 的槽位
inited_flag:  .space 4              @ 0=未初始化；1=已初始化
last_N:       .space 4              @ 记录上一次使用的 N，N 变化时全部重置
    .section .text
    .align  2
    .global iir
    @ int iir(int N, int* b, int* a, int x_n);
    @ R0=N, R1=b*, R2=a*, R3=x_n；返回: R0
/* 寄存器使用：
   R4 : 循环计数 i (1到N)
   R5  : y_acc 分子累加器（b0*W[n] + Σ b[i]*W[n-i]）
   R6  : w_i = W[n-i]
   R9  : Wn_full = W[n]（带 a0 的内部状态）
   R8  : 临时/备用
   R3  : a0（常量）
   R12 : N（备份）
   stack allocation:
     [SP+0]  : x_n
     [SP+4]  : b*
     [SP+8]  : a*
     [SP+12] : &W_list */
iir:
    PUSH    {R4, R5, R6, R8, R9, LR}
    SUB     SP, SP, #16
    MOV     R12, R0                 @ 保存 N
    STR     R1, [SP, #4]            @ b*
    STR     R2, [SP, #8]            @ a*
    STR     R3, [SP, #0]            @ x_n
    LDR     R0, =W_list
    STR     R0, [SP, #12]           @ &W_list
/* 一次性初始化（或在N改变时重置）*/
    LDR     R0, =inited_flag
    LDR     R1, [R0]
    CMP     R1, #0
    BEQ     do_clear
    LDR     R2, =last_N
    LDR     R1, [R2]
    CMP     R1, R12
    BNE     do_clear
    B       init_done
do_clear:
    @ 清零 X/Y list（按 N_MAX）
    MOVS    R4, #0
clear_loop:
    CMP     R4, #N_MAX
    BGE     clear_complete
    LSLS    R1, R4, #2
    MOVS    R2, #0
    LDR     R3, [SP, #12]           @ &W_list
    STR     R2, [R3, R1]            @ W[j] = 0
    ADDS    R4, R4, #1
    B       clear_loop
clear_complete:
    LDR     R0, =head_index
    SUBS    R1, R12, #1             @ head = N-1
    STR     R1, [R0]
    LDR     R0, =inited_flag
    MOVS    R1, #1
    STR     R1, [R0]
    LDR     R0, =last_N
    STR     R12,[R0]
init_done:
/* 取 a0，并用 w[n] = x[n] - Σ a[i]*w[n-i] 的公式
   直接把 x_n 作为 W[n] 的起始值 */
    LDR     R0, [SP, #8]            @ a*
    LDR     R3, [R0]                @ a0  （只作除法用）
    LDR     R9, [SP, #0]            @ R9 = x_n   ← W[n] 初值
/* 同一轮循环里，减 Σa[i]*W[n-i]，加 y_acc += b[i]*W[n-i] */
    MOVS    R5, #0                  @ y_acc = 0
    MOVS    R4, #1                  @ i = 1
df2_loop:
    CMP     R4, R12
    BGT     df2_done                @ i>N, 结束
    @ 列表索引 p_index = (head - (i-1)) mod N
    LDR     R0, =head_index
    LDR     R2, [R0]                @ head 指向 w[n-1]
    MOV     R0, R4
    SUBS    R0, R0, #1              @ R0 = i-1
    SUB     R1, R2, R0              @ p = head - (i-1)
    CMP     R1, #0
    BPL     p_index_cal
    ADDS    R1, R1, R12             @ 取模
p_index_cal:
    LSLS    R1, R1, #2              @ R1 = p * 4
    @ 取 w_i = W[p_index]
    LDR     R0, [SP, #12]           @ &W_list
    LDR     R6, [R0, R1]            @ R6 = W[n-i]
    @ Wn -= a[i]*W[n-i]
    LSLS    R0, R4, #2              @ off_i = 4*i
    LDR     R2, [SP, #8]            @ a*
    LDR     R2, [R2, R0]            @ a[i]
    MUL     R2, R2, R6
    SUB     R9, R9, R2
    @ y_acc += (b[i]*W[n-i]) / a0     （逐项 /a0，向 0 截断）
    LDR     R2, [SP, #4]            @ b*
    LDR     R2, [R2, R0]            @ b[i]
    MUL     R2, R2, R6              @ b[i] * W[n-i]
    ADD     R5, R5, R2              @ y_acc += b[i]*W[n-i]
    ADDS    R4, R4, #1              @ i++
    B       df2_loop
df2_done:
    SDIV    R9, R9, R3              @ Wn = Wn / a0   （R3 = a0）
    /*  y_n = b0*W[n] + Σ b[i]*W[n-i]  */
    LDR     R1, [SP, #4]            @ b*
    LDR     R1, [R1]                @ b0
    MUL     R1, R1, R9              @ b0 * Wn（Wn 已/ a0）
    ADD     R5, R5, R1              @ y_full = y_acc + b0*Wn
    @ 前移 head：指向“最新历史”的槽位（写入 W[n]）
    LDR     R0, =head_index
    LDR     R1, [R0]                  @ R1 = head
    ADDS    R1, R1, #1                @ head++
    CMP     R1, R12
    IT      EQ
    MOVEQ   R1, #0                    @ head==N → 回绕到 0
    STR     R1, [R0]                  @ 保存新的 head
    @ 把本轮的 W[n] 写入环形list
    LSLS    R2, R1, #2                @ R2 = head*4
    LDR     R0, [SP, #12]             @ &W_list
    STR     R9, [R0, R2]              @ W_list[head] = Wn_full
/*  缩放：y = y_n / 100 */
    MOVS    R1, #100
    SDIV    R0, R5, R1                @ R0 = y_full / 100
    ADD     SP, SP, #16
    POP     {R4, R5, R6, R8, R9, PC}




