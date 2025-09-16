# IIR Filter — Background & Assignment Guide

This document introduces the background concepts of Infinite Impulse Response (IIR) filters and summarizes the assignment brief for implementing an ARMv7‑M assembly version of an IIR filter callable from C.

---

## 1. Background Concepts

A function or subroutine can be programmed in assembly language and called from a C program. A well‑written assembly function can execute faster than its C counterpart.

**Infinite impulse response (IIR) filters** are digital filters whose impulse response does **not** become exactly zero after a finite number of samples; it continues indefinitely. In practice, the response typically decays toward zero and can be neglected after some point.

For simplicity, assume the IIR filter has the same feedforward and feedback order \(N\). The output \(y[n]\) relates to the input \(x[n]\) as:

$$
\begin{aligned}
y[n]
&= \frac{1}{a_0}\Big( b_0 x[n] + b_1 x[n-1] + \cdots + b_N x[n-N]
      - a_1 y[n-1] - a_2 y[n-2] - \cdots - a_N y[n-N] \Big) \\
&= \frac{1}{a_0}\!\left(\sum_{i=0}^{N} b_i\,x[n-i] \;-\; \sum_{j=1}^{N} a_j\,y[n-j]\right) \\
&= \frac{b_0}{a_0}\x[n] \+\ \frac{1}{a_0}\\left(\sum_{i=1}^{N}\big(b_i x[n-i] - a_i y[n-i]\big)\right).
\end{aligned}
$$



**Notation**

- \(x[n]\): current input sample.  
- \(x[n-i]\): input delayed by \(i\) samples.  
- \(y[n]\): current output sample.  
- \(y[n-i]\): previous output delayed by \(i\) samples.  
- \(N\): filter order; an \(N^{\text{th}}\)-order filter has \(N{+}1\) feedforward terms and \(N\) feedback terms.  
- \(b_i\): feedforward coefficients (\(i=0\ldots N\)).  
- \(a_i\): feedback coefficients (\(i=0\ldots N\)).

**Block diagram intuition**  
In standard diagrams, \(z^{-1}\) denotes a one‑sample delay (the upper box’s value is a one‑sample‑delayed version of the value directly below it). Depending on the coefficient set, IIR filters can realize high‑pass, low‑pass, band‑pass, or band‑reject responses. Compared with FIR, IIR can meet specs (passband/stopband/ripple/roll‑off) with fewer computations per sample.

**Additional resource**  
A concise video explainer (watch **5:41–10:00**): <https://www.youtube.com/watch?v=QRMe02kzVkA&t=341s>

---

## 2. Objectives

Implement the following ARMv7‑M assembly function, callable from C:

```c
int iir(int N, int* b, int* a, int x_n);
```

Where:

- **`y_n`** — the function’s return value — is the current output sample \(y[n]\).  
- **`N`** — filter order; a constant **`N_MAX`** (assume **10**) is defined in `main.c` and must also be declared in `iir.s`. Require `N ≤ N_MAX`.  
- **`b`** — pointer to an array of **N+1** feedforward coefficients `b0 … bN`.  
- **`a`** — pointer to an array of **N+1** feedback coefficients `a0 … aN`.  
- **`x_n`** — current input sample \(x[n]\).

> The internal memory holding delayed versions of `x_n` and `y_n` is **not guaranteed to be zero** at program start. Because the recursion uses past outputs, invalid/garbage history must not be used. Proper one‑time initialization is required.

A reference C implementation `iir_c()` is provided to compare results printed in STM32CubeIDE’s console.

---

## 3. Getting Started

### (a) Initial Program Layout

- **`iir.s`** — write the ARMv7‑M assembly implementation here.  
- **`main.c`** — C driver that calls your assembly function.

### (b) Parameter Passing (AAPCS for Cortex‑M)

Arguments from C are passed in **R0–R3**; return value is in **R0**:

```c
extern int iir(arg1, arg2, ...);
// arg1 -> R0, arg2 -> R1, arg3 -> R2, arg4 -> R3; return -> R0
```

### (c) Procedure & Constraints

- The assembly program only handles **integers**. Use **`SDIV`** for divisions.  
- **Allocate sufficient static memory** to store delayed values of `x_n` and the previously generated `y_n` inside the assembly module (e.g., `.bss`/`.lcomm`).  
- Declare **`N_MAX`** in `iir.s` as well (even if it’s `#define`d in C), because the assembly needs static storage sized to the maximum order.  
- Your assembly must work for any valid parameter set with `N ≤ N_MAX`; arrays `a` and `b` each have **N+1** elements; the input buffer size (if any) must be ≥ **N+1**.  
- Verify correctness by comparing with `iir_c()` outputs printed to the console.

---

## 4. Hints & Implementation Notes

- Prefer a **circular buffer** for histories to avoid O(N) shifts (update becomes O(1)).  
- Use simple address arithmetic where possible (e.g., `LSLS #2` for 32‑bit word offsets).  
- Guard **one‑time initialization** with a flag to avoid resetting valid history on subsequent calls.  
- Treat \(a_0=1\) if specified; otherwise divide by \(a_0\) where required.  
- Keep the function **leaf** (no sub‑calls) to minimize prologue/epilogue overhead.  
- Cross‑check results against the C version on corner cases (e.g., step input, impulse, constant input).

---

## 5. References

- Oppenheim & Schafer, *Discrete‑Time Signal Processing*.  
- ARM® Architecture Procedure Call Standard (AAPCS).  
- STM32CubeIDE user docs.
