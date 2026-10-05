def tree(path, indent = 0)
  puts "#{'  ' * indent}- #{File.basename(path)}"

  return unless File.directory?(path)

  Dir.children(path).each do |child|
    tree File.join(path, child), indent + 1
  end
end

tree ARGV.first
