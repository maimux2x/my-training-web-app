def step(rule, cells, bg, gen, max_gen)
  return if gen > max_gen
  padding = [bg] * (max_gen - gen)
  puts (padding + cells + padding).map { ' #'[it] }.join
  next_cells = [bg, bg, *cells, bg, bg].each_cons(3).map {|x, y, z|
    rule[x * 4 + y * 2 + z]
  }
  step rule, next_cells, rule[bg * 7], gen + 1, max_gen
end

rule    = ARGV.shift.to_i
max_gen = ARGV.shift.to_i
step rule, [1], 0, 1, max_gen
