# 素のRackアプリの限界を体験する

## 成果物

### ソースコード

```ruby
require 'socket'
require 'openssl'
require 'rack'
require 'stringio'

def build_env(con)
  if line = con.gets("\r\n")
    method, fullpath, protocol = line.split
    path, query                = fullpath.split('?', 2)

    env = {
      'PATH_INFO'       => path,
      'REQUEST_METHOD'  => method,
      'QUERY_STRING'    => query || '',
      'SERVER_NAME'     => 'localhost',
      'SERVER_PROTOCOL' => protocol,
      'SERVER_PORT'     => '3001',
      'rack.url_scheme' => 'https',
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

    if length = env['CONTENT_LENGTH']&.to_i
      env['rack.input'] = StringIO.new(con.read(length))
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

users = {}
mutex = Thread::Mutex.new

app = Proc.new do |env|
  if env['REQUEST_METHOD'] == 'GET'
    case env['PATH_INFO']
    when '/'
      [200, {'content-type' => 'text/html'}, ['<h1>Hello</h1>']]
    when '/users'
      [200, {'content-type' => 'text/html'}, [<<~HTML]]
        <ul>
          #{users.values.map { "<li>#{it['name']}</li>" }.join}
        </ul>
      HTML
    when %r(\A/users/(\d+)\z)
      id   = Regexp.last_match[1]
      user = users[id.to_i]

      if user
        [200, {'content-type' => 'text/html'}, [<<~HTML]]
          <dl>
            <dt>ID</dt>
            <dd>#{id}</dd>
            <dt>Name</dt>
            <dd>#{user['name']}</dd>
            <dt>Age</dt>
            <dd>#{user['age']}</dd>
          </dl>
        HTML
      else
        [404, {'content-type' => 'text/html'}, ['<h1>Not Found</h1>']]
      end
    else
      [404, {'content-type' => 'text/html'}, ['<h1>Not Found</h1>']]
    end
  elsif env['REQUEST_METHOD'] == 'POST'
    req = Rack::Request.new(env)

    mutex.synchronize do
      id        = (users.keys.max || 0) + 1
      users[id] = req.params
    end

    [200, {'content-type' => 'text/html'}, ['<p>登録しました。</p>']]
  else
    [405, {'content-type' => 'text/html'}, ['<h1>Method Not Allowed</h1>']]
  end
end

Rack::Lint.new(app)

tcp_server       = TCPServer.open('127.0.0.1', 3001)
ssl_context      = OpenSSL::SSL::SSLContext.new
ssl_context.cert = OpenSSL::X509::Certificate.new(File.read('cert.pem'))
ssl_context.key  = OpenSSL::PKey::RSA.new(File.read('key.pem'))
ssl_server       = OpenSSL::SSL::SSLServer.new(tcp_server, ssl_context)

ssl_server.start_immediately = false

loop do
  con = ssl_server.accept
  create_thread con, app
end
```

### 問題点リスト

#### 書いていて辛かった点

- ヒアドキュメントでRubyとHTMLを組み合わせるのはERBを使うことと比較して、ループや分岐を入れたい場合にとても書きにくかった
- パスが増える度にappに手をいれなければいけない
- 404のレスポンスは共通化したいけれど、できなかった
- id の増加や歯抜けがあった際のことを自分で考えなければいけなかった

#### 将来的に問題になりそうな点

- users 以外のリソースも扱うようになった場合、ロジックが重複する部分が増える
- 分岐が増えてコードの見通しが悪くなる

### 考察

#### なぜフレームワークが必要なのか

- 処理が重複する部分は共通化して使い回せるようになる
- idの扱いを例に考えると、アプリで考慮しなければいけない決めごとをフレームワークのルールとして事前に定めておける
