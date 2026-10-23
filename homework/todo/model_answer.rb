data  = Hash.new {|k, v| k[v] = [] }
group = nil

ARGF.each_line chomp: true do |line|
  next if line.empty?

  if line.start_with?('# ')
    group = line.delete_prefix('# ')
  else
    data[group] << line
  end
end

p data
