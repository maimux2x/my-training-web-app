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

socket = TCPServer.open('127.0.0.1', 3000)
cons   = [socket]

loop do
  ready = IO.select(cons)

  ready[0].each do |con|
    if con == socket
      cons.push(con.accept)
    else
      line             = con.gets
      method, fullpath = line.split
      path, query      = fullpath.split('?', 2)

      while line = con.gets
        break if line == "\r\n"
      end

      if method == 'GET'
        case path
        when '/'
          con.write response('200 OK', '<h1>Hello World</h1>')
        when '/about'
          con.write response('200 OK', '<h1>About Page</h1>')
        when '/hello'
          params = query ? query.split('&').map { it.split('=') }.to_h : {}

          con.write response('200 OK', "Hello #{params['name']}")
        else
          con.write response('404 Not Found', '<h1>404 Not Found</h1>')
        end
      else
        con.write response('405 Method Not Allowed', '<h1>405 Method Not Allowed</h1>')
      end

      con.close
      cons.delete(con)
    end
  end
end
