# HTTPS対応（TLSの導入）演習

## Step 1 HTTPの限界を理解する

### HTTPとは/HTTPSとは

HTTPはプロトコルのことを指し、HTTPの場合は通信は暗号化されていない。HTTPSの場合は通信が暗号化されている

## Step 2 OpenSSLで証明書を作る

key.pemとcert.pemについて

key.pem: 秘密鍵
cert.pem: 自己証明書

## Step 6 HTTPとの違いを整理する

|項目|HTTP|HTTPS|
|---|---|---|
|通信内容|平文|暗号化されている|
|既定ポートと演習用ポート|80と3000|443と3001|
|セキュリティ|通信が暗号化されていない|通信が暗号化されている|

## Step 7 なぜコードがほぼ同じか考える

暗号化レイヤーであるTLSが実装の違いを吸収しているため

## 成果物

### HTTPS 対応サーバ

```ruby
require 'socket'
require 'openssl'

def build_env(con)
  if line = con.gets("\r\n")
    method, fullpath, protocol = line.split
    path, query                = fullpath.split('?', 2)
    server_name = 'localhost'
    port = '3001'
    scheme = 'https'

    env = {
      'PATH_INFO'       => path,
      'REQUEST_METHOD'  => method,
      'QUERY_STRING'    => query || '',
      'SERVER_NAME'     => server_name,
      'SERVER_PROTOCOL' => protocol,
      'SERVER_PORT'     => port,
      'rack.url_scheme' => scheme,
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
end

def create_thread(con, app)
  Thread.new {
    begin
      con.sync_close = true
      con.accept

      env = build_env(con)

      next unless env

      status, headers, body = app.call(env)

      res_headers = headers.map {|(k, v)|
        "#{k}: #{v}"
      }.join("\n")

      res_body = body.join
      sleep 3
      con.write <<~RESP.chomp.gsub("\n", "\r\n")
        HTTP/1.1 #{status} 
        #{res_headers}
        Content-Length: #{res_body.gsub("\n", "\r\n").bytesize}
        Connection: close

        #{res_body}
      RESP
    rescue OpenSSL::SSL::SSLError, SystemCallError => e
      warn "TLS/接続エラー: #{e.message}"
    ensure
      con.close
    end
  }
end

app = Proc.new do |env|
  if env['REQUEST_METHOD'] == 'GET'
    case env['PATH_INFO']
    when '/'
      [200, { 'content-type' => 'text/html' }, ['<h1>New App</h1>']]
    when '/about'
      [200, { 'content-type' => 'text/html' }, ['<h1>About Page</h1>']]
    else
      [404, { 'content-type' => 'text/html' }, ['<h1>Not Found</h1>']]
    end
  else
    [405, { 'content-type' => 'text/html' }, ['<h1>Method Not Allowed</h1>']]
  end
end

tcp_server       = TCPServer.open('127.0.0.1', 3001)
ssl_context      = OpenSSL::SSL::SSLContext.new
ssl_context.cert = OpenSSL::X509::Certificate.new(File.read("cert.pem"))
ssl_context.key  = OpenSSL::PKey::RSA.new(File.read("key.pem"))
ssl_server       = OpenSSL::SSL::SSLServer.new(tcp_server, ssl_context)

ssl_server.start_immediately = false

loop do
  con = ssl_server.accept
  create_thread con, app
end
```

### HTTP と HTTPS の違い

Step 1に書いた通り

### TLS の役割

HTTP に暗号レイヤーとして追加され、通信を暗号化する役割を担う

### なぜ HTTPS が必要なのか

HTTP のままでは通信内容をだれでも確認することができてしまい、のっとりや情報の漏洩が起きてしまうため
