def step(rule, remaining_gen, cells = [1], bg = 0)
  return if remaining_gen <= 0

  padding = [bg] * remaining_gen

  puts (padding + cells + padding).map { ' #'[it] }.join

  next_cells = [bg, bg, *cells, bg, bg].each_cons(3).map {|x, y, z|
    rule[x * 4 + y * 2 + z]
  }

  step rule, remaining_gen - 1, next_cells, rule[bg * 7]
end

rule    = ARGV.shift.to_i
max_gen = ARGV.shift.to_i

step rule, max_gen
