File.foreach('RP2350-orig.svd') do |line|
  if line.include?('<bitRange>')
    # Extract range from <bitRange>[31:0]</bitRange>
    range_match = line.match(/\[(\d+):(\d+)\]/)
    if range_match
      hr = range_match[1].to_i
      lr = range_match[2].to_i
      puts "<bitOffset>#{lr}</bitOffset>"
      puts "<bitWidth>#{(hr - lr) + 1}</bitWidth>"
    end
  end
  puts line
end
