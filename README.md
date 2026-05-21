# IIR Filter in C and ARM Assembly

This repository contains an embedded systems assignment implementing an Infinite Impulse Response (IIR) digital filter in C and ARM Cortex-M assembly.

The project compares a reference C implementation with optimized assembly implementations that can be called directly from C using the ARM Architecture Procedure Call Standard (AAPCS).

## Project Goals

- Implement an integer IIR filter in ARMv7-M assembly.
- Call the assembly function from a C test driver.
- Compare assembly output against a reference C implementation.
- Explore history-buffer management and assembly-level optimization.

## IIR Filter Form

For a filter of order `N`, the output sample is computed from current and previous input/output samples:

```text
y[n] = (b0*x[n] + b1*x[n-1] + ... + bN*x[n-N]
       - a1*y[n-1] - ... - aN*y[n-N]) / a0
```

The implementation uses scaled integers instead of floating point values. Coefficients such as `1.00`, `2.50`, and `3.60` are represented as `100`, `250`, and `360`.

## Repository Layout

```text
.
├── main.c              # C test driver and reference IIR implementation
├── iir_ring_buffer.s   # ARM assembly implementation using circular buffers
├── iir_2_loop_in_1.s   # ARM assembly implementation merging sum and shift logic
├── docs/               # Assignment and implementation notes
└── README.md
```

## Main Files

- `main.c`: defines test coefficients, input samples, the reference `iir_c()` function, and calls the assembly `iir()` function.
- `iir_ring_buffer.s`: stores input/output history in circular buffers to avoid shifting arrays on every sample.
- `iir_2_loop_in_1.s`: combines summation and history shifting to reduce loop overhead.

## Function Interface

```c
extern int iir(int N, int *b, int *a, int x_n);
```

Argument passing follows AAPCS for Cortex-M:

```text
R0 = N
R1 = b pointer
R2 = a pointer
R3 = x_n
R0 = return value y_n
```

## Build Notes

This project is intended for ARM Cortex-M / STM32CubeIDE-style coursework. Enable semihosting to view the `printf()` comparison output from `main.c`.

The selected assembly file should export the symbol `iir`, matching the C declaration in `main.c`.

## Notes

The repository is kept close to the final assignment version. The source files are intentionally not heavily refactored so the C reference and assembly implementations remain easy to compare.
