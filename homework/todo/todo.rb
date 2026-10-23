group = nil

pp ARGF.readlines.each_with_object({}) {|line, data|
  line = line.chomp

  next if line.empty?

  if line.start_with?('#')
    group       = line.slice(2..)
    data[group] = []
  else
    data[group] << line
  end
}
