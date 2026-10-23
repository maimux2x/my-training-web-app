group = nil

pp ARGF.each_line(chomp: true).each_with_object(Hash.new {|h, k| h[k] = []}) {|line, data|
  next if line.empty?

  if line.start_with?('# ')
    group = line.delete_prefix('# ')
  else
    data[group] << line
  end
}
