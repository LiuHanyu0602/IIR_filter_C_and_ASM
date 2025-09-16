## I. Discussion of Program Logic

### 1. Data Section (.bss)
- **X_list, Y_list**: Feedforward and feedback queues for input and output history, each allocated `4 * N_MAX` bytes.  
- **inited_flag**: A 4-byte variable ensuring initialization is performed only once.  
- **last_N**: A 4-byte variable storing the filter order from the previous call to detect changes.  
- **head_index**: A 4-byte variable pointing to the most recent entry in the circular buffers.

### 2. Text Section (.text)
- **Function Entry**: Saves registers R4, R5, R6, R8, and LR on the stack.  
- **Initialization**:  
  - Loads input parameters from the C caller.  
  - Clears the queues and sets `head_index` to `N-1`.  
  - Uses `inited_flag` to ensure this runs only once.  
- **Filter Computation**:  
  - Computes the base term `y[n] = (b0 × x[n]) / a0` separately.  
  - Loops over past samples, multiplying stored `x` and `y` values by the corresponding coefficients and accumulating the results.  
  - Uses index `i` to represent the offset from `head_index` in the circular buffer. Negative indices wrap around.  
- **Buffer Update**:  
  - Advances `head_index` and wraps around if needed.  
  - Stores the new `x_n` and computed `y_n` at the updated position, effectively enqueuing the new data and overwriting the oldest entry.  
- **Result Return**:  
  - Divides `y_n` by 100 as required and places it in R0 for return.  
  - Restores saved registers and returns to the C function.

---

## II. Discussion of Improvements

- **Circular Buffer**  
  Replaces shifting all elements with simply moving a pointer, reducing update complexity from O(N) to O(1).

- **Stack Spill for x_n**  
  Saves `x_n` on the stack instead of using a dedicated register, allowing one-time `LDR` access and avoiding extra push/pop of R7 and R11.

- **One-Time Initialization**  
  Clears the buffer and sets `inited_flag` only on the first call to preserve historical data across iterations.

- **Use LSLS #2 Instead of Multiplication**  
  Generates byte offsets by shifting left by two bits, saving ALU instructions.

- **Merged Feedforward and Feedback Computation**  
  Computes `(b[i+1]*X[i] − a[i+1]*Y[i]) / a0` within a single loop, halving loop overhead.

- **Leaf Function Optimization**  
  Since the function makes no subroutine calls, it pushes only the necessary callee-saved registers and returns via `POP {..., pc}`, reducing stack operations.

- **Merged Summation and Shift**  
  Accumulates coefficients and updates buffer slots in one pass, eliminating a second loop and cutting branch and memory traffic in half.

---

## III. Additional Outcomes

- **Direct Form I (DF1) vs. Direct Form II (DF2)**  
  The implemented equation is in **Direct Form I**. Mathematically, DF1 and DF2 are equivalent.  
  <br><img src="https://github.com/user-attachments/assets/f623a599-226a-4c58-9702-08f0fe59e6bc" width="432" height="193">  
  <img src="https://github.com/user-attachments/assets/dc920557-bc09-47c3-927c-b764b77fd501" width="432" height="109">

- **a₀ Default Value**  
  `a₀` is taken as 1 by default, so other coefficients must be adjusted accordingly.  
  <br><img src="https://github.com/user-attachments/assets/0cd88142-09f8-46a0-8643-5e8feedbc0a7" width="432" height="72">  
  <img src="https://github.com/user-attachments/assets/1466f798-e0b0-4ba3-bb6a-b308662ca04d" width="432" height="47">

- **Pros and Cons of DF2**  
  DF2 uses only one buffer and could lower stack usage and loop time. However, testing revealed significant cumulative errors over iterations, so DF1 was retained and the DF2 code kept only for reference.


