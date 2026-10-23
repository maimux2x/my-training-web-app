require 'json'

data = $stdin.each_line(chomp: true).map {|line|
  case line
  when /\Acommit (\h+)\z/
    ['revision', Regexp.last_match(1)]
  when /\A(?<key>[\w ]+):\s*(?<val>.*?)\s*\z/
    Regexp.last_match => {key:, val:}

    [key.downcase.tr(' ', '_'), val]
  when ''
    [
      'message',
      $stdin.each_line.map { it.delete_prefix('    ') }.join.chomp
    ]
  else
    raise line
  end
}.to_h

puts JSON.generate(data)
