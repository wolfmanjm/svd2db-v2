#!/usr/bin/ruby
require "sequel"
require 'logger'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: lookup-svc.rb [options]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
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

  opts.on("--asm", "generate asm output") do |v|
    options[:asm] = v
  end

  opts.on("--forth", "generate forth output") do |v|
    options[:forth] = v
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
	dbfile = find_file_upwards('default-svd.db')
	if dbfile.nil?
		puts "No database found"
		exit 1
	end
end

if options[:verbose]
	puts "Using databse file #{dbfile}"
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
	pr = mpu.peripherals_dataset.where(name: options[:peripheral]).first
	if pr.nil?
		puts "Unknown peripheral #{options[:peripheral]}"
		exit
	end

	res = pr.registers_dataset.order(:name)
	if res.empty?
		puts "try #{options[:peripheral].chop}0"
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

# create equ's for given peripheral and register
if options[:asm]
	if options[:register].nil?
		puts "register required"
		exit
	end

	pr = mpu.peripherals_dataset.where(name: options[:peripheral]).first
	if pr.nil?
		puts "Unknown peripheral #{options[:peripheral]}"
		exit
	end

	puts ".equ #{pr.name}, #{pr.base_address}"

	res = pr.registers_dataset.where(Sequel.ilike(:name, "%#{options[:register]}"))
	if res.count == 0
		puts "No match for the register #{options[:register]}"
		exit
	end
	if res.count > 1
		puts "more than one match for the register..."
		res.each { |r| puts r.name }
		exit
	end

	res = res.first
	puts "  .equ _#{res.name}, #{res.address_offset}"
	res.fields_dataset.order(:bit_offset).each do |f|
		bf = "#{res.name}_#{f.name}"
        if f.num_bits == 1
			puts "    .equ b_#{bf}, #{f.num_bits}<<#{f.bit_offset}"
        else
            mask = ((2**f.num_bits) - 1) << f.bit_offset
			puts "    .equ m_#{bf}, 0x#{sprintf("%08X", mask)}"
			puts "    .equ o_#{bf}, #{f.bit_offset}"
        end
	end

	exit
end

# create the register structure for forth
if options[:forth]
	pr = mpu.peripherals_dataset.where(name: options[:peripheral]).first
	if pr.nil?
		puts "Unknown peripheral #{options[:peripheral]}"
		exit
	end

	regs = pr.registers_dataset
	if regs.count == 0
		puts "No registers found for #{options[:peripheral]} Base address: #{pr.base_address}. try 0"
		exit
	end

	# create registers
	# use as USART1 _usCR1 leaves address of CR1 register for USART1 on the stack
	puts "#{pr.base_address.sub('0x', '$')} constant #{pr.name}"
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
pr = mpu.peripherals_dataset.where(name: options[:peripheral]).first
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
	puts "No match for the register #{options[:register]}"
	exit
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

