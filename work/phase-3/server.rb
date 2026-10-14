require 'socket'

def build_env(con)
  line                       = con.gets("\r\n")
  method, fullpath, protocol = line.split
  path, query                = fullpath.split('?', 2)

  env = {
    'PATH_INFO'       => path,
    'REQUEST_METHOD'  => method,
    'QUERY_STRING'    => query || '',
    'SERVER_NAME'     => 'localhost',
    'SERVER_PROTOCOL' => protocol,
    'SERVER_PORT'     => '3000',
    'rack.url_scheme' => 'http',
    'rack.errors'     => $stderr
  }

  while line = con.gets("\r\n")
    break if line == "\r\n"

    key, value = line.split(':', 2)
    key        = key.gsub('-', '_').upcase
    value      = value.strip

    if %w[CONTENT_TYPE CONTENT_LENGTH].include?(key)
      env[key] = value
    else
      env["HTTP_#{key}"] = value
    end
  end

  env
end

app = Proc.new do |env|
  if env['REQUEST_METHOD'] == 'GET'
    case env['PATH_INFO']
    when '/hello'
      [200, { 'content-type' => 'text/html' }, ['<h1>Hello, World</h1>']]
    else
      [404, { 'content-type' => 'text/html' }, ['<h1>Not Found</h1>']]
    end
  else
    [405, { 'content-type' => 'text/html' }, ['<h1>Method Not Allowed</h1>']]
  end
end

Socket.tcp_server_loop '127.0.0.1', 3000 do |con|
  status, headers, body = app.call(build_env(con))

  res_headers = headers.map {|(k, v)|
    "#{k}: #{v}"
  }.join("\n")

  res_body = body.join("\n")

  con.write <<~RESP.chomp.gsub("\n", "\r\n")
    HTTP/1.1 #{status} 
    #{res_headers}
    Content-Length: #{res_body.gsub("\n", "\r\n").bytesize}
    Connection: close

    #{res_body}
  RESP

  con.close
end
