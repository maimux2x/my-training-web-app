path   = ARGV[0]
limit  = ARGV[1].to_i
result = []

File.foreach path do |line|
  break if limit.zero?

  result.shift if result.length >= limit

  result << line.lines
end

puts result
