class App
  def call(env)
    pp env
    status  = 200
    headers = {'content-type' => 'text/plain'}
    body    = ['sample']

    [status, headers, body]
  end
end
