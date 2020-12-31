#!/usr/bin/env ruby
# coding: utf-8
#
# @(#) sudoku
#
# This script attempts to solve a Sudoku puzzle by iteratively
# assigning values meeting row, column and grid constraints.
#
class Sudoku
  class ConstraintError <RuntimeError; end

  class <<self
    def dup(grid)
      newgrid = []
      grid.each {|row| newgrid.append(row.dup)}
      newgrid
    end

    def print(grid)
      grid.each do |row|
        row.each {|v| v.nil? ? printf(" _ ") : printf("%2d ",  v)}
        puts
      end
    end
  end

  attr_reader :g, :c, :s, :sz, :s_sz

  def initialize(sparse_matrix)

    raise "Expecting nested Array" unless (sparse_matrix.class == Array &&
                                           sparse_matrix[0].class == Array)

    # Grid, g[i][j], that will contain the solution.
    @g = self.class.dup(sparse_matrix)

    # Grid columns
    @c = g.transpose

    # Grid size (i.e., rows/columns in grid)
    @sz = g.size

    # Sub-grid size (i.e., rows/columns in a sub-grid).
    @s_sz = Integer(Math.sqrt(sz))

    # Row-indexed square sub-grids of size s_sz
    @s = subgrids

    # Sanity check:
    begin
      consistent?
      raise "Grid not square" unless sz > 0 && g.size == g[0].size
      raise "Invalid grid size" unless sz = s_sz ** 2
    rescue ConstraintError => err
        puts "#{err.class}: #{err.message}"
        exit
    end
  end

  # Return array of square s_sz-sized sub-grids, s[i], of grid
  # r[i][j], indexed by row order.
  def subgrids()
    sg = []
    sz.times do |i; ri, ci, subgrid|
      ri = (i / s_sz) * s_sz
      ci = (i * s_sz) % sz
      subgrid = []
      ri.upto(ri + s_sz - 1) {|j| subgrid.append(g[j][ci .. ci + s_sz - 1])}
      sg.append(subgrid)
    end
    sg
  end

  def duplicates?(ary)
    ary.empty? ? false : ary.tally.values.max > 1
  end

  # Ensure that initial values in grid are not duplicated in the same
  # row, column or sub-grid.
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

  # For each point, g[i][j], of the grid, collect all values (i.e.,
  # possible assignments) satisfying current row, column and sub-grid
  # constraints by taking the intersection of the numbers missing from
  # each of those.
  def assignments()

    # Collect missing numbers, m_in_r[i], in row, g[i].
    m_in_r = []
    sz.times {|i| m_in_r.append([*1 .. sz] - g[i].reject(&:nil?))}

    # Collect missing numbers, m_in_c[i], in column, c[i].
    m_in_c = []
    sz.times {|i| m_in_c.append([*1 .. sz] - c[i].reject(&:nil?))}

    # Collect missing numbers, m_in_s[i], in sub-grid, s[i].
    m_in_s = []
    s.each do |subgrid|
      m_in_s.append([*1 .. sz] - subgrid.flatten.reject(&:nil?))
    end

    # For each point, collect the intersection of numbers missing from
    # the corresponding row, column and grid. These are used to
    # determine what value to assign to point.
    a = Array.new(sz) {Array.new(sz) {Array.new}}
    sz.times do |ri|
      sz.times do |ci; si|

        # Skip points already assigned values.
        next if g[ri][ci]

        si = (ri / s_sz) * s_sz + (ci / s_sz)
        a[ri][ci] +=
          m_in_r[ri].intersection(m_in_c[ci]).intersection(m_in_s[si])
         if a[ri][ci].size == 0
           raise ConstraintError, "Over-constrained: a[#{ri}][#{ci}].size == 0"
        end
      end
    end
    a
  end

  def apply_unique(a)

    # Update grid, g[i][j], with constraints, a[i][j], that are
    # unique, i.e., such that a[i][j].size == 1
    sz.times do |ri|
      sz.times do |ci; si, v|
        if a[ri][ci].size == 1
          v = a[ri][ci].pop
          si = (ri / s_sz) * s_sz + (ci / s_sz)
          if (g[ri].include?(v) ||
              c[ci].include?(v) ||
              s[si].flatten.include?(v))
            raise ConstraintError,
                  "Under-constrained: #{v} => g[#{ri}][#{ci}]: Not allowed"
          else
            g[ri][ci] = v

            # Column and sub-grid don't reflect changes to grid,
            # g[ri][ci], so update them manually in order to detect
            # constraint errors.
            c[ci][ri] = s[si][ri % s_sz][ci % s_sz] = v
          end
        end
      end
    end
  end

  def select_minimal(a)

    # Among all points in grid, g[i, j], find the coordinates of the
    # (first) point, m, with the fewest values that can be assigned to
    # it.
    m = [0, 0]
    min = sz
    sz.times do |ri|
      sz.times do |ci|
        if 0 < a[ri][ci].size && a[ri][ci].size < min
          min = a[ri][ci].size
          m = [ri, ci]
        end
      end
    end
    m
  end

  def apply_multiple(a, ri, ci)

    # For each value, create a new Sudoku instance, variant, with the
    # current state of the grid, g, and value applied. If assignment
    # doesn't yield a solution, iteratively try the next value.

    # Shuffle values, since order is significant.
    a[ri][ci].shuffle.each do |n; variant|
      variant = self.class.new(g)
      variant.g[ri][ci] = n
      if variant.solve
        @g = self.class.dup(variant.g)
        break
      end
    end
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

    # Next, find a minimal set, a[*m], of possible values.
    m = select_minimal(a = assignments)
    if ! m.empty?

      # Iterate over values in the set.
      apply_multiple(a, *m)
    end
    completed? ? g : nil
  end

  def completed?
    g.flatten.select(&:nil?).empty?
  end

  def show_assignments()
    assignments.each do |row|
      row.each {|v| printf("%s ", v.inspect)}
      puts
    end
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
  Sudoku.print(s.g)

  if VERBOSE
    puts "Initial assignments:"
    s.show_assignments
  end

  if s.solve
    puts "Solution:"
    Sudoku.print(s.g)
  else
    puts "No solution found 😧"
  end
end
