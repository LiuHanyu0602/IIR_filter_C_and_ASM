# Assignment Notes

This project implements an Infinite Impulse Response (IIR) digital filter in ARMv7-M assembly and calls it from C.

## Background

A C program can call an assembly subroutine when the function follows the platform calling convention. On ARM Cortex-M, the first four function arguments are passed in registers `R0` to `R3`, and the return value is placed in `R0`.

An IIR filter uses both previous input samples and previous output samples. For an order `N` filter, the result depends on `x[n]`, past inputs `x[n-i]`, and past outputs `y[n-i]`.

## Function Interface

```c
int iir(int N, int *b, int *a, int x_n);
```

Where:

- `N`: filter order.
- `b`: feedforward coefficient array with `N + 1` elements.
- `a`: feedback coefficient array with `N + 1` elements.
- `x_n`: current input sample.
- return value: current output sample `y_n`.

## Constraints

- The implementation uses integer arithmetic.
- Division is performed with `SDIV`.
- Static memory is used to store delayed input and output values.
- Internal history must be initialized before it is used.
- Results are checked against the reference C implementation in `main.c`.

## Implementation Variants

- `iir_ring_buffer.s`: avoids shifting history arrays by using a circular buffer.
- `iir_2_loop_in_1.s`: combines summation and shifting work into a tighter loop.
