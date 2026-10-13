require 'socket'

def build_env(con)
  line         = con.gets
  method, path = line.split

  env = {
    PATH_INFO: path,
    REQUEST_METHOD: method
  }

  while line = con.gets
    break if line == "\r\n"

    header = line.split(': ', 2)
    key    = header.first
    value  = header.last.chomp

    unless %w[content-type content-length].include?(key)
      env["HTTP_#{key.gsub('-', '_')}".to_sym] = value
    else
      env[key.to_sym] = value
    end
  end

  env
end

app = Proc.new do |env|
  if env[:REQUEST_METHOD] == 'GET'
    case env[:PATH_INFO]
    when '/'
      [200, { 'content-type' => 'text/html' }, ['<h1>New App</h1>']]
    when '/about'
      [200, { 'content-type' => 'text/html' }, ['<h1>About Page</h1>']]
    else
      [400, { 'content-type' => 'text/html' }, ['<h1>Bad Request</h1>']]
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
