# Median Filter - x64 Assembly & C++ (SIMD + Multithreading)

[cite_start]Project realized as part of the Assembly Languages course at the Silesian University of Technology[cite: 3, 181]. 

[cite_start]The application demonstrates the implementation of a non-linear median filter for grayscale images, used for noise reduction (e.g., "salt and pepper" noise)[cite: 31, 184]. [cite_start]The project puts a strong emphasis on performance optimization, comparing code written in C++ with highly optimized x64 Assembly code[cite: 149, 185].

## Project Architecture
[cite_start]The project was developed using a hybrid architecture in Visual Studio 2022[cite: 33, 185]:
* [cite_start]**User Interface (UI):** C# (Windows Forms) - manages image loading, processing parameters, and displaying results[cite: 186].
* [cite_start]**Compute Engine:** A Dynamic-Link Library (DLL) written in C++ and Assembly (MASM x64)[cite: 187].

## Key Technologies & Optimizations
* [cite_start]**SIMD Vectorization:** The assembly implementation utilizes SSE vector instructions (`movdqu`, `pminub`, `pmaxub`)[cite: 286, 498]. [cite_start]This allows the processing of 16 bytes (pixels) simultaneously in a single loop cycle[cite: 189, 499].
* **Multithreading:** The algorithm supports parallel data processing. [cite_start]The image is divided into stripes and processed across multiple threads (from 1 to 12), managed directly from C++ using the `<thread>` library[cite: 190, 500].
* [cite_start]**Sorting Networks:** Instead of classic sorting algorithms with conditional branching (like QuickSort/IntroSort in C++), the ASM version uses a Sorting Network based on MIN/MAX instructions[cite: 275, 280, 502]. [cite_start]This approach completely eliminates costly branch prediction errors in the CPU[cite: 284, 285, 502].

## Performance Results
[cite_start]Performance benchmarks revealed a massive advantage of low-level optimization[cite: 498]. Using SIMD instructions combined with multithreading yielded the following results for a 2040x2040px image with a 3x3 filter window:
* [cite_start]Execution time (1 C++ thread): **49,486 ms**[cite: 416, 431].
* [cite_start]Execution time (12 ASM threads): **17 ms**[cite: 435, 439].
* [cite_start]**Speedup:** The optimized ASM algorithm executes **2910.9x** faster[cite: 439]!

## How to run
1. Clone the repository.
2. [cite_start]Open the `.sln` solution file in Microsoft Visual Studio 2022[cite: 33, 185].
3. Ensure the build configuration is set to **x64** (required for the MASM library).
4. Build the solution and run the application.

> Full project documentation, including mathematical analysis, the final report with all benchmarks, and a presentation, can be found in the `docs` folder.
