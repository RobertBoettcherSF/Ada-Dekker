# Ada-Dekker

Implementation of Dekker's algorithm and variants in Ada.

## Quick Start

### Prerequisites
- GNAT (GNU Ada compiler) - Install via:
  - Ubuntu/Debian: `sudo apt install gnat`
  - macOS: `brew install gnat`
  - Windows: Download from [AdaCore](https://www.adacore.com/download)

### Build and Run

**Option 1: Using make (recommended)**
```bash
# Build everything
make

# Run the demonstration
make run

# Run the tests
make test

# Clean build files
make clean
```

**Option 2: Manual commands**
```bash
# Build the main demonstration
gnatmake -P dekker.gpr
./obj/dekker

# Build and run tests
cd tests
gnatmake -P tests.gpr
./obj/dekker_tests
```

## Project Structure

- `dekker.adb` - Main implementation with three algorithm variants:
  - `Naive_Turn_Taking` - Strict alternation (fails if one process halts)
  - `Starvation_Susceptible` - Missing turn check (can starve one process)
  - `Full_Dekker` - Correct and complete Dekker's algorithm

- `tests/dekker_tests.adb` - Comprehensive test suite

## Algorithm Variants

1. **Naive Turn Taking**: Simple strict alternation. Works when both processes do the same number of iterations, but deadlocks with uneven iterations.

2. **Starvation Susceptible**: Implements the entry protocol but without the turn check in the back-off, making it susceptible to starvation.

3. **Full Dekker**: The complete and correct algorithm that ensures mutual exclusion, progress, and bounded waiting.
