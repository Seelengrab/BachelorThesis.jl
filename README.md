## Performance Optimization in Julia

Run `julia make.jl pdf` to build the PDF and `julia make.jl html` to build the HTML version.

Use `julia make.jl tex` to build just the LaTeX, if you want to inspect that.

Building tex or pdf requires a working `latexmk` install, plus some additional packages for fonts/`naustrian` language support.
On my (archlinux) machine, that means installing `texlive-langgerman` (for german accents) as well as `texlive-luatex` (for bibliography citing).

Delete the `data` directory to regenerate benchmarking data of inline benchmarks.
Delete `src/bench_output` to regenerate benchmarking data of low level optimization.
This requires a working `g++` installation with OpenMP available for building the shared object of the C++ comparison code.

Be aware that exact results will only be available on similar computer hardware, that is, intel skylake based processors.
