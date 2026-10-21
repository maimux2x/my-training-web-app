require 'csv'

def draw_line(row, widths)
  aligned = row.zip(widths).map {|cell, width|
    cell.ljust(width)
  }

  puts "|#{aligned.join('|')}|"
end

head, *body = rows = CSV.parse(ARGF).map {|row|
  row.map { " #{it} " }
}

widths = rows.transpose.map { it.map(&:size).max }

draw_line head, widths
draw_line widths.map { '-' * it }, widths

body.each do |row|
  draw_line row, widths
end
