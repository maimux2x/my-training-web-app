def tree
  p Dir.children(ARGV[0]).map {|dir|
    path = "#{ARGV}/#{dir}"
    if File.directory?(path)
      Dir.children(path)
    else
      path
    end
  }
end

tree

