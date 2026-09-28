require 'socket'

def response(status, body)
  <<~RESP.chomp.gsub("\n", "\r\n")
    HTTP/1.1 #{status}
    Content-Type: text/html
    Content-Length: #{body.bytesize}
    Connection: close

    #{body}
  RESP
end

Socket.tcp_server_loop '127.0.0.1', 3000 do |con|
  line = con.gets
  method, path = line.split

  while line = con.gets
    break if line == "\r\n"
  end

  if method == 'GET'
    case path
    when '/'
      con.write response('200 OK', '<h1>Hello World</h1>')
    when '/about'
      con.write response('200 OK', '<h1>About Page</h1>')
    else
      con.write response('404 Not Found', '<h1>404 Not Found</h1>')
    end
  else
    con.write response('405 Method Not Allowed', '<h1>405 Method Not Allowed</h1>')
  end

  con.close
end
