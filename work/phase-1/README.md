# Phase 1
## 実装内容

### server.rb
Socket クラスを使ってサーバーソケットを実装しました。

### server_2.rb
TCPServer クラスを使ってサーバーソケットを実装しました。
server.rbで `tcp_server_loop` を使って実現していたループ処理を自分で実装しました。

## 動作確認

```
$ ruby server.rb
```

または

```
$ ruby server_2.rb
```

別ターミナルで

```
$ telnet 127.0.0.1 3000
```

を実行して

```
GET / HTTP/1.1
Host: localhost

```

のようにリクエストを送ります。
'/', '/about', '/hello?name=alice' に対して200 OK、無効なパスに対しては404 Not Found、GET以外のリクエストには405 Method Not Allowed がレスポンスとして返されます。

```
$ curl -v http://localhost:3000/
```

を実行することでもレスポンスを確認することができます。

ブラウザで直接 `localhost:3000/` にアクセスすると、Hello World と表示されます。

## HTTP リクエストとはなにか

```
GET / HTTP/1.1
Host: localhost

```

HTTPメソッドから始まり、ヘッダーを持ち、空行、HTTPメソッドによってはボディを持つテキスト

## HTTP レスポンスとはなにか

```
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 20
Connection: close
```

## クライアントとサーバーの通信の流れ

サーバーがクライアントからのリクエストを待機する。
クライアントからのリクエストがあると接続を受け付ける。
接続を受け付けた後、クライアントからEOFが送られるまで読み込みを続ける。
EOFに到達したらレスポンスを書き込む。
接続を終了する。

## なぜブラウザにHTMLが表示されるのか

クライアントからのリクエストに対してサーバーが適切なHTMLファイルを読み込んでレスポンスとして返すため。
