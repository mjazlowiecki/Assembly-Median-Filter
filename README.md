# Median Filter - x64 Assembly & C++ (SIMD + Multithreading)

Project realized as part of the Assembly Languages course at the Silesian University of Technology. 

The application demonstrates the implementation of a non-linear median filter for grayscale images, used for noise reduction (e.g., "salt and pepper" noise). The project puts a strong emphasis on performance optimization, comparing code written in C++ with highly optimized x64 Assembly code.

<img width="1364" height="921" alt="example" src="https://github.com/user-attachments/assets/259e076d-79df-4d35-b91d-615a7e85ba65" />

## Project Architecture
The project was developed using a hybrid architecture in Visual Studio 2022:
* **User Interface (UI):** C# (Windows Forms) - manages image loading, processing parameters, and displaying results.
* **Compute Engine:** A Dynamic-Link Library (DLL) written in C++ and Assembly (MASM x64).

## Key Technologies & Optimizations
* **SIMD Vectorization:** The assembly implementation utilizes SSE vector instructions (`movdqu`, `pminub`, `pmaxub`). This allows the processing of 16 bytes (pixels) simultaneously in a single loop cycle.
* **Multithreading:** The algorithm supports parallel data processing. The image is divided into stripes and processed across multiple threads (from 1 to 12), managed directly from C++ using the `<thread>` library.
* **Sorting Networks:** Instead of classic sorting algorithms with conditional branching (like QuickSort/IntroSort in C++), the ASM version uses a Sorting Network based on MIN/MAX instructions. This approach completely eliminates costly branch prediction errors in the CPU.

## Performance Results
Performance benchmarks revealed a massive advantage of low-level optimization. Using SIMD instructions combined with multithreading yielded the following results for a 2040x2040px image with a 3x3 filter window:
* Execution time (1 C++ thread): **49,486 ms**.
* Execution time (12 ASM threads): **17 ms**.
* **Speedup:** The optimized ASM algorithm executes **2910.9x** faster!

## How to run
1. Clone the repository.
2. Open the `.sln` solution file in Microsoft Visual Studio 2022.
3. Ensure the build configuration is set to **x64** (required for the MASM library).
4. Build the solution and run the application.

> Full project documentation, including mathematical analysis, the final report with all benchmarks, and a presentation, can be found in the `docs` folder.
