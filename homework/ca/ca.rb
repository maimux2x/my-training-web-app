rule, gen = ARGV.map(&:to_i)

patterns   = %w[111 110 101 100 011 010 001 000]
rule       = rule.to_s(2).rjust(8, '0').chars
rule_table = patterns.zip(rule).to_h

start = '1'

result = (gen - 1).times.map {
  start = start.center(gen * 2 + 1, '0').each_char.each_cons(3).map { rule_table[it.join] }.join
}

result.unshift('1'.center(gen * 2)).each do |line|
  line.gsub!('0', ' ')
  line.gsub!('1', '#')
  puts line
end
