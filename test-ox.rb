#!/usr/bin/ruby -w
require 'ox'

#xml = 'RP2350-orig.svd'
xml = 'STM32H750x.svd'

@derives = {}
doc = Ox.load_file(xml)
doc.device.peripherals.locate('peripheral[@derivedFrom]').each do |n|
	puts
	a = n.locate('name/?[0]')[0]
	b = n.attributes[:derivedFrom]
	@derives[a] = b
end

p @derives

# h[:device].each do |d|
# 	unless d[:peripherals].nil?
# 		d[:peripherals][:peripheral].each { |p| p p }
# 		puts
# 	end
# end

#h = Ox.load_file(xml, mode: :hash_no_attrs)
exit
