This is based on the excellent [svd2db](https://mecrisp-stellaris-folkdoc.sourceforge.io/svd2db-v1.html) by Terry Porter.

I refactored the database to be relational which makes it about 5x smaller.

You need to install ruby if not already installed and the following gems...

	> gem install --user-install ox
	> gem install --user-install sqlite3

Then to create the database, specify the svd file you want to process...

	> parse-svd.rb RP2350.svd

Which will create `new_svd.db` which you should rename appropriately.

Once the database has been created you can query it with the `lookup-svd.rb`
script. There are various output formats, from listing all peripherals, to
listing all registers for a specified peripheral.

You can also create `.equ` for assembly code for the register and bitfields in that register, or cretae forth register files (usually used in mecrisp forth).

	Usage: lookup-svd.rb [options]
	    -v, --[no-]verbose               Run verbosely
	    -c, --curdir DIR                 set the current directory
	        --dump                       dump the database
	        --desc                       Show any description
	    -l, --list-peripherals           List all peripherals
	        --regs                       List all registers of the given peripheral
	        --asm                        generate asm output
	        --forth                      generate forth output
	    -d, --database FILENAME          Use this database [otherwise opens a default]
	    -p, --peripheral PERIPHERAL      search for this peripheral
	    -r, --register REGISTER          search for this register

If the `--database` is not specified it will look in the current directory and
search up until it finds a `default-svd.db` to use.

In the sublime-text-plugins directory is a plugin `svd_query.py` for sublimetext 4 which will lookup
peripherals and registers from the SVD database and insert code friendly .equ into your assembler source code for the register and its bit fields. The plugin will call `lookup-svd` which should be on your PATH.

Also the plugin `insert_command_output.py` found in the sublime-text-plugins directory also needs to be installed into sublime (basically copy them to ~/.config/sublime-text/Packages/User/).

(A plugin for the original svd2db database schema is in sublime-text-plugins/old_svd_query.py)
