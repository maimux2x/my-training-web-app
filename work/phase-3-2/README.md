# Phase 3.2: サーバの並行性（スレッド対応HTTPサーバ）をTDDで安全に導入する
## Step 2 期待する振る舞いを先にテストで固定する（RED）

```ruby
require_relative 'test_helper'
require 'net/http'
require 'uri'

class Parallel < Minitest::Test
  def test_parallel_request
    start = Time.now

    threads = Array.new(2) { Thread.new { Net::HTTP.get(URI.parse('http://localhost:3000/')) } }

    threads.each { it.join }

    finish = Time.now

    assert finish - start <= 6
  end
end
```

## Step 3 最小のスレッド化を行う（GREEN）

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

def create_thread(con, app)
  Thread.new {
    status, headers, body = app.call(build_env(con))

    res_headers = headers.map {|(k, v)|
      "#{k}: #{v}"
    }.join("\n")

    sleep 3
    res_body = body.join
    con.write <<~RESP.chomp.gsub("\n", "\r\n")
      HTTP/1.1 #{status} 
      #{res_headers}
      Content-Length: #{res_body.gsub("\n", "\r\n").bytesize}
      Connection: close

      #{res_body}
    RESP

    con.close
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

socket  = TCPServer.open('127.0.0.1', 3000)
cons    = [socket]

loop do
  cons.each do |con|
    if con == socket
      cons.push con.accept
    else
      create_thread con, app
      cons.delete con
    end
  end
end
```

## Step 4 スレッド化で壊れるケースをテストで観察する

```ruby
require_relative 'test_helper'

class RequestCounter
  def initialize
    @count = 0
  end

  attr_reader :count

  def inc
    count = @count
    sleep 0.1
    @count = count + 1
  end
end

class ThreadSafeTest < Minitest::Test
  def test_pararell_thread
    req_counter = RequestCounter.new

    3.times.map {
      Thread.new { req_counter.inc }
    }.each(&:join)

    assert_equal 3, req_counter.count
  end
end
```

## Step 5 race condition の原因を理解する
### なぜ期待した値にならないのか

カウントの値を読み込んで、書き込みをする前にスレッドが切り替わってしまったから

### どこで競合が起きているのか

カウントに書き込みをする手前

### なぜシングルスレッドでは問題が見えにくかったのか

スレッドが切り替わらず、逐次実行されるため

## Step 6 最低限の対策をテストから導入する（GREEN）

```ruby
require_relative 'test_helper'

class RequestCounter
  def initialize
    @count = 0
    @mutex = Thread::Mutex.new
  end

  attr_reader :count

  def inc
    @mutex.synchronize do
      count = @count
      sleep 0.1
      @count = count + 1
    end
  end
end

class ThreadSafeTest < Minitest::Test
  def test_pararell_thread
    req_counter = RequestCounter.new

    3.times.map {
      Thread.new { req_counter.inc }
    }.each(&:join)

    assert_equal 3, req_counter.count
  end
end
```

## Step 7 HTTPサーバ本体に応用する

### server.rb で検証したこと

#### 38行目 build_env(con)

  - con：スレッドごとに異なるオブジェクト
  - env（Hash そのもの）：スレッドごとに異なるオブジェクト
  - env の各値（リクエスト由来 / リテラル / nil / rack.errors）：リクエスト由来、リテラルはスレッドごとに異なるオブジェクト。nilとrack.errorsは複数のスレッドが同じオブジェクトを参照している。nilは状態を変えられないためスレッドをまたいで同じ値になっている。
  - 根拠（コード・実験）：build_envの中でそれぞれのobject_idとThread.currentの結果を出力して比較した

  #### 46行目 con.write

  - con を参照しているスレッド：ワーカースレッドとメインスレッド
  - con の状態を変えるスレッド：ワーカースレッド
  - 根拠（コード・実験）：
	build_env では con.gets で1行ずつ con の内容を取得している
    con.writeでレスポンスを書き込んでいる
    create_thread の最後で con.close をしてコネクションを閉じている
    メインスレッドでもワーカースレッドと同じ con を参照しているが、cons の状態のみを変えていて、con の状態は変えていない

  #### 見つかった共有状態

  - 何が：rack.errorsの参照と書き込みを共有している
  - 今のコードで問題になるか：ほぼならない。エラーメッセージからスレッドの object_id を識別できるため。
  - app 側の使い方次第で問題になりうるか：なる
  - 起きうること：appでエラーの書き込み中にスレッドが切り替わると、エラーの書き込みに割り込みが生じる

  #### 共有状態ではないが見つかった問題
  
  現状のコードでは[socket]からconsのeachループがスタートし、consに追加される値は1つのみなため、問題は発生しない。しかし、consに1回のループで2つ以上のコネクションが追加されるような実装に修正がされると仮定した場合、cons の each 中の delete によって cons の状態を変えていて、if con == socket が true の際にリクエストがないとリクエストがくるまで con.accept がブロックし続けるため、処理が長時間待たされるコネクションが発生する可能性がある。

  #### この検証で言えないこと
  - 同時に送ったリクエストは最大3本、5回ずつ程度試している。書き込んだ文字列の長さは3文字程度。　  - $stderr への書き込みでは1行の途中では混ざらなかったが上記前提以外の結果は未検証
  - Ruby のバージョンや実装違いのパターンも未検証
  - 現時点で起きていないことは「起きない」ことの証明にはならない
  - 例外が発生した際に標準エラー出力への書き込みは1回まとめてなのか複数回なのか

### どこが危険か

- メインスレッドで `con` の状態を変える処理が追加されると共有状態になりうる
- Rack アプリ側で `rack.errors` の参照と書き込みを共有しているため、使い方次第でエラーの書き込みに割り込みが生じる

### どこは安全か

現時点では `Mutex` の導入をしていないため、安全と言い切れる箇所はない

### Rackアプリ側に共有状態があると何が起きるか？

「どこが危険か」で書いた通り

## Step 8 TDDの有効性と限界を振り返る

### なぜTDDは有効だったのか

スレッド化するためにできるようになってほしい結果を先に固定して、現状と修正後の結果を比較しながら開発を進めることができるため。

### どのような振る舞いを先に固定できたのか

必ずこの結果になるという振る舞い
今回の場合は、2つのリクエストの処理時間がn秒以内に収まっているか、カウンターの値が意図した値になっているかなど

### なぜそれでもバグを100%防げないのか

並行処理は実行順序が常に一定ではないことが一つ挙げられる

### 並行性では、設計がなぜ重要なのか

同じ結果を得られるような設計にすることで安全性を高められるからではと考えましたが、まだ理解が足りていないです

## Step 9 WEBrick / Rack / 実務構成と比較する

### WEBrickはどのように並行処理しているか

Thread::SizedQueueで接続の最大数を管理し、GenericServer#start_threadメソッドで並行処理をしている。

### Rackアプリはスレッドセーフである必要があるか

必要。自前実装の Rack アプリ側で標準エラー出力に書き込みを加え、sleep を挟む処理を複数回追加したところ、エラーの書き込みに割り込みが生じた。
Web サーバーがスレッドセーフに対応していても Rack アプリ側がそうでなければ、レースコンディションが発生してしまう。

### 実務でPumaなどがなぜ慎重に設計されているのか

分かりません。

## レポート

### なぜ並行処理が必要か

逐次処理では処理できる量に限界があり、性能が悪化するため

### なぜ単純なスレッド化が危険か

実行順序などが毎回同じではないため、結果が不安定になる

### なぜこのフェーズでTDDを導入したのか

期待する結果を先に固定して実装を進めるため

### TDDの有効性と限界

必ずその結果になるという振る舞いは固定できるが、そうではないケースでは振る舞いを固定することが難しい

### 自作サーバにおける危険箇所と対策

Rack アプリに共有状態があるとレースコンディションが発生する
現在の実装では共有状態はないため、対策をしていない
