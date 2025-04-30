require "sequel"
require 'logger'

#DB = Sequel.sqlite(loggers: [Logger.new($stdout)])
#DB = Sequel.sqlite # connect to an in-memory database

#DB = Sequel.sqlite('RP2350-new.db', loggers: [Logger.new($stderr)])
DB = Sequel.sqlite('RP2350-new.db')

class Mpu < Sequel::Model
  one_to_many :peripherals
end

class Peripheral < Sequel::Model
  one_to_many :registers
end

class Register < Sequel::Model
  one_to_many :fields
end

class Field < Sequel::Model
end

def dump_db(mpu)
	mpu.peripherals.each do |pe|
		p pe
		pe.registers.each do |r|
			p r
			r.fields.each { |f| p f }
		end
	end
end

mpu = Mpu[1]
#dump_db(mpu)
#pp mpu.peripherals

# p DB.schema(:mpus)

# create equ's for UART0 SR register
pr = mpu.peripherals_dataset.where(name: 'UART0').first
puts ".equ #{pr.name}, #{pr.base_address}"

res = pr.registers_dataset.where(Sequel.ilike(:name, 'UARTCR'))
if res.count > 1
	puts "more than one match..."
	res.each { |r| puts r.name }
	exit
end

res = res.first
puts "  .equ #{res.name}, #{res.address_offset}"
res.fields_dataset.each do |f|
	puts "    .equ #{res.name}_#{f.name}, #{f.num_bits} << #{f.bit_offset}"
end




