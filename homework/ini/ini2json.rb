require 'json'

result  = {}

File.foreach ARGV.first, chomp: true do |line|
  next if line.empty? || line.start_with?(';')

  if line.start_with?('[') && line.end_with?(']')
    key         = line.slice(1..-2)
    result[key] = {}
  else
    key, value = line.split('=', 2).map(&:strip)

    last_value = result.values.last

    if last_value.instance_of?(Hash)
      last_value[key] = value
    else
      result[key] = value
    end
  end
end

puts result.to_json
