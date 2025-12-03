#!/usr/bin/ruby
require 'bundler/setup'
require "sequel"
require 'logger'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: lookup-svd.rb [options]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end

  opts.on("-c", "--curdir DIR", "set the current directory") do |v|
    options[:directory] = v
  end

  opts.on("--dump", "dump the database") do |v|
    options[:dump] = v
  end

  opts.on("--desc", "Show any description") do |v|
    options[:description] = v
  end

  opts.on("-l", "--list-peripherals", "List all peripherals") do |v|
    options[:list_periphs] = v
  end

  opts.on("--regs", "List all registers of the given peripheral") do |v|
    options[:list_registers] = v
  end

  opts.on("--asm", "generate asm output for specified register") do |v|
    options[:asm] = v
  end

  opts.on("--asm-all", "generate asm output for all registers") do |v|
    options[:asm] = v
    options[:asm_all] = v
    options[:register] = '%'
  end

  opts.on("--forth-reg", "generate forth output using reg") do |v|
    options[:forthreg] = v
  end

  opts.on("--forth-const", "generate forth output using constant") do |v|
    options[:forthconst] = v
  end

  opts.on("-d", "--database FILENAME", "Use this database [otherwise opens a default]") do |v|
    options[:database] = v
  end

  opts.on("-p", "--peripheral PERIPHERAL", "search for this peripheral") do |v|
    options[:peripheral] = v
  end

  opts.on("-r", "--register REGISTER", "search for this register") do |v|
    options[:register] = v
  end

end.parse!

# p options
# p ARGV

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

if options[:database]
	dbfile = options[:database]
else
	# find a database
	if options[:directory].nil?
		cdir = Dir.pwd
	else
		cdir = options[:directory]
	end
	dbfile = find_file_upwards('default-svd.db', cdir)
	if dbfile.nil?
		puts "No database found starting at #{cdir}"
		exit 1
	end
end

if options[:verbose]
	puts "Using database file #{dbfile}"
	DB = Sequel.sqlite(dbfile, {readonly: true, loggers: [Logger.new($stderr)]})
else
	DB = Sequel.sqlite(dbfile, {readonly: true})
end

# Models
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

# actions
def dump_db(mpu)
	mpu.peripherals.each do |pe|
		p pe
		pe.registers.each do |r|
			p r
			r.fields.each { |f| p f }
		end
	end
end

# get the first MPU
mpu = Mpu[1]
if options[:dump]
	puts "MPU: #{mpu.name}"
	dump_db(mpu)
	exit
end

# list all the peripherals
if options[:list_periphs]
	puts "MPU: #{mpu.name}, Available Peripherals:"
	mpu.peripherals_dataset.order(:name).each do |pe|
		s = pe.name
		if options[:description] and not pe.description.nil?
			s += " - #{pe.description}"
		end
		puts s
	end
	exit
end

# list all the registers for a given peripheral
if options[:list_registers]
	if options[:peripheral].nil?
		puts "peripheral required"
		exit
	end
	puts "MPU: #{mpu.name}, Registers for #{options[:peripheral]}:"
	# pr = mpu.peripherals_dataset.where(name: options[:peripheral]).first
	pr = mpu.peripherals_dataset.first(Sequel.ilike(:name, options[:peripheral]))
	if pr.nil?
		puts "Unknown peripheral #{options[:peripheral]}"
		exit
	end

	res = pr.registers_dataset.order(:name)
	if res.empty?
 		if pr.derived_from.nil?
			puts "#{options[:peripheral]} did not have any registers"
 		else
 			res= pr.derived_from.registers_dataset.order(:name)
 			puts "Has the same registers as #{pr.derived_from.name}"
 		end
	end
	res.each do |r|
		s = r.name
		if options[:description] and not r.description.nil?
			s += " - #{r.description}"
		end
		puts s
	end

	exit
end

if options[:peripheral].nil?
	puts "peripheral required"
	exit
end

def asm_register_output(mpu, pr, reg)
	puts "  .equ _#{reg.name}, #{reg.address_offset}"
	reg.fields_dataset.order(:bit_offset).each do |f|
		bf = "#{reg.name}_#{f.name}"
        if f.num_bits == 1
			puts "    .equ b_#{bf}, #{f.num_bits}<<#{f.bit_offset}"
        else
            mask = ((2**f.num_bits) - 1) << f.bit_offset
			puts "    .equ m_#{bf}, 0x#{sprintf("%08X", mask)}"
			puts "    .equ o_#{bf}, #{f.bit_offset}"
        end
	end
end

# create equ's for given peripheral and register
if options[:asm]
	if options[:register].nil?
		puts "register required"
		exit 1
	end

	pr = mpu.peripherals_dataset.first(Sequel.ilike(:name, options[:peripheral]))
	if pr.nil?
		puts "Unknown peripheral #{peripheral}"
		exit 1
	end

	res = pr.registers_dataset.where(Sequel.ilike(:name, "%#{options[:register]}"))
	if res.count == 0
 		if pr.derived_from.nil?
			puts "No match for the register #{options[:register]}"
			exit 1
 		else
 			res= pr.derived_from.registers_dataset.where(Sequel.ilike(:name, "%#{options[:register]}"))
 			puts "@ Has the same registers as #{pr.derived_from.name}"
 		end
 		if res.nil? or res.count == 0
 			puts "@ no matching registers to #{options[:register]}"
 			exit 1
 		end
	end

	if options[:asm_all]
		puts ".equ #{pr.name}_BASE, #{pr.base_address}"
		res.each do |reg|
			asm_register_output(mpu, pr, reg)
		end

	else
		if res.count > 1
			puts "more than one match for the register..."
			res.each { |r| puts r.name }
			exit 1
		end

		puts ".equ #{pr.name}_BASE, #{pr.base_address}"
		reg = res.first
		asm_register_output(mpu, pr, reg)
	end

	exit 0
end

# create the constant version for forth
if options[:forthconst]
	pr = mpu.peripherals_dataset.first(Sequel.ilike(:name, options[:peripheral]))
	if pr.nil?
		puts "\\ Unknown peripheral #{options[:peripheral]}"
		exit
	end

	puts "#{pr.base_address.sub('0x', '$')} constant #{pr.name}_BASE"
	regs = pr.registers_dataset
	if regs.count == 0
		if pr.derived_from.nil?
			puts "\\ No registers found for #{options[:peripheral]} Base address: #{pr.base_address}."
 		else
 			puts "\\ Has the same registers as #{pr.derived_from.name}"
 		end
			exit
	end

	prefix = pr.name.downcase[0..2]

	regs.each do |r|
		a = r.address_offset.sub('0x', '$')
		puts "  #{pr.name}_BASE #{a} + constant #{prefix}_#{r.name}"
	end

	# create constants for the bit fields
	# m_ use with modify-reg ( value mask pos reg -- )
	# ie 5 m_CR2_TSER SPI1 _spCR2 modify-reg
	# b_ use either bic! or bis!
	# ie b_CR1_SSI SPI2 _sCR1 bis!
	regs.each do |r|
		puts "\n\\ Bitfields for #{prefix}_#{r.name}"
		r.fields_dataset.order(:bit_offset).each do |f|
			bf = "#{prefix}_#{r.name}_#{f.name}"
	        if f.num_bits == 1
				puts "  1 #{f.bit_offset} lshift constant b_#{bf}"
	        else
	            mask = ((2**f.num_bits) - 1)
				puts "  $#{sprintf("%08X", mask)} #{f.bit_offset} 2constant m_#{bf}"
	        end
		end
	end

	exit
end

# create the register structure for forth
if options[:forthreg]
	pr = mpu.peripherals_dataset.first(Sequel.ilike(:name, options[:peripheral]))
	if pr.nil?
		puts "\\ Unknown peripheral #{options[:peripheral]}"
		exit
	end

	puts "#{pr.base_address.sub('0x', '$')} constant #{pr.name}"
	regs = pr.registers_dataset
	if regs.count == 0
		if pr.derived_from.nil?
			puts "\\ No registers found for #{options[:peripheral]} Base address: #{pr.base_address}."
 		else
 			puts "\\ Has the same registers as #{pr.derived_from.name}"
 		end
			exit
	end

	# create registers
	# use as USART1 _usCR1 leaves address of CR1 register for USART1 on the stack
	puts "  registers"
	prefix = pr.name.downcase[0..1]
	addr = 0

	regs.each do |r|
		a = r.address_offset.to_i(16)
		if a != addr
			puts "    drop $#{a.to_s(16)}"
			addr = a
		end
		addr += 4
		puts "    reg _#{prefix}#{r.name}"

	end

	puts "  end-registers"

	# create constants for the bit fields
	# m_ use with modify-reg ( value mask pos reg -- )
	# ie 5 m_CR2_TSER SPI1 _spCR2 modify-reg
	# b_ use eith bic! or bis!
	# ie b_CR1_SSI SPI2 _sCR1 bis!
	regs.each do |r|
		puts "\n\\ Bitfields for #{r.name}"
		r.fields_dataset.order(:name).each do |f|
			bf = "#{r.name}_#{f.name}"
	        if f.num_bits == 1
				puts "  #{f.bit_offset} bit constant b_#{bf}"
	        else
	            mask = ((2**f.num_bits) - 1) << f.bit_offset
				puts "  $#{sprintf("%08X", mask)} #{f.bit_offset} 2constant m_#{bf}"
	        end
		end
	end

	exit
end


# just list all the fields
pr = mpu.peripherals_dataset.first(Sequel.ilike(:name, options[:peripheral]))
if pr.nil?
	puts "Unknown peripheral #{options[:peripheral]}"
	exit
end

puts "#{pr.name} base address: #{pr.base_address}"

if options[:register].nil?
	reg = '%'
else
	reg = options[:register]
end

res = pr.registers_dataset.where(Sequel.ilike(:name, "%#{reg}"))
if res.count == 0
	if pr.derived_from.nil?
		puts "No match for the register #{options[:register]}"
		exit
	end
	res = pr.derived_from.registers_dataset.where(Sequel.ilike(:name, "%#{reg}"))
	puts "Has the same registers as #{pr.derived_from.name}"
end

res.each do |r|
	desc = ""
	if options[:description] and not r.description.nil?
		desc = " - #{r.description}"
	end

	puts "\nRegister #{r.name} offset: #{r.address_offset}, reset: #{r.reset_value} #{desc}"

	r.fields_dataset.order(:bit_offset).each do |f|
		if options[:description] and not f.description.nil?
			desc = " - #{f.description}"
		else
			desc = ''
		end

		bf = "#{r.name}_#{f.name}"
		puts " #{bf}: number bits #{f.num_bits}, bit offset: #{f.bit_offset} #{desc}"
	end
end

exit

puts "Try --help"

