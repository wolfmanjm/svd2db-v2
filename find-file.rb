#!/usr/bin/env ruby

def find_file_upwards(filename, start_dir = Dir.pwd)
  current_dir = File.expand_path(start_dir)

  loop do
    target_path = File.join(current_dir, filename)
    return target_path if File.exist?(target_path)

    parent_dir = File.expand_path("..", current_dir)
    return nil if current_dir == parent_dir  # Reached root directory

    current_dir = parent_dir
  end
end

if ARGV.length != 1
  puts "Usage: ruby find_upwards.rb <filename>"
  exit 1
end

filename = ARGV[0]
result = find_file_upwards(filename)

if result
  puts "Found: #{result}"
else
  puts "File '#{filename}' not found in current or any parent directory."
end
