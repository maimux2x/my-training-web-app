formula = ARGV[0]
stack   = []

formula.split(' ').each do |v|
  case v
  when '+', '-', '*', '/'
    acc = stack.pop

    break if stack.empty?

    stack.push stack.pop.send(v, acc)
  else
    stack.push v.to_i
  end
end

if stack.length == 1
  puts stack
else
  puts '計算できませんでした。'
end
