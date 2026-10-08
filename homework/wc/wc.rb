def wc(path)
  lines = 0
  words = 0
  bytesize = 0

  File.foreach path do |line|
    lines += 1
    words += line.split(' ').length
    bytesize += line.bytesize
  end

  puts "#{lines} #{words} #{bytesize} #{path}"
end

wc ARGV.first
