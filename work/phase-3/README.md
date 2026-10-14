# Phase 3
## 抽象化の導入(Rack)
### STEP 1: Rackアプリを書いてみる

```ruby
app = proc.new do |env|
  [200, {'content-type' => 'text/plain'}, ['hello, world']]
end
```

#### env とは何か？

HTTP リクエストを含むハッシュオブジェクト

#### 配列 [200, headers, body] の意味は何か？

HTTP レスポンス

### STEP 2: Rackの構造を理解する

```ruby
call(env) → [status, headers, body]
```

#### なぜこの形になっているのか？

Rack が提供するインターフェイスのシンプルな共通の型があることで利用する際に準拠しやすくしている

#### なぜオブジェクトではなく配列なのか？

わかりません。

## Step 3: Rackを使ってサーバを起動する

### Phase 1との違いは何か？

- リクエストを受け付けてレスポンスを返す処理は実装していない
- 自分ではステータスコード、コンテントタイプ、ボディしか指定していない

### サーバとアプリの責務はどう分かれているか？

- サーバはHTTPリクエストを解析して、適切な形でHTTPレスポンスを返す
- アプリはenvを受け取り、stetus, headers, bodyの3要素の配列を返す

## Step 4: envの中身を調べる

### envにどんな情報が入っているか列挙する

REMOTE_HOST, REQUEST_METHOD, SERVER_NAME などの HTTP リクエストに関する情報が入っている

```
{"GATEWAY_INTERFACE" => "CGI/1.1",
 "PATH_INFO" => "/",
 "QUERY_STRING" => "",
 "REMOTE_ADDR" => "127.0.0.1",
 "REMOTE_HOST" => "127.0.0.1",
 "REQUEST_METHOD" => "GET",
 "REQUEST_URI" => "http://localhost:3000/",
 "SCRIPT_NAME" => "",
 "SERVER_NAME" => "localhost",
 "SERVER_PORT" => "3000",
 "SERVER_PROTOCOL" => "HTTP/1.1",
 "SERVER_SOFTWARE" => "WEBrick/1.9.2 (Ruby/4.0.6/2026-07-14)",
 "HTTP_HOST" => "localhost:3000",
 "HTTP_USER_AGENT" => "curl/8.22.0",
 "HTTP_ACCEPT" => "*/*",
  ...
}
```

### HTTPリクエストとの対応関係を説明する

HTTP リクエストのリクエストヘッダーで `Host: localhost:3000` とある場合、env側では `SERVER_PORT => 3000` , `SERVER_NAME => localhost` のように対応付けられている
サーバーが解析したHTTP リクエストが Rack が定める形に変換 env が構成されている

## Step 5: 自作HTTPサーバをRack対応させる

```ruby

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

Socket.tcp_server_loop '127.0.0.1', 3000 do |con|
  status, headers, body = app.call(build_env(con))

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

  con.close
end

```

## Step 6: サーバとアプリの分離を実感する

```ruby
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

  res_body = body.join

  con.write <<~RESP.chomp.gsub("\n", "\r\n")
    HTTP/1.1 #{status} 
    #{res_headers}
    Content-Length: #{res_body.gsub("\n", "\r\n").bytesize}
    Connection: close

    #{res_body}
  RESP

  con.close
end
```

## 成果物
### Rack とは何か

サーバとアプリを分離して、それぞれが何をするかを決めたルール

### なぜ必要か

HTTP サーバが独自にHTTPリクエストと対応するレスポンスの返却を行っていると、振る舞いを変えたい場合にサーバのロジックに手を入れなければならず汎用性に欠ける。
Rack によって振る舞いをアプリとして分離し、アプリが受け取る引数と戻り値をルールとして定めることで、サーバはそのルールに則ってロジックを組めば良くなる。

### 何が変わったか

Phase 1 で実装したサーバには HTTP リクエストの処理と HTTP レスポンスの処理がサーバのコード内に含まれていたが、Rack 対応させることでその処理をサーバのコードから消すことができた

### 比較
#### Phase 1との違い

上述の「何が変わったか」と同様

#### WEBrick との関係

WEBrick は振る舞いをサーブレットとして分離していて、Rack は Rack アプリとして分離している点が設計として異なっているが、サーバから振る舞いを分離して抽象化している点は共通している。
