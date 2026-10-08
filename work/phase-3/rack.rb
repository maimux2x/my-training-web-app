app = proc.new do |env|
  [200, {'content-type' => 'text/plain'}, ['hello, world']]
end
