require 'csv'

csv       = ARGV.first
max_group = CSV.read(csv).transpose.map { it.map(&:length).max }

hyphen = max_group.map {|i|
  '-' * (i + 2)
}.join('|')

CSV.read(csv).each.with_index do |line, i|
  line = line.map.with_index {|str, num|
    str.ljust max_group[num] + 1
  }.join('| ')

  puts "| #{line}|"
  puts "|#{hyphen}|" if i.zero?
end
