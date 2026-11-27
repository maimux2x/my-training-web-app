# 生SQLのつらさをTDDで体験する

## STEP1 まずは一覧表示をしたいという失敗テストを書く（RED）

```ruby
  def test_users_index_displays_all_users
    seed_users([
      { id: 1, name: 'Alice', email: 'alice@example.com' },
      { id: 2, name: 'Bob', email: 'bob@example.com' }
    ])

    router = Router.new
    router.get '/users', to: 'users#index'

    status, _, body = router.call(env_for('/users'))

    assert_equal 200, status
    assert_includes body.join, 'Alice'
    assert_includes body.join, 'Bob'
  end
```

```
# Running:

E

Finished in 0.101545s, 9.8479 runs/s, 0.0000 assertions/s.

  1) Error:
SqlTest#test_users_index_displays_all_users:
RuntimeError: nothing rendered
    app/controllers/controller_base.rb:73:in 'ControllerBase#dispatch'
    app/controllers/controller_base.rb:35:in 'block in ControllerBase.action'
    router.rb:52:in 'block in Router#call'
    router.rb:48:in 'Array#each'
    router.rb:48:in 'Router#call'
    test/sql_test.rb:31:in 'SqlTest#test_users_index_displays_all_users'

1 runs, 0 assertions, 0 failures, 1 errors, 0 skips
```

## STEP2 最小実装で一覧を表示する（GREEN）

```ruby
# UsersController
  def index
    rows = db.execute('SELECT id, name FROM users')

    render_text rows.map {|row|
      row.join(',')
    }.join("\n")
  end
```

```
# Running:

.

Finished in 0.073119s, 13.6763 runs/s, 68.3816 assertions/s.

1 runs, 5 assertions, 0 failures, 0 errors, 0 skips
```

## STEP3 詳細表示をしたいという失敗テストを書く（RED）

```ruby
# SqlTest

  def test_users_show_displays_single_user
    seed_users([
      { id: 1, name: 'Alice', email: 'alice@example.com' }
    ])

    router = Router.new
    router.get '/users/:id', to: 'users#show'

    status, _, body = router.call(env_for('/users/1'))

    assert_equal 200, status
    assert_includes body.join, 'Alice'
    assert_includes body.join, 'alice@example.com'
  end
```

```

# Running:

.E

Finished in 0.124233s, 16.0988 runs/s, 40.2470 assertions/s.

  1) Error:
SqlTest#test_users_show_displays_single_user:
RuntimeError: nothing rendered
    app/controllers/controller_base.rb:73:in 'ControllerBase#dispatch'
    app/controllers/controller_base.rb:35:in 'block in ControllerBase.action'
    router.rb:52:in 'block in Router#call'
    router.rb:48:in 'Array#each'
    router.rb:48:in 'Router#call'
    test/sql_test.rb:46:in 'SqlTest#test_users_show_displays_single_user'

2 runs, 5 assertions, 0 failures, 1 errors, 0 skips
```

## STEP4 最小実装で詳細表示を通す（GREEN）

```ruby
# UsersController

  def show
    row = db.get_first_row('SELECT id, name, email FROM users WHERE id = ?', params['id'])

    render_text row.join(',')
  end
```

```
# Running:

..

Finished in 0.127098s, 15.7359 runs/s, 78.6797 assertions/s.

2 runs, 10 assertions, 0 failures, 0 errors, 0 skips
```

## STEP5 「存在しないID」の振る舞いを先にテストで決める（RED）

```ruby
# SqlTest

  def test_users_show_returns_404_when_user_not_found
    seed_users([])

    router = Router.new
    router.get '/users/:id', to: 'users#show'

    status, _, _ = router.call(env_for('/users/999'))

    assert_equal 404, status
  end
```

```
# Running:

..F

Finished in 0.279407s, 10.7370 runs/s, 39.3691 assertions/s.

  1) Failure:
SqlTest#test_users_show_returns_404_when_user_not_found [test/sql_test.rb:61]:
Expected: 404
  Actual: 200

3 runs, 11 assertions, 1 failures, 0 errors, 0 skips
```

## STEP6 選んだ仕様を最小実装する（GREEN）

```ruby
# UsersController

  def show
    row = db.get_first_row('SELECT id, name, email FROM users WHERE id = ?', params['id'])

    if row
      render_text row.join(',')
    else
      render_text '', status: 404
    end
  end
```

## STEP7 SQLの結果形式がつらいことを体験するためのテストを書く（RED）

```ruby
# SqlTest

require_relative 'test_helper'
require_relative '../router'
require_relative '../app/controllers/5_1_users_controller'

class SqlTest < Minitest::Test
  def setup
    @db = SQLite3::Database.new('db/development.sqlite3')

    @db.execute <<~SQL
      CREATE TABLE users (
        id INTEGER,
        name TEXT,
        email TEXT
      );
    SQL

    write_view '5_1_users/index.erb', <<~ERB
      <table>
        <thead>
          <tr>
            <th>id</th>
            <th>名前</th>
          </tr>
        </thead>
        <tbody>
          <% @rows.each do |row| %>
            <tr>
              <td><%= row[:id] %></td>
              <td><%= row[:name] %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    ERB

    write_view '5_1_users/show.erb', <<~ERB
      <dl>
        <dt>id</dt>
        <dd><%= @row[:id] %></dd>

        <dt>名前</dt>
        <dd><%= @row[:name] %></dd>

        <dt>メール</dt>
        <dd><%= @row[:email] %></dd>
      </dl>
    ERB
  end

  def teardown
    @db.execute 'DROP TABLE users'
  end

  def test_users_index_displays_all_users
    seed_users([
      { id: 1, name: 'Alice', email: 'alice@example.com' },
      { id: 2, name: 'Bob', email: 'bob@example.com' }
    ])

    router = Router.new
    router.get '/users', to: 'users#index'

    status, _, body = router.call(env_for('/users'))

    assert_equal 200, status
    assert_includes body.join, 'Alice'
    assert_includes body.join, 'Bob'
  end

  def test_users_show_displays_single_user
    seed_users([
      { id: 1, name: 'Alice', email: 'alice@example.com' }
    ])

    router = Router.new
    router.get '/users/:id', to: 'users#show'

    status, _, body = router.call(env_for('/users/1'))

    assert_equal 200, status
    assert_includes body.join, 'Alice'
    assert_includes body.join, 'alice@example.com'
  end

  def test_users_show_returns_404_when_user_not_found
    seed_users([])

    router = Router.new
    router.get '/users/:id', to: 'users#show'

    status, _, _ = router.call(env_for('/users/999'))

    assert_equal 404, status
  end

  def test_user_row_shape_is_used_in_view
    seed_users([
      { id: 1, name: 'Alice', email: 'alice@example.com' },
      { id: 2, name: 'Bob', email: 'bob@example.com' }
    ])

    router = Router.new
    router.get '/users', to: 'users#index'

    status, _, body = router.call(env_for('/users'))

    assert_equal 200, status
    assert_includes body.join, 'Alice'
  end

  private

  def env_for(path, method: 'GET', params: {})
    path, query = path.split('?')

    body = params.map {|k, v|
      "#{CGI.escape(k)}=#{CGI.escape(v)}"
    }.join('&')

    {
      'PATH_INFO'      => path,
      'REQUEST_METHOD' => method,
      'QUERY_STRING'   => query,
      'rack.input'     => StringIO.new(body)
    }
  end

  def write_view(path, html)
    path = File.join('app/views', path)

    FileUtils.mkdir_p File.dirname(path)
    File.write path, html
  end

  def seed_users(users)
    users.each do |user|
      @db.execute <<~SQL, [user[:id], user[:name], user[:email]]
        INSERT INTO users (id, name, email)
        VALUES (?, ?, ?)
      SQL
    end
  end
end

# UsersController

require_relative 'controller_base'

class UsersController < ControllerBase
  def index
    rows = db.execute('SELECT id, name FROM users')

    @rows = rows.map {|row|
      %i[id name].zip(row).to_h
    }

    render_view '5_1_users/index'
  end

  def show
    row = db.get_first_row('SELECT id, name, email FROM users WHERE id = ?', params['id'])

    if row
      @row = %i[id name email].zip(row).to_h

      render_view '5_1_users/show'
    else
      render_text '', status: 404
    end
  end
end
```

```
# Running:

....

Finished in 0.230105s, 17.3833 runs/s, 60.8417 assertions/s.

4 runs, 14 assertions, 0 failures, 0 errors, 0 skips
```

## STEP8 SQLの重複が見えるように、2つ目の取得処理を追加する（RED）

```ruby
# SqlTest

  def test_users_search_by_name
    seed_users([
      { id: 1, name: 'Alice', email: 'alice@example.com' },
      { id: 2, name: 'Bob', email: 'bob@example.com' }
    ])

    router = Router.new
    router.get '/users/search', to: 'users#search'

    status, _, body = router.call(env_for('/users/search?name=Bob'))

    assert_equal 200, status
    assert_includes body.join, 'Bob'
    refute_includes body.join, 'Alice'
  end

# UsersController

def search
end
```

```
# Running:

....E

Finished in 0.309833s, 16.1377 runs/s, 45.1856 assertions/s.

  1) Error:
SqlTest#test_users_search_by_name:
RuntimeError: nothing rendered
    app/controllers/controller_base.rb:73:in 'ControllerBase#dispatch'
    app/controllers/controller_base.rb:35:in 'block in ControllerBase.action'
    router.rb:52:in 'block in Router#call'
    router.rb:48:in 'Array#each'
    router.rb:48:in 'Router#call'
    test/sql_test.rb:120:in 'SqlTest#test_users_search_by_name'

5 runs, 14 assertions, 0 failures, 1 errors, 0 skips
```

## STEP9 最小実装で検索を通す（GREEN）

```ruby
# UsersController
  def search
    rows = db.execute('SELECT id, name FROM users WHERE name = ?', params['name'])

    @rows = rows.map {|row|
      %i[id name].zip(row).to_h
    }

    render_view '5_1_users/index'
  end
```

```
# Running:

.....

Finished in 0.302665s, 16.5199 runs/s, 62.7758 assertions/s.

5 runs, 19 assertions, 0 failures, 0 errors, 0 skips
```

## STEP10 DB接続の扱いがつらいことを観察する

- コントローラにSQLを直接書いている
- ビューで扱いやすくするために、DBで取得した結果を都度ハッシュに変換している

## STEP11 まずは“雑でも通る”リファクタリングをする（REFACTOR）

```ruby
# UsersController

require_relative 'controller_base'

class UsersController < ControllerBase
  def index
    rows = db.execute('SELECT id, name FROM users')

    @rows = rows.map {|row|
      array_to_hash(%i[id name], row)
    }

    render_view '5_1_users/index'
  end

  def show
    row = db.get_first_row('SELECT id, name, email FROM users WHERE id = ?', params['id'])

    if row
      @row = array_to_hash(%i[id name email], row)

      render_view '5_1_users/show'
    else
      render_text '', status: 404
    end
  end

  def search
    rows = db.execute('SELECT id, name FROM users WHERE name = ?', params['name'])

    @rows = rows.map {|row|
      array_to_hash(%i[id name], row)
    }

    render_view '5_1_users/index'
  end
end

# ControllerBase

class ControllerBase
  # ...

  private

  # ...

  def array_to_hash(arr, row)
    arr.zip(row).to_h
  end
end
```

## STEP12 「なぜつらいのか」を言語化する

### なぜ Controller にSQLを書くとつらいのか

少し条件が異なるだけのSQLをアクションごとに繰り返し書かなければいけない。

### 一覧・詳細・検索のどこに重複が出たか

すべての箇所に配列からハッシュへ変換する処理の重複がでた。

### DBの戻り値はアプリケーションコードにとって自然だったか

自然ではない。
firstやarr[0]のようにして値を取得するため、何の値を得たいのかがコードから理解しにくい。

### 次のフェーズでどのような抽象化が欲しくなったか

属性に対応するアクセサーメソッド。
DBの戻り値をコントローラやビューで扱いやすくしたい。

## 提出物

### テストコード

```ruby
require_relative 'test_helper'
require_relative '../router'
require_relative '../app/controllers/5_1_users_controller'

class SqlTest < Minitest::Test
  def setup
    @db = SQLite3::Database.new('db/development.sqlite3')

    @db.execute <<~SQL
      CREATE TABLE users (
        id INTEGER,
        name TEXT,
        email TEXT
      );
    SQL

    write_view '5_1_users/index.erb', <<~ERB
      <table>
        <thead>
          <tr>
            <th>id</th>
            <th>名前</th>
          </tr>
        </thead>
        <tbody>
          <% @rows.each do |row| %>
            <tr>
              <td><%= row[:id] %></td>
              <td><%= row[:name] %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    ERB

    write_view '5_1_users/show.erb', <<~ERB
      <dl>
        <dt>id</dt>
        <dd><%= @row[:id] %></dd>

        <dt>名前</dt>
        <dd><%= @row[:name] %></dd>

        <dt>メール</dt>
        <dd><%= @row[:email] %></dd>
      </dl>
    ERB
  end

  def teardown
    @db.execute 'DROP TABLE users'
  end

  def test_users_index_displays_all_users
    seed_users([
      { id: 1, name: 'Alice', email: 'alice@example.com' },
      { id: 2, name: 'Bob', email: 'bob@example.com' }
    ])

    router = Router.new
    router.get '/users', to: 'users#index'

    status, _, body = router.call(env_for('/users'))

    assert_equal 200, status
    assert_includes body.join, 'Alice'
    assert_includes body.join, 'Bob'
  end

  def test_users_show_displays_single_user
    seed_users([
      { id: 1, name: 'Alice', email: 'alice@example.com' }
    ])

    router = Router.new
    router.get '/users/:id', to: 'users#show'

    status, _, body = router.call(env_for('/users/1'))

    assert_equal 200, status
    assert_includes body.join, 'Alice'
    assert_includes body.join, 'alice@example.com'
  end

  def test_users_show_returns_404_when_user_not_found
    seed_users([])

    router = Router.new
    router.get '/users/:id', to: 'users#show'

    status, _, _ = router.call(env_for('/users/999'))

    assert_equal 404, status
  end

  def test_user_row_shape_is_used_in_view
    seed_users([
      { id: 1, name: 'Alice', email: 'alice@example.com' },
      { id: 2, name: 'Bob', email: 'bob@example.com' }
    ])

    router = Router.new
    router.get '/users', to: 'users#index'

    status, _, body = router.call(env_for('/users'))

    assert_equal 200, status
    assert_includes body.join, 'Alice'
  end

  def test_users_search_by_name
    seed_users([
      { id: 1, name: 'Alice', email: 'alice@example.com' },
      { id: 2, name: 'Bob', email: 'bob@example.com' }
    ])

    router = Router.new
    router.get '/users/search', to: 'users#search'

    status, _, body = router.call(env_for('/users/search?name=Bob'))

    assert_equal 200, status
    assert_includes body.join, 'Bob'
    refute_includes body.join, 'Alice'
  end

  private

  def env_for(path, method: 'GET', params: {})
    path, query = path.split('?')

    body = params.map {|k, v|
      "#{CGI.escape(k)}=#{CGI.escape(v)}"
    }.join('&')

    {
      'PATH_INFO'      => path,
      'REQUEST_METHOD' => method,
      'QUERY_STRING'   => query,
      'rack.input'     => StringIO.new(body)
    }
  end

  def write_view(path, html)
    path = File.join('app/views', path)

    FileUtils.mkdir_p File.dirname(path)
    File.write path, html
  end

  def seed_users(users)
    users.each do |user|
      @db.execute <<~SQL, [user[:id], user[:name], user[:email]]
        INSERT INTO users (id, name, email)
        VALUES (?, ?, ?)
      SQL
    end
  end
end
```

### 実装コード

#### UsersController

```ruby
require_relative 'controller_base'

class UsersController < ControllerBase
  def index
    rows = db.execute('SELECT id, name FROM users')

    @rows = rows.map {|row|
      array_to_hash(%i[id name], row)
    }

    render_view '5_1_users/index'
  end

  def show
    row = db.get_first_row('SELECT id, name, email FROM users WHERE id = ?', params['id'])

    if row
      @row = array_to_hash(%i[id name email], row)

      render_view '5_1_users/show'
    else
      render_text '', status: 404
    end
  end

  def search
    rows = db.execute('SELECT id, name FROM users WHERE name = ?', params['name'])

    @rows = rows.map {|row|
      array_to_hash(%i[id name], row)
    }

    render_view '5_1_users/index'
  end
end
```

#### 必要なビュー

##### index.erb

```ruby
<table>
  <thead>
    <tr>
      <th>id</th>
      <th>名前</th>
    </tr>
  </thead>
  <tbody>
    <% @rows.each do |row| %>
      <tr>
        <td><%= row[:id] %></td>
        <td><%= row[:name] %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

##### show.erb

```ruby
<dl>
  <dt>id</dt>
  <dd><%= @row[:id] %></dd>

  <dt>名前</dt>
  <dd><%= @row[:name] %></dd>

  <dt>メール</dt>
  <dd><%= @row[:email] %></dd>
</dl>
```

#### ControllerBase

```ruby
require_relative '../../router'

require 'erb'
require 'sqlite3'

class ControllerBase
  Callback = Data.define(:method, :only, :except, :block) {
    def match?(action)
      if only
        only.include?(action)
      elsif except
        !except.include?(action)
      else
        true
      end
    end

    def call(controller)
      if method
        controller.__send__ method
      else
        controller.instance_exec(&block)
      end
    end
  }

  @callbacks = []

  def self.inherited(subclass)
    subclass.instance_variable_set :@callbacks, []
  end

  def self.action(method)
    ->(req) {
      new(req).dispatch(method)
    }
  end

  def self.before_action(method = nil, only: nil, except: nil, &block)
    @callbacks << Callback.new(method, only, except, block)
  end

  def self.callbacks
    if superclass.respond_to?(:callbacks)
      superclass.callbacks + @callbacks
    else
      @callbacks
    end
  end

  def self.clear_callbacks
    @callbacks&.clear
  end

  def initialize(req)
    @request = req
    @res     = nil
  end

  attr_reader :request

  def db = @db ||= SQLite3::Database.new('db/development.sqlite3')

  def dispatch(action)
    self.class.callbacks.select { it.match?(action) }.each do |callback|
      callback.call self

      break if @res
    end

    public_send action unless @res

    raise 'nothing rendered' unless @res

    @res
  end

  def render_text(text, status: 200)
    build_response status, {'content-type' => 'text/plain'}, [text]
  end

  def render_html(html, status: 200)
    build_response status, {'content-type' => 'text/html'}, [html]
  end

  def render_file(path)
    render_html read_view_file(path)
  end

  def render_view(path)
    context = ViewContext.new

    (instance_variables - %i[@request @res]).each do |name|
      context.instance_variable_set name, instance_variable_get(name)
    end

    render_html ERB.new(read_view_file("#{path}.erb"), trim_mode: '-').result(context._binding)
  end

  def redirect_to(path, status: 302)
    build_response status, {'location' => path}, []
  end

  private

  def params
    @request.params.merge(@request.path_params)
  end

  def build_response(status, header, body)
    raise 'double rendered' if @res

    @res = [status, header, body]
  end

  def read_view_file(path)
    File.read(File.join('app/views', path))
  end

  def array_to_hash(arr, row)
    arr.zip(row).to_h
  end
end

class ViewContext
  include ERB::Util

  def _binding
    binding
  end
end
require_relative '../../router'

require 'erb'
require 'sqlite3'

class ControllerBase
  Callback = Data.define(:method, :only, :except, :block) {
    def match?(action)
      if only
        only.include?(action)
      elsif except
        !except.include?(action)
      else
        true
      end
    end

    def call(controller)
      if method
        controller.__send__ method
      else
        controller.instance_exec(&block)
      end
    end
  }

  @callbacks = []

  def self.inherited(subclass)
    subclass.instance_variable_set :@callbacks, []
  end

  def self.action(method)
    ->(req) {
      new(req).dispatch(method)
    }
  end

  def self.before_action(method = nil, only: nil, except: nil, &block)
    @callbacks << Callback.new(method, only, except, block)
  end

  def self.callbacks
    if superclass.respond_to?(:callbacks)
      superclass.callbacks + @callbacks
    else
      @callbacks
    end
  end

  def self.clear_callbacks
    @callbacks&.clear
  end

  def initialize(req)
    @request = req
    @res     = nil
  end

  attr_reader :request

  def db = @db ||= SQLite3::Database.new('db/development.sqlite3')

  def dispatch(action)
    self.class.callbacks.select { it.match?(action) }.each do |callback|
      callback.call self

      break if @res
    end

    public_send action unless @res

    raise 'nothing rendered' unless @res

    @res
  end

  def render_text(text, status: 200)
    build_response status, {'content-type' => 'text/plain'}, [text]
  end

  def render_html(html, status: 200)
    build_response status, {'content-type' => 'text/html'}, [html]
  end

  def render_file(path)
    render_html read_view_file(path)
  end

  def render_view(path)
    context = ViewContext.new

    (instance_variables - %i[@request @res]).each do |name|
      context.instance_variable_set name, instance_variable_get(name)
    end

    render_html ERB.new(read_view_file("#{path}.erb"), trim_mode: '-').result(context._binding)
  end

  def redirect_to(path, status: 302)
    build_response status, {'location' => path}, []
  end

  private

  def params
    @request.params.merge(@request.path_params)
  end

  def build_response(status, header, body)
    raise 'double rendered' if @res

    @res = [status, header, body]
  end

  def read_view_file(path)
    File.read(File.join('app/views', path))
  end

  def array_to_hash(arr, row)
    arr.zip(row).to_h
  end
end

class ViewContext
  include ERB::Util

  def _binding
    binding
  end
end
```

### 振り返りメモ

#### なぜ生SQLがつらいのか

上述

#### どの責務が Controller に漏れ出していたか

DBからのデータ取得と成形の責務

#### 次にどんな抽象化が欲しくなったか

上述

#### なぜそれを「Model」と呼びたくなるのか

分かりません

