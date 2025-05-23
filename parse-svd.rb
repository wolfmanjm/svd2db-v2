#!/usr/bin/ruby -w
require 'bundler/setup'
require 'ox'

unless ARGV[0].nil?
	$xml = ARGV[0]
else
	puts " Required input .svd file"
	exit 1
end

# extract all the peripherals that derive from another
@derives = {}
doc = Ox.load_file($xml)
doc.device.peripherals.locate('peripheral[@derivedFrom]').each do |n|
	a = n.locate('name/?[0]')[0]
	b = n.attributes[:derivedFrom]
	@derives[a] = b
end

h = Ox.load_file($xml, mode: :hash_no_attrs)

$stderr.puts "CPU: #{h[:device][:name]}"
$mcuname = h[:device][:name]

def convert_bitrange(br)
	m = /\[(.*)\]/.match(br)
	r = m[1].split(':')
	hr = r[0].to_i
	lr = r[1].to_i
    [lr, (hr-lr)+1]
end

# build the peripheral array
pa = []

pers = h[:device][:peripherals][:peripheral]
begin
	pers.each do |p|
		$stderr.puts "Peripheral: #{p[:name]} : #{p[:baseAddress]}"
		# build hash
		th = {peripheral: {name: p[:name], base_address: p[:baseAddress], description: p[:description]}, registers: []}
		if not p[:registers].nil?
			regs = p[:registers][:register]
			if regs.kind_of?(Array)
				regs.each do |r|
					# puts "  Register: #{r[:name]} address offset: #{r[:addressOffset]} reset: #{r[:resetValue]} desc: #{r[:description]}"
					rh = {register: {name: r[:name], address_offset: r[:addressOffset], reset_value: r[:resetValue], description: r[:description]}}

					fa = []
					fields = r[:fields][:field]
					if fields.kind_of?(Array)
						fields.each do |f|
							if f[:bitRange].nil?
								bo = f[:bitOffset]
								bw = f[:bitWidth]
							else
								bo, bw = convert_bitrange(f[:bitRange])
							end
							# puts "    #{f[:name]} - #{bw} << #{bo}"
							fa << {name: f[:name], num_bits: bw, bit_offset: bo, description: f[:description]}
						end
					else
						if fields[:bitRange].nil?
							bo = fields[:bitOffset]
							bw = fields[:bitWidth]
						else
							bo, bw = convert_bitrange(fields[:bitRange])
						end
						# puts "    #{fields[:name]} - #{bw} << #{bo}"
						fa << {name: fields[:name], num_bits: bw, bit_offset: bo, description: fields[:description]}
					end
					rh[:fields] = fa
					th[:registers] << rh
				end
			else
				# puts "  Register: #{regs[:name]} : #{regs[:addressOffset]}"
				th[:registers] << {register: {name: regs[:name], address_offset: regs[:addressOffset],
								   reset_value: regs[:resetValue], description: regs[:description]} }
			end
		else
			derived_from = @derives[p[:name]]
			if derived_from.nil?
				$stderr.puts "  #{th} has no registers"
			else
				th[:derived_from] = derived_from
			end
		end
		pa << th
	end
rescue => error
	$stderr.puts "ERROR"
	p error
	exit
end


require "sequel"
require 'logger'
# Memory database for testing
#DB = Sequel.sqlite(loggers: [Logger.new($stdout)])
#DB = Sequel.sqlite
$output_file = 'new_svd.db'
DB = Sequel.sqlite($output_file)

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


def populate_db(arr)
	$mpu = Mpu.create(name: $mcuname)

	arr.each do |p|
		$stderr.puts "Creating Peripheral: #{p[:peripheral]}"
		px = $mpu.add_peripheral(p[:peripheral])
		if p[:derived_from].nil?
			p[:registers].each do |r|
				#puts "  Creating Register: #{r[:register]}"
				rx = px.add_register(r[:register])
				if not r[:fields].nil?
					r[:fields].each do |f|
						#puts "    Creating Fields: #{f}"
						rx.add_field(f)
					end
				else
					$stderr.puts "no fields in #{r[:register]}"
				end
			end
		else
			# we derive the registers from the specified peripheral
			px.derived_from = Peripheral[name: p[:derived_from]]
			if px.derived_from.nil?
				$stderr.puts "ERROR: could not derived from #{p[:derived_from]}"
			else
				px.save
			end

		end
	end
end

# pp pa
populate_db(pa)
puts "output databse file is #{$output_file}"
# def dump_db()
# 	$mpu.peripherals.each do |pe|
# 		p pe
# 		unless pe.derived_from.nil?
# 			pe= pe.derived_from
# 		end

# 		pe.registers.each do |r|
# 			p r
# 			r.fields.each { |f| p f }
# 		end
# 	end
# end

# dump_db()
