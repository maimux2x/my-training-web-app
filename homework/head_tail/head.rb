path  = ARGV[0]
limit = ARGV[1].to_i

File.foreach path do |file|
  break if limit.zero?

  puts file.lines

  limit -= 1
end
