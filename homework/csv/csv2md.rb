require 'csv'

csv    = CSV.read(ARGV.first)
widths = csv.transpose.map { it.map(&:length).max }

csv.each.with_index do |row, i|
  line = row.zip(widths).map {|cell, width|
    cell.ljust(width)
  }.join(' | ')

  puts "| #{line} |"

  if i.zero?
    delimiter = widths.map {|i|
      '-' * (i + 2)
    }.join('|')

    puts "|#{delimiter}|"
  end
end
