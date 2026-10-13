path  = ARGV[0]
limit = ARGV[1].to_i

File.foreach path do |line|
  break if limit.zero?

  puts line

  limit -= 1
end
