require "sequel"
require 'logger'

# connect to an in-memory database
DB = Sequel.sqlite(loggers: [Logger.new($stdout)])
#DB = Sequel.sqlite

#DB = Sequel.sqlite('RP2350-new.db', loggers: [Logger.new($stderr)])
#DB = Sequel.sqlite('RP2350-new.db')

def create_db
	DB.create_table(:mpus) do
	  # Primary key must be set explicitly
	  primary_key :id
	  String :name, null: false, unique: true
	  String :description
	end

	DB.create_table(:peripherals) do
	  primary_key :id
	  foreign_key :mpu_id
	  foreign_key :derived_from_id
	  String :name, null: false, unique: true
	  String :base_address
	  String :description
	end

	DB.create_table(:registers) do
	  primary_key :id
	  foreign_key :peripheral_id
	  String :name, null: false
	  String :address_offset
	  String :reset_value
	  String :description
	end

	DB.create_table(:fields) do
	  primary_key :id
	  foreign_key :register_id
	  String :name, null: false
	  Integer :num_bits
	  Integer :bit_offset
	  String :description
	end
end

create_db

class Mpu < Sequel::Model
  one_to_many :peripherals
end

class Peripheral < Sequel::Model
  one_to_many :registers
  many_to_one :derived_from, key: :derived_from_id, class: self
end

class Register < Sequel::Model
  one_to_many :fields
end

class Field < Sequel::Model
end

def populate_db
	mpu = Mpu.create(name: 'TestMPU', description: 'A test SVD database')
	px1 = mpu.add_peripheral(name: 'PERIPH1', base_address: '0x12345678', description: 'periph1')
	rx1 = px1.add_register(name: 'REG1', address_offset: '0x004', reset_value: '0x000', description: 'reg1')
	px1.add_register(name: 'REG2', address_offset: '0x008', reset_value: '0x000', description: 'reg2')

	px = mpu.add_peripheral(name: 'PERIPH2', base_address: '0x87654321', description: 'periph2')
	rx = px.add_register(name: 'P2REG1', address_offset: '0x004', reset_value: '0x000', description: 'periph2 reg1')

	# <peripheral derivedFrom="PERIPH1">
	px = mpu.add_peripheral(name: 'PERIPH3', base_address: '0x11111111', description: 'periph3 uses periph1 registers')
	px.derived_from = Peripheral[name: 'PERIPH1']
	px.save

	# <peripheral derivedFrom="PERIPH1">
	px = mpu.add_peripheral(name: 'PERIPH4', base_address: '0x22222222', description: 'periph4 uses periph1 registers')
	px.derived_from = Peripheral[name: 'PERIPH1']
	px.save
end

populate_db

def dump_db(mpu)
	p mpu
	mpu.peripherals.each do |pe|
		p pe
		unless pe.derived_from.nil?
			pe= pe.derived_from
			puts "duplicating registers of peripheral #{pe.name}"
		end
		pe.registers.each do |r|
			p r
			r.fields.each { |f| p f }
		end
		puts
	end
end

puts "\nDump DB:\n\n"
mpu = Mpu[1]
dump_db(mpu)

#pp mpu.peripherals

# p DB.schema(:mpus)



