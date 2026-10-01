def parse_query(path)
  _, query = path.split('?', 2)

  return {} unless query

  query.split('&').map {|str|
    if str.end_with?('=')
      [str.delete_suffix('='), '']
    else
      str.split('=', 2).values_at(0..1)
    end
  }.to_h
end

p parse_query('/?foo=bar')
p parse_query('/?foo=bar&baz')
p parse_query('/?foo=bar&baz=')
