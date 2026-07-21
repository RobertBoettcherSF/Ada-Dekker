# Ada-Dekker

Ada implementation of Dekker's algorithm, including three variants as discussed in the Wikipedia article:

1. **Naive_Turn_Taking**: Strict alternation (fails if one process halts)
2. **Starvation_Susceptible**: Actions performed without checking turn (can lead to starvation)
3. **Full_Dekker**: The correct and complete Dekker's algorithm

## Project Structure

```
Ada-Dekker/
├── dekker.adb          # Main implementation
├── dekker.ads          # Specification
├── dekker.gpr          # GNAT project file
├── README.md           # This file
├── obj/                # Object files directory
├── bin/                # Binary output directory
└── tests/
    ├── dekker_tests.adb # Comprehensive test suite
    └── tests.gpr        # Test project file
```

## Building and Running

### Prerequisites
- GNAT (GNU Ada compiler)
- GPRBuild

### Build the main program

```bash
cd Ada-Dekker
gnatmake -P dekker.gpr
```

The executable will be created in the `bin/` directory (or current directory).

Run the demonstration:
```bash
./dekker
```

### Build and run the tests

```bash
cd Ada-Dekker/tests
gnatmake -P tests.gpr
./dekker_tests
```

Or from the root directory:
```bash
cd Ada-Dekker
gnatmake -P tests/tests.gpr
```

## Test Suite

The test suite (`tests/dekker_tests.adb`) contains **15 comprehensive tests** that verify:

### Assumptions Tested

1. **Initial State**: All flags, turn variable, and counters are initialized correctly
2. **Mutual Exclusion (Full Dekker)**: Only one process in critical section at a time
3. **Progress (Full Dekker)**: Both processes eventually enter critical section
4. **Naive Turn Taking - Uneven Iterations**: Handles different iteration counts
5. **Starvation Susceptible - Fairness**: Tests the unfair variant behavior
6. **No Starvation (Full Dekker)**: Both processes get fair access
7. **Counter Accuracy**: Shared counter increments correctly across all variants
8. **Turn Alternation**: Turn variable alternates correctly in naive variant
9. **Flag Reset**: Wants_To_Enter flags are reset after critical section
10. **Multiple Iterations**: Algorithm works across many loop iterations
11. **No Deadlock**: System doesn't deadlock with both processes active
12. **Concurrent Execution**: Both processes actually run concurrently
13. **Starvation Variant - Unfairness**: Demonstrates potential unfairness
14. **Critical Section Protection**: Shared counter is protected from race conditions
15. **All Variants Complete**: All algorithm variants complete without crashing

### Test Design Principles

The tests follow these principles:

1. **Make assumptions about code behavior** - Each test starts with clear assumptions about what the code should (or should not) do
2. **Test different assumptions** - Tests cover correct behavior, edge cases, and known issues
3. **Be proven false** - Tests are designed to fail when assumptions are wrong, providing clear feedback

### Test Output

Each test outputs:
- `[PASS]` for successful assertions
- `[FAIL]` for failed assertions
- `[INFO]` for additional information

A summary at the end shows:
- Total tests run
- Number passed
- Number failed

## Algorithm Variants

### 1. Naive_Turn_Taking

Strict alternation between processes. Simple but has a critical flaw: if one process halts or crashes, the other process cannot proceed because it's waiting for the turn to switch.

### 2. Starvation_Susceptible

This variant attempts to be more flexible but is missing the crucial `if Turn /= ID` check. This can lead to one process being starved (never getting access to the critical section) if the other process is always ready to enter.

### 3. Full_Dekker

The complete and correct Dekker's algorithm. It ensures:
- **Mutual Exclusion**: Only one process in critical section at a time
- **Progress**: If no process is in the remainder section, a waiting process can enter
- **Bounded Waiting**: No process waits forever to enter the critical section

## Implementation Details

### Key Components

- **Process_Id**: Enumeration type for P0 and P1
- **Wants_To_Enter**: Boolean array with atomic components to indicate process intent
- **Turn**: Atomic variable to resolve ties
- **Shared_Counter**: The protected resource (critical section payload)

### Memory Barriers

The implementation uses:
- `pragma Atomic_Components` for the boolean array to prevent loop invariant code motion
- `pragma Atomic` for the Turn variable
- These match the Wikipedia article's notes about memory barriers

## Directory Notes

The `obj/` and `bin/` directories are included in the repository to avoid the need to create them manually when cloning. They contain `.gitkeep` files to ensure they're tracked by git.

## License

This project is open source. Feel free to use, modify, and distribute.

## References

- [Dekker's algorithm - Wikipedia](https://en.wikipedia.org/wiki/Dekker%27s_algorithm)
- [Ada Programming Language](https://www.adaic.org/)
