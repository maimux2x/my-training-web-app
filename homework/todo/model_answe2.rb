p ARGF.each_line(chomp: true).inject([Hash.new {|h, k| h[k] = [] }, nil]) {|(data, group), line|
  next data, group if line.empty?

  if line.start_with?('# ')
    group = line.delete_prefix('# ')
  else
    data[group] << line
  end

  [data, group]
}.first
