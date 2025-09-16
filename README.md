# IIR_filter_C_and_ASM
A function or subroutine can be programmed in assembly language and called from a C program. A well-written assembly language function could execute faster than its C counterpart.

Infinite impulse response (IIR) filters are filters with the property that are distinguished by having an impulse response that does not become exactly zero past a certain point but continues indefinitely. In practice, the impulse response usually approaches zero and can be neglected past a certain point.

For simplicity, we will assume the IIR filter has similar feedforward and feedback filter order N, where the value of the output is related to the input signal

where:

x[n] is the input signal,
x[n-i] is the input signal delayed by i samples,
y[n] is the output signal,
y[n-i] is the previous output signal by i samples,
N is the filter order; an Nth-order filter has (N+1) terms on the right-hand side
bi is the value of the impulse response at the ith instant for 0 ≤ i ≤ N of feedforward IIR filter of Nth order, i.e., bi is a coefficient of the filter.
ai is the value of the impulse response at the ith instant for 0 ≤ i ≤ N of feedback IIR filter of Nth order, i.e., ai is a coefficient of the filter.

To know more about IIR filters you can watch the video snippet from the following link. https://www.youtube.com/watch?v=QRMe02kzVkA&t=341s(From 5:41 to 10:00) 

Objectives
The objective is to develop an ARMv7-M assembly language function which implements the function int iir(int N, int* b, int* a, int x[i]); where,

y_n is the current output returned from the iir() function.
N is the order of the filter. For memory allocation purposes, a constant N_MAX is defined in main.c (you will have to declare a constant N_MAX in iir.s files). The variable N has to be less than or equal to N_MAX. For this assignment, you can assume N_MAX is always 10. 
b is a pointer to an array containing N+1 filter coefficients (b0 to bN).
a is a pointer to an array containing N+1 filter coefficients (a0 to aN).
x_n is the current x[n] passed to the function.

The internal memory (for storing the delayed versions of x_n) is not guaranteed to be 0s when the main function starts executing. Since the output y_n will vary because of the feedback, we will need to make sure that the delayed versions of x_n that are not valid are not taken into account in the calculation.

 Initial Configuration of Programs

iir.s: which is where we will write the assembly language function.
main.c: which is a C program that calls our assembly function.

In general, parameters can be passed between a C program and an assembly language function through the ARM Cortex-M3 registers. In the following example:

extern int iir(arg1, arg2, …);

arg1 will be passed to the assembly language function iir() in the R0 register, arg2 will be passed in the R1 register, and so on. The return value of the assembly language function can be passed back to the C program through the R0 register.

Write the code for the assembly language function iir().

Verify the correctness of the results computed by the function you have written that appears in the console window of the STM32CubeIDE. A C language function iir_c() is provided as a reference.
