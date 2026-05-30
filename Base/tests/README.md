# Apus Engine — Tests & Benchmarks

This directory contains functional tests and performance benchmarks for the Base library.
Tests are compiled with FPC and run on both 32-bit and 64-bit targets.

## Running Tests

```
test.bat [TestName]
```

Compiles and runs a test project in both 64-bit and 32-bit mode.
If no name is given, `TestCore` is used by default.

**Examples:**
```
test.bat              → runs TestCore
test.bat Strings      → runs TestStrings
```

**Available tests:**

| Name | What it covers |
|------|---------------|
| `Core` | Memory, bits, alignment, min/max/clamp |
| `Conv` | Type conversions (int, float, bool, hex) |
| `Strings` | UTF-8 string operations |
| `Containers` | Generic collections (lists, queues) |
| `HashMaps` | Hash map operations |
| `Files` | File I/O utilities |
| `EventMan` | Event system |
| `Threads` | Threading primitives |
| `Tweenings` | Tweening interpolation, delays, interruptions |
| `Types` | Base types, buffers, bit streams |
| `Geom2D` | 2D geometry |
| `Geom3D` | 3D geometry |
| `Spatial` | Spatial primitives |
| `Compress` | Compression helpers |

## Running Tests on Linux

```
./test.sh [TestName]
```

Linux equivalent of `test.bat`. Runs only the 64-bit build (no 32-bit on Linux).
Usage and test names are identical to `test.bat`.

**Examples:**
```
./test.sh             → runs TestCore
./test.sh Strings     → runs TestStrings
```

Result is written to `test_results_L64.txt`.

Run the deterministic Linux-compatible Base regression set with:

```
bash test_all.sh
```

This excludes tests with external-service or platform-specific requirements.
The summary is written to `test_results_all.txt`.

## Reading Test Results

Results are written to files in this directory:

- `test_results_64.txt` — Windows 64-bit build and run output
- `test_results_32.txt` — Windows 32-bit build and run output
- `test_results_L64.txt` — Linux 64-bit build and run output

Each test prints one line per check:

```
Testing <feature>... OK
Testing <feature>... FAIL
```

A non-zero exit code at the end of the file means at least one check failed.
If the file contains `COMPILE FAILED`, the build did not succeed — check the compiler
errors above that line.

## Build Test (compile all modules)

```
buildtest.bat       # Windows
bash buildtest.sh   # Linux
```

Compiles every Base module individually with FPC to verify they all build successfully.
Does not run any code — only checks that compilation succeeds.

Each module is reported as `[ ---- ]` (pass) or `[ FAIL ]` (fail), followed by a summary:

```
[ ---- ] Apus.Core
[ ---- ] Apus.Conv
[ ---- ] Apus.Tweenings
...
==========================================
SUMMARY: all modules passed
```

On failure, the compiler output for the failing module is included in the log.

Results are written to `buildtest_results.txt`.

The build test also runs automatically on GitHub Actions on every push to `engine5`
(see `.github/workflows/build_test.yml`).

## Running Benchmarks

```
bench.bat [BenchName]
```

Compiles with optimizations (`-O3`) and measures performance of selected operations.
If no name is given, `BenchStrings` is used by default.

**Available benchmarks:** `Core`, `Conv`, `Strings`, `HashMaps`, `Mem`, `Animation`

**Examples:**
```
bench.bat             → runs BenchStrings
bench.bat HashMaps    → runs BenchHashMaps
```

Results are written to `bench_<Name>_64.txt` and `bench_<Name>_32.txt`.
Each line reports an operation name and its timing (ns or μs per call).

## BenchRes — Historical Benchmark Archive

The `BenchRes/` subdirectory contains saved benchmark results from previous runs
on multiple compiler/platform combinations:

- `*_F32.txt` — FPC 32-bit
- `*_F64.txt` — FPC 64-bit
- `*_D64.txt` — Delphi 64-bit

`BenchRes/analysis_report.md` contains a comparative analysis of these results,
including known performance anomalies and their probable causes.
