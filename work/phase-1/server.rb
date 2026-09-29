require 'socket'

def response(status, html, params)
  body = if params.length > 0
           html + "\n<pre>" + params.map {|k, v|
             "#{k}=#{v}"
           }.join(', ') + '</pre>'
         else
           html
         end

  <<~RESP.chomp.gsub("\n", "\r\n")
    HTTP/1.1 #{status}
    Content-Type: text/html
    Content-Length: #{body.gsub("\n", "\r\n").bytesize}
    Connection: close

    #{body}
  RESP
end

Socket.tcp_server_loop '127.0.0.1', 3000 do |con|
  line             = con.gets
  method, fullpath = line.split
  path, query      = fullpath.split('?', 2)
  params           = query ? query.split('&').map { it.split('=') }.to_h : {}

  while line = con.gets
    break if line == "\r\n"
  end

  if method == 'GET'
    case path
    when '/'
      con.write response('200 OK', '<h1>Hello World</h1>', params)
    when '/about'
      con.write response('200 OK', '<h1>About Page</h1>', params)
    else
      con.write response('404 Not Found', '<h1>404 Not Found</h1>', params)
    end
  else
    con.write response('405 Method Not Allowed', '<h1>405 Method Not Allowed</h1>', params)
  end

  con.close
end
