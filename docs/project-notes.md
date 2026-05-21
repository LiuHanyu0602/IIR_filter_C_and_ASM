# Project Notes

This repository is kept in a compact coursework layout. The code is intentionally preserved close to the submitted/demo version.

## Files

- `main.c`: C driver, test vectors, reference IIR implementation, and semihosting output.
- `iir_ring_buffer.s`: ARMv7-M assembly implementation using circular buffers for input/output history.
- `iir_2_loop_in_1.s`: ARMv7-M assembly implementation that combines summation and history update work.

## Implementation Details

- The filter order is limited by `N_MAX = 10`.
- Coefficients and samples are represented as integers scaled by 100.
- The assembly function follows the C-callable interface `int iir(int N, int *b, int *a, int x_n)`.
- Historical input/output values are stored in static assembly memory.
- Output is compared against `iir_c()` in `main.c`.

## Clean Repository Choices

- Build output and local IDE files are ignored by `.gitignore`.
- Source files remain at the repository root because this is a small completed assignment project.
- The README is concise so the repository is easier to browse on GitHub.
