# 生SQLのつらさをTDDで体験する

## STEP1

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

## STEP2

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

## STEP3

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

## STEP4

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

## STEP5

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

## STEP6

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
