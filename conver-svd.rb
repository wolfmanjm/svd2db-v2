require 'rio'

rio('RP2350.svd').each do |l|
	m = /\<bitRange\>/.match(l)
	if m
		# <bitRange>[31:0]</bitRange>
		m = /\[(.*)\]/.match(l)
		r = m[1].split(':')
		hr = r[0].to_i
		lr = r[1].to_i
		# <bitOffset>0</bitOffset>
        # <bitWidth>1</bitWidth>
        puts "<bitOffset>#{lr}</bitOffset>"
        puts "<bitWidth>#{(hr-lr)+1}</bitWidth>"
	end
	puts l
end
