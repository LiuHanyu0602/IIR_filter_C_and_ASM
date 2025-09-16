/*
 * iir.s
 */
.syntax unified
	.cpu cortex-m4
	.fpu softvfp
	.thumb
	.equ N_MAX, 10

.section .bss
.align 2
	X_list: 	.space 4*N_MAX        @ Reserve spaces for circular buffers
	Y_list: 	.space 4*N_MAX
	head_index:	.space 4          @ Points to the newest entry in X/Y buffers
	inited_flag:.space 4         @ Initialization flag (0=uninitialized, 1=initialized)
	last_N: 	.space 4              @ Stores last used N value for change detection

.section .text
.align 2
.global iir

// int iir(int N, int* b, int* a, int x_n);
// R0=N, R1=b*, R2=a*, R3=x_n; Returns: R0

/*
Register usage:
R4: Loop counter i
R5: Accumulator for y_n
R6: x[n-i]
R8: y[n-i]
R3: a0 coefficient (a[0])
Others: R0/R1/R2/R12 for temporary/offset calculations
*/

iir:
    PUSH {R4, R5, R6, R8, LR}
    SUB SP, SP, #20             // Reserve space for local variables
    MOV R12, R0                 // R12 = N
    STR R1, [SP, #4]            // push *b, *a, x_n onto the stack
    STR R2, [SP, #8]
    STR R3, [SP, #0]
    LDR R0, =X_list
    STR R0, [SP, #12]           // Store X_list address
    LDR R0, =Y_list
    STR R0, [SP, #16]           // Store Y_list address

// Check initialization status and N value consistency
    LDR R0, =inited_flag
    LDR R1, [R0]
    CMP R1, #0
    BEQ do_clear                // Jump to clear if uninitialized

    LDR R2, =last_N
    LDR R1, [R2]
    CMP R1, R12
    BNE do_clear                // Jump to clear if N changed
    B init_done

// Initialize & Clear buffers
do_clear:
    MOV R4, #0                  // Initialize loop counter
clear_loop:
    CMP R4, #N_MAX
    BGE clear_complete
    LSL R1, R4, #2              // Calculate byte offset
    MOV R2, #0
    LDR R3, [SP, #12]           // Clear X_list and Y_list
    STR R2, [R3,  R1]
    LDR R3, [SP, #16]
    STR R2, [R3,  R1]
    ADD R4, R4, #1
    B clear_loop

clear_complete:
    LDR R0, =head_index
    SUB R1, R12, #1             // head_index = N-1
    STR R1, [R0]
    LDR R0, =inited_flag
    MOV R1, #1
    STR R1, [R0]                // Set initialized flag
    LDR R0, =last_N
    STR R12, [R0]               // Store current N

init_done:
// Calculate base term y_n = (b0 * x_n) / a0
    LDR R0, [SP, #8]            // Load a pointer
    LDR R3, [R0]                // R3 = a[0]
    LDR R0, [SP, #0]            // Load x_n
    LDR R1, [SP, #4]            // Load b pointer
    LDR R1, [R1]                // R1 = b[0]
    MUL R5, R0, R1              // x_n * b0
    SDIV R5, R5, R3             // Divide by a0

// Main filter summation loop (i=1 to N)
    MOV R4, #1                  // Initialize loop counter i
sum_loop:
    CMP R4, R12
    BGT sum_done

// Calculate ring buffer index for historical values
    LDR R0, =head_index
    LDR R2, [R0]                // Load head_index
    SUB R0, R4, #1              // i-1
    SUB R1, R2, R0              // head - (i-1)
    CMP R1, #0
    BPL p_index_cal
    ADD R1, R1, R12             // Wrap around if negative

p_index_cal:
    LSL R1, R1, #2              // Convert to byte offset
    LDR R0, [SP, #12]           // Load X_list address
    LDR R6, [R0, R1]            // Load x[n-i]
    LDR R0, [SP, #16]           // Load Y_list address
    LDR R8, [R0, R1]            // Load y[n-i]

// Calculate filter term: (b[i]*x[n-i] - a[i]*y[n-i]) / a0
    LSL R0, R4, #2
    LDR R1, [SP, #4]
    LDR R1, [R1, R0]
    MUL R1, R1, R6              // b[i] * x[n-i]
    LDR R2, [SP, #8]
    LDR R2, [R2, R0]
    MUL R2, R2, R8              // a[i] * y[n-i]
    SUB R1, R1, R2              // Numerator
    SDIV R1, R1, R3             // Divide by a0
    ADD R5, R5, R1              // Accumulate to y_n

    ADD R4, R4, #1
    B sum_loop

sum_done:
// Update ring buffer with new values
    LDR R0, =head_index
    LDR R1, [R0]
    ADD R1, R1, #1
    CMP R1, R12
    IT EQ
    MOVEQ R1, #0                // Wrap around if needed
    STR R1, [R0]

    LSL R2, R1, #2
    LDR R0, [SP, #12]
    LDR R1, [SP, #0]
    STR R1, [R0, R2]            // Store new x_n
    LDR R0, [SP, #16]
    STR R5, [R0, R2]            // Store unscaled y_n

// Scale output and return
    MOV R1, #100
    SDIV R0, R5, R1             // y_n /= 100

    ADD SP, SP, #20             // Restore stack
    POP {R4, R5, R6, R8, PC}    // Return
