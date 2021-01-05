#!/usr/bin/env ruby
# coding: utf-8
#
# @(#) sudoku
#
# This script attempts to solve a Sudoku puzzle by iteratively
# assigning values meeting row, column and grid constraints.
#
class Sudoku

  # Exception class
  class ConstraintError <RuntimeError; end

  # Class methods
  class <<self
    def dup(grid)
      grid.reduce([]) {|acc, row| acc.append(row.dup)}
    end

    def display(grid)
      sz = grid.size
      s_sz = Integer(Math.sqrt(sz))

      puts '┌─────────┬─────────┬─────────┐'
      sz.times do |i|
        puts '├─────────┼─────────┼─────────┤' if i > 0 && i % s_sz == 0
        s_sz.times do |j|
          printf '│'
          s_sz.times do |k; v|
            v = grid[i][j * s_sz + k]
            v.nil? ? printf(" _ ") : printf("%2d ",  v)
          end
        end
        puts '│'
      end
      puts '└─────────┴─────────┴─────────┘'
    end
  end

  attr_reader :g, :c, :s, :sz, :s_sz

  def initialize(sparse_matrix)

    raise "Expecting nested Array" \
      unless (sparse_matrix.class == Array &&
              sparse_matrix[0].class == Array)

    # Grid, g[i][j], that will contain the solution.
    @g = self.class.dup(sparse_matrix)

    # Grid size (i.e., rows/columns in grid)
    @sz = g.size

    # Sub-grid size (i.e., rows/columns in a sub-grid).
    @s_sz = Integer(Math.sqrt(sz))

    # Sanity check:
    begin
      raise "Grid not square" unless sz > 0 && g.size == g[0].size
      raise "Invalid grid size" unless sz = s_sz ** 2
      consistent?
    rescue ConstraintError => err
        puts "#{err.class}: #{err.message}"
        exit
    end

    # Column view of grid
    @c = g.transpose

    # Array of sub-grids - i.e., row-indexed sub-grids of size s_sz
    @s = subgrids
  end

  def solve()

    # Columns
    @c = g.transpose

    # Sub-grids
    @s = subgrids

    # First, iteratively assign unique values.
    loop do
      prev = self.class.dup(g)
      begin
        apply_unique(assignments)
        break if g == prev
      rescue ConstraintError => err
        puts "#{err.class}: #{err.message}" if VERBOSE
        return nil
      end
    end

    # Next, find a minimal set, a[*m], of possible assignments.
    m = select_minimal(a = assignments)
    if ! m.empty?

      # Recursively apply values in minimal set.
      apply_recursively(a, *m)
    end
    completed? ? g : nil
  end

  private

  # subgrids: Returns array of square s_sz-sized sub-grids of
  #           grid g indexed by row order.
  def subgrids()
    sz.times.reduce([]) do |ac, i; ri, ci|
      ri = (i / s_sz) * s_sz
      ci = (i * s_sz) % sz
      ac.append((ri ... ri + s_sz).reduce([]) do |acc, j|
                  acc.append(g[j][ci ... ci + s_sz])
                end)
    end
  end

  # duplicates?: Returns `true' if any non-nil value in ary occurs more
  #     than once, otherwise `false'.
  def duplicates?(ary)
    ary.empty? ? false : ary.tally.values.max > 1
  end

  # consistent?: Ensures that initial values in grid g are not
  #              duplicated in the same row, column or sub-grid.
  def consistent?()
    g.each do |row|
      raise ConstraintError, 'duplicate row values' \
        if duplicates?(row.reject(&:nil?))
    end

    # Columns, col[ci][ri], of grid g[ri][ci].
    g.transpose.each do |col|
      raise ConstraintError, 'duplicate column values' \
        if duplicates?(col.reject(&:nil?))
    end

    # Square sub-grids, s[i], of size s_sz, indexed by row order.
    subgrids.each do |subgrid|
      raise ConstraintError, 'duplicate sub-grid values' \
        if duplicates?(subgrid.flatten.reject(&:nil?))
    end
  end

  # assignments: For each point in grid g, collects all values (i.e.,
  #     possible assignments) satisfying current row, column and
  #     sub-grid constraints by taking the intersection of the numbers
  #     missing from each of those.
  def assignments()

    # Collect missing numbers, rc[i], in row g[i].
    rc = sz.times.reduce([]) do |acc, i|
      acc.append([*1 .. sz] - g[i].reject(&:nil?))
    end

    # Collect missing numbers, cc[i], in column c[i].
    cc = sz.times.reduce([]) do |acc, i|
      acc.append([*1 .. sz] - c[i].reject(&:nil?))
    end

    # Collect missing numbers, sc[i], in sub-grid s[i].
    sc = s.reduce([]) do |acc, subgrid|
      acc.append([*1 .. sz] - subgrid.flatten.reject(&:nil?))
    end

    # For each point without a value, collect the intersection, a, of
    # numbers missing from the corresponding row, column and grid.
    # These are used to determine what value to assign to that point.
    # For points with values, the associated assignments array is empty.
    sz.times.reduce([]) do |ac, ri|
      ac.append(sz.times.reduce([]) do |acc, ci; si, a|
                   next acc.append([]) unless g[ri][ci].nil?
                   si = (ri / s_sz) * s_sz + (ci / s_sz)
                   a = rc[ri] & cc[ci] & sc[si]
                   raise ConstraintError, "Over-constrained: assignments[#{ri}][#{ci}].empty?" \
                     if a.empty?
                   acc.append(a)
                end)
    end
  end

  # apply_unique: Updates grid g with values in constraints array a
  #     that are unique, i.e., such that a[i][j].size == 1
  def apply_unique(a)
    sz.times do |ri|
      sz.times do |ci; si, v|
        next unless a[ri][ci].size == 1
        v = a[ri][ci].pop
        si = (ri / s_sz) * s_sz + (ci / s_sz)
        raise ConstraintError, "Under-constrained: #{v} => g[#{ri}][#{ci}]: Not allowed" \
          if (g[ri] + c[ci] + s[si].flatten).include?(v)
        g[ri][ci] = c[ci][ri] = s[si][ri % s_sz][ci % s_sz] = v
      end
    end
  end

  # select_minimal: Finds the coordinates of the (first) point, m, in g
  #     with the fewest values that can be assigned to it.
  def select_minimal(a)
    min = sz + 1
    sz.times.reduce([]) do |ac, ri; m|
      m = sz.times.reduce([]) do |acc, ci|
        next acc unless (0 < a[ri][ci].size && a[ri][ci].size < min)
        min = a[ri][ci].size
        [ri, ci]
      end
      m.empty? ? ac : m
    end
  end

  # apply_recursively: For each value in a[ri][ci] (a candidate for
  #     assignment to g[ri][ci]), creates a new Sudoku instance,
  #     variant, from the current state of the grid g and applies
  #     value to variant.g[ri][ci] until a solution is reached.
  def apply_recursively(a, ri, ci)
    a[ri][ci].shuffle.each do |n; variant|
      variant = self.class.new(g)
      variant.g[ri][ci] = n
      if variant.solve
        @g = self.class.dup(variant.g)
        break
      end
    end
  end

  # completed?: Returns true if grid g does not contain any nil values,
  #     otherwise false.
  def completed?
    g.flatten.select(&:nil?).empty?
  end
end

if __FILE__ == $0

  # g = [
  #   [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  #   [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  #   [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  #   [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  #   [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  #   [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  #   [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  #   [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  #   [nil, nil, nil, nil, nil, nil, nil, nil, nil]
  # ]

  # g = [
  #   [ 2,   nil, nil, nil, 5,   nil, nil, nil, 3 ],
  #   [ nil, nil, 5,   nil, nil, 1,   nil, nil, nil ],
  #   [ nil, 1,   nil, 4,   nil, nil, 5,   nil, 8 ],
  #   [ 3,   nil, nil, nil, 6,   nil, nil, 5,   nil ],
  #   [ nil, nil, nil, 7,   nil, nil, 4,   nil, nil ],
  #   [ nil, nil, 2,   nil, 3,   nil, nil, 1,   7 ],
  #   [ nil, 5,   nil, nil, nil, 7,   2,   nil, nil ],
  #   [ 6,   nil, 4,   nil, nil, nil, nil, 8,   nil ],
  #   [ nil, 9,   nil, 5,   nil, 8,   nil, nil, nil ]
  # ]

  g = [
    [8,   nil, nil, nil, nil, nil, nil, nil, nil],
    [nil, nil, 3,   6,   nil, nil, nil, nil, nil],
    [nil, 7,   nil, nil, 9,   nil, 2,   nil, nil],
    [nil, 5,   nil, nil, nil, 7,   nil, nil, nil],
    [nil, nil, nil, nil, 4,   5,   7,   nil, nil],
    [nil, nil, nil, 1,   nil, nil, nil, 3,   nil],
    [nil, nil, 1,   nil, nil, nil, nil, 6,   8],
    [nil, nil, 8,   5,   nil, nil, nil, 1,   nil],
    [nil, 9,   nil, nil, nil, nil, 4,   nil, nil]
  ]

  if ARGV[0] =~ /-{0,2}h/
    puts "Usage: #{$0.sub(/.*\//, '')} [-v]"
    exit
  end

  VERBOSE = ARGV[0] == '-v'

  s = Sudoku.new(g)

  exit if s.nil?

  puts "Given:"
  Sudoku.display(s.g)

  if s.solve
    puts "Solution:"
    Sudoku.display(s.g)
  else
    puts "No solution found 😧"
  end
end
