require 'json'

data = {}

readlines.each.with_index {|line, i|
  if line.start_with?(/\w/)
    if i.zero?
      _, value = line.split(' ')
      data['revision'] = value
    else
      key, value = line.split(':', 2)
      data[key.gsub(' ', '_').downcase] = value.strip
    end
  elsif line == "\n"
    data['message'] = ''
  else
    data['message'] += line.slice(4..)
  end
}

data['message'].chomp!
puts JSON.generate(data)
