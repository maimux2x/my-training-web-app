require 'json'

result  = {}
section = nil

File.foreach ARGV.first, chomp: true do |line|
  next if line.empty? || line.start_with?(';')

  if line.start_with?('[') && line.end_with?(']')
    section = line.slice(1..-2)

    result[section] ||= {}
  else
    key, value = line.split('=', 2).each(&:strip)

    (section ? result[section] : result)[key] = value
  end
end

puts result.to_json
