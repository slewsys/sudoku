# Sudoku constraint-based solver in Ruby
Yet another implementation of a sudoku solver for arbitrary-sized
square grids (providing the number of rows/columns is the square of an
integer). The implementation is not based on any prior work, though
the method is familiar - i.e., it iterates over values satisfying row,
column and sub-grid constraints at the most highly constrained points
and recursively tries each. Consequently, if a solution exists, it
will be found. Likewise, if a solution does not exist, that will be
determined as well.

Though only one solution is presented at a time, since values are
tried in a random order, if multiple solutions exist, they will all be
generated after enough runs (without saying how many is "enough").

No attempt is made to introduce concurrency (yet).

# Installation
The code is not packaged yet. It's a single file - download it and run
it. There's no I/O interface yet.  To add new puzzles, open the
program file in your editor.
