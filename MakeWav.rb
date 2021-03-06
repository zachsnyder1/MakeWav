# SET GLOBAL VARIABLES:
# table size
$TABLE_SIZE = 400
# initialize a wavetable
$waveTable = Array.new($TABLE_SIZE)

# This class is used to create .wav files from scratch, and to fill the files
# with audio signal data generated by wavetable synthesis.
class Wav
	# Initialize Wav object with the following arguments:
	#   filename == A string that is the name of the .wav file being created;
	#               the string must end in '.wav'.
	#   numChannels == An integer (either 1 or 2) that describes if the file
	#                  is mono or stereo (stereo is default).
	#   sampleRate == An integer that determines the number of samples that are
	#                 used to create every second of ouput signal during
	#                 digital-to-analog conversion.  Acceptable values are
	#                 22050, 32000, 44100 (default), or 48000.
	#                 NOTE: Because this is a wavetable synthesis program,
	#                       distortion is inherent.  With a wavetable size of
	#                       400, sampleRate values of 32000 and 48000 contain
	#                       noticably more distortion, while values of 22050
	#                       and 44100 contain almost no distortion.
	#   bitsPerSample == An integer that determines the bit depth of each
	#                    sample.  Acceptable values are 16 (default) and 32.
	def initialize(filename, numChannels=2, sampleRate=44100, bitsPerSample=16)
		# INITIALIZE THE ARGUEMNTS AS VARIABLES:
		@filename, @numChannels, @sampleRate, @bitsPerSample =
			filename, numChannels, sampleRate, bitsPerSample
		# INITIALIZE SOME OTHER INSTANCE VARIABLES:
		# variable for keeping track of file offset (used when writing to file)
		@file_offset = 0
		# an array in which to put each byte
		@byte1, @byte2, @byte3, @byte4 = [], [], [], []
		# initialize an array for the encoded data, and associated variables
		@dataBlock_array = Array.new()
		@dataBlock_joined = nil
		@samples_per_dataBlock = 0
		# L and R table positions
		@tablePosition_L = 0.0
		@tablePosition_R = 0.0
	end

# ------------------------------------------------------------------------
# |                 METHODS INTENDED FOR INTERNAL USE ONLY:               |
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	# MODE: 'file'
	#    Takes a sample in the form of a 16-bit integer (0 <= X <= 65535) and
	#    writes it to the .wav file as little-endian arranged bytes, as per
	#    the RIFF file specification.
	# MODE: 'dataBlock'
	#    Does the same, but instead of writing the sample to file it adds it
	#    to the 'dataBlock' being constructed.  See compose_new_dataBlock()
	#    below for details about what a dataBlock is.
	# Input parameters are:
	#    int == the integer that will be converted to little-endian binary
	#              and written to file
	#    mode == either 'file' (default) or 'dataBlock'.  Modes are described
	#            above.
	def encode_and_write_int16(int, mode='file')
		# make sure 'byte' arrays are clear
		@byte1.clear
		@byte2.clear
		# convert int argument into binary, put in arrays
		15.downto(8) do |x| @byte1.push(int[x]) end
		7.downto(0) do |x| @byte2.push(int[x]) end

		# order the bytes in little-endian fashion, join
		correct_endianness_binary = [@byte2, @byte1]

		if mode == 'file'
			# join and pack bytes
			binary_to_write = [correct_endianness_binary.join].pack("B*")
			# write binary to file with correct offset
			File.write(@filename, binary_to_write, @file_offset)
			# increment offset for next method call
			@file_offset += 2
		elsif mode == 'dataBlock'
			# push string into dataBlock_array
			@dataBlock_array.push(correct_endianness_binary.join)
		end
	end

	# MODE: 'file'
	#    Takes a sample in the form of a 32-bit integer (0 <= X <= 4,294,967,296)
	#    and writes it to the .wav file as little-endian arranged bytes, as per
	#    the RIFF file specification.
	# MODE: 'dataBlock'
	#    Does the same, but instead of writing the sample to file it adds it
	#    to the 'dataBlock' being constructed.  See compose_new_dataBlock()
	#    below for details about what a dataBlock is.
	# Input parameters are:
	#    int == The integer that will be converted to little-endian binary
	#           and written to file/dataBlock.
	#    mode == Either 'file' (default) or 'dataBlock'.  Modes are described
	#            above.
	#    byte_offset == An integer that indicates the byte offset when writing
	#                   data to the .wav file (otherwise it overwrites data at
	#                   the beginning of the file).  Default is $file_offset
	#                   variable.  Other values are only used in the
	#                   finalize_wav_header() method (see below).
	def encode_and_write_int32(int, mode='file', byte_offset=@file_offset)
		# make sure 'byte' arrays are clear
		@byte1.clear
		@byte2.clear
		@byte3.clear
		@byte4.clear
		# convert int argument into binary, put in arrays
		31.downto(24) do |x| @byte1.push(int[x]) end
		23.downto(16) do |x| @byte2.push(int[x]) end
		15.downto(8) do |x| @byte3.push(int[x]) end
		7.downto(0) do |x| @byte4.push(int[x]) end

		# order the bytes in little-endian fashion (reverse order), join
		correct_endianness_binary = [@byte4, @byte3, @byte2, @byte1]
		if mode == 'file'
			# join and pack bytes
			binary_to_write = [correct_endianness_binary.join].pack("B*")
			# write binary to file with correct offset
			File.write(@filename, binary_to_write, byte_offset)
			# increment offset for next method call
			@file_offset += 4
		elsif mode == 'dataBlock'
			# push string into dataBlock_array
			@dataBlock_array.push(correct_endianness_binary.join)
		end
	end

	# Convert a floating point sample value to a 16-bit integer value
	# and write value to file.  Input parameter is:
	#    float_sample == a floating point number that is the sample value that
	#                    will be converted and written to file/dataBlock
	#    mode == 'file' or 'dataBlock' (passed on to encode_and_write method)
	def convert_and_write_float_sample_16bit(float_sample, mode='file')
		# converts sample to 16-bit integer and calls encode-and-write method
		# positive values have one conversion equation...
		if float_sample >= 0
			int_sample = (float_sample * 32767.to_f).round
			# write rounded value to file
			encode_and_write_int16(int_sample, mode)
		# ...negative values have another
		elsif float_sample < 0
			int_sample = (((float_sample + 1.to_f) * 32767.to_f) +
				32768.to_f).round
			# write rounded value to file
			encode_and_write_int16(int_sample, mode)
		end
	end

	# Convert a floating point sample value to a 32-bit integer value
	# and write value to file.  Input parameter is:
	#    float_sample == a floating point number that is the sample value that
	#                    will be converted and written to file/dataBlock
	#    mode == 'file' or 'dataBlock' (passed on to encode_and_write method)
	def convert_and_write_float_sample_32bit(float_sample, mode='file')
		# converts sample to 32-bit integer and calls encode-and-write method
		# positive values have one conversion equation...
		if float_sample >= 0
			int_sample = (float_sample * 2147483647.to_f).round
			# write rounded value to file
			encode_and_write_int32(int_sample, mode)
		# ...negative values have another
		elsif float_sample < 0
			int_sample = (((float_sample + 1.to_f) * 2147483647.to_f) +
				2147483648.to_f).round
			# write rounded value to file
			encode_and_write_int32(int_sample, mode)
		end
	end

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# |                       ...END INTERNAL METHODS                         |
# ------------------------------------------------------------------------

	# Every .wav file consists of an RIFF chunk-header (12 bytes), a
	# 'fmt ' subchunk (24 bytes), and a 'data' subchunk that contains
	# (8 bytes of info) + audio data.  THIS METHOD writes the RIFF/.wav
	# header, which is all 44 bytes preceding the audio data.
	def write_wav_header()
		# calculate additional parameters included in the .wav header
		block_align = (@bitsPerSample * @numChannels) / 8
		byte_rate = (@sampleRate * @numChannels * @bitsPerSample) / 8

		# write first 16 bytes to file (always the same)
		# 'xxxx' portion will be modified in finalize_wav_header() method (see below)
		File.write(@filename, 'RIFFxxxxWAVEfmt ', @file_offset)
		@file_offset += 16

		# write the rest of the header, except the 'data' subchunk header
		self.encode_and_write_int32(16) # set Subchunk1Size in header
		self.encode_and_write_int16(1) # set AudioFormat to 1 (PCM) in header
		self.encode_and_write_int16(@numChannels) # set NumChannels in header
		self.encode_and_write_int32(@sampleRate) # set SampleRate in header
		self.encode_and_write_int32(byte_rate) # set ByteRate in header
		self.encode_and_write_int16(block_align) # set block align in header
		self.encode_and_write_int16(@bitsPerSample) # set BitsPerSample in header

		# write 8 byte 'data' subchunk header info
		# 'xxxx' portion will be modified in finalize_wav_header() method (see below)
		File.write(@filename, 'dataxxxx', @file_offset)
		@file_offset += 8
	end

	# EXPLANATION OF DATABLOCK:
	#   Converting each sample to an integer and changing it from big-endian to
	#   little-endian bit order is very inefficient.  In order to speed up the
	#   alogrithm, the waveform in the wavetable is only converted and encoded
	#   once, then that data is saved and written to file repeatedly.  The
	#   converted and encoded waveform is called a 'dataBlock'.
	#
	# This method, given a pitchIncrementer value, creates a new data block
	# for the frequency corresponding to that value.  Input parameter is:
	#    pitchIncrementer == a floating point number used to increment the
	#                        wavetable index, therby adjusting pitch
	def compose_new_dataBlock(pitchIncrementer)
		# clear the 'dataBlock' array
		@dataBlock_array.clear
		# adjust pitchIncrementer to account for sample rate
		adjusted_incrementer = (44100.to_f / @sampleRate.to_f) * pitchIncrementer.to_f
		# determine samples_per_dataBlock, provided that each dataBlock is equal
		# to one waveform period
		if ($TABLE_SIZE.to_f).modulo(adjusted_incrementer) == 0.0
			@samples_per_dataBlock = ($TABLE_SIZE.to_f / adjusted_incrementer).to_i
		else
		    @samples_per_dataBlock = (($TABLE_SIZE.to_f / adjusted_incrementer).truncate)
		end
		# reset table positions to 0.0
		@tablePosition_L = 0.0
		@tablePosition_R = 0.0
		# CREATE THE DATABLOCK:
		for i in (0...@samples_per_dataBlock)
			# given table position values, get sample value from wavetable
			sample_value_L = $waveTable[@tablePosition_L.round]
			sample_value_R = $waveTable[@tablePosition_R.round]
			# write each channel to dataBlock
			if @bitsPerSample == 16
				self.convert_and_write_float_sample_16bit(sample_value_L, mode='dataBlock')
				if @numChannels == 2
					self.convert_and_write_float_sample_16bit(sample_value_R, mode='dataBlock')
				end
			elsif @bitsPerSample == 32
				self.convert_and_write_float_sample_32bit(sample_value_L, mode='dataBlock')
				if @numChannels == 2
					self.convert_and_write_float_sample_32bit(sample_value_R, mode='dataBlock')
				end
			end
			# increment the R and L table positions
			@tablePosition_L += adjusted_incrementer
			@tablePosition_R += adjusted_incrementer
		end
		# join the dataBlock array to form the finished dataBlock
		@dataBlock_joined = nil
		@dataBlock_joined = [@dataBlock_array.join].pack("B*")
	end

	# This method writes the dataBlock to file repeatedly, until (noteduration)
	# seconds of audio signal have been written.  Input parameter is:
	#   miliseconds == number of seconds (integer) of audio signal that will
	#                   be written as the waveform contained in the dataBlock
	def write_dataBlock_to_file(miliseconds)
		# calculate the number of dataBlocks to write to file
		numBlocks_to_write = (miliseconds.to_f * @sampleRate.to_f /
		    @samples_per_dataBlock.to_f) / 1000.to_f
		# calculate bytes per sample
		if @bitsPerSample == 16
			bytesPerSample = 2
		elsif @bitsPerSample == 32
			bytesPerSample = 4
		end
		# write the dataBlocks to file
		for i in (0..numBlocks_to_write.round)
			# write binary to file with correct offset
			File.write(@filename, @dataBlock_joined, @file_offset)
			# increment offset for next method call
			@file_offset += @samples_per_dataBlock * @numChannels * bytesPerSample
		end
	end

	# Modify Chunksize and Subchunk2Size parameters of .wav header.
	def finalize_wav_header()
		# these are the byte offsets for the Chunksize and Subchunk2Size
		# parts of the .wav file header
		chunk_size = @file_offset - 8
		subChunk2_size = chunk_size - 36
		# set ChunkSize in header
		encode_and_write_int32(chunk_size, mode='file', byte_offset=4)
		# set Subchunk2Size in header
		encode_and_write_int32(subChunk2_size, mode='file', byte_offset=40)
	end
end

# This class is used to write/rewrite the wavetable with a new waveform.
class WaveTable
	# write a sine wave to the wavetable
	def self.sine
		for i in (0...$TABLE_SIZE)
			$waveTable[i] = Math.sin((i.to_f/$TABLE_SIZE.to_f) * Math::PI * 2.0)
		end
	end

	# write a pseudo-square wave to the wavetable
	def self.square
		# check that $TABLE_SIZE is an even number, if not
		if $TABLE_SIZE % 2 != 0
			print "\n\tERROR: $TABLE_SIZE needs to be an even integer to "
			print "make a square wave\n"
			return
		end
		# put a square wave in the wavetable
		for i in (0...$TABLE_SIZE)
			if i < ($TABLE_SIZE / 2)
				$waveTable[i] = 0.15
			else
				$waveTable[i] = -0.15
			end
		end
	end

	# write a custom wave to the wavetable (must write a sine wave first,
	# or a null table will be created)
	def self.custom
		# make sure wavetable is a sine waveform
		self.sine
		# initialize the array to hold the amplitudes of the harmonics
		harmonic_amplitudes = Array.new(32, nil)
		command_check = nil
		# print info to terminal
		print "\n\t\t ---- SYNTHESIZE A CUSTOM TIMBRE ----\n\n"
		print "type 'z' and hit RETURN for custom synthesis info\n"
		print "type 's' and hit RETURN to synthesize timbre with current parameters\n"
		print "type 'x' and hit RETURN to abort program\n\n"
		print "Enter amplitude of each harmonic:"
		# loop gets harmonic amplitude info
		for x in (0...32)
			# prompt for harmonic amplitude info
			if x == 0
				print "\n  Fundamental: "
				command_check = STDIN.gets.chomp
			else
				print "  Harmonic #{x}: "
				command_check = STDIN.gets.chomp
			end

			# command is processed
			if command_check == 'z'
				print "\n\nCUSTOM TIMBRE INFO:\n\n"
				print "The 'synthesize custom timbre' function allows you to synthesize a new sound by"
				print "\nsetting the relative amplitude for each harmonic, up to the 31st harmonic."
				print "\nRelative amplitudes are values between 0 and 100.  Enter a value for each"
				print "\nharmonic as you are promted.  A value of 0 means the harmonic is not"
				print "\nincluded in the sound.  When you have entered a value for the highest"
				print "\nharmonic that you want to include, enter 's' (without quotations) to"
				print "\nsynthesize the sound.\n\n", "  LOCAL COMMANDS:\n"
				print "  --------------\n", "    z   --->  Print custom synthesis info\n"
				print "    s   --->  Synthesize waveform\n", "    x   --->  Abort program\n"
				redo
			elsif command_check == 'x'
				puts "PROGRAM ABORTED"
				exit
			elsif command_check == 's' && x == 0
				print "\n\tERROR: Enter amplitude for one or more frequency\n"
				redo
			elsif command_check == 's'
				x = 32
				puts "\t         ---------- end of function ----------\n\n"
				puts "Creating custom wave...\n"
				break
			elsif command_check.to_i > 100
				print "\n\tERROR: Amplitude needs to be 0<=X<=100\n\n"
				redo
			else
				harmonic_amplitudes[x] = command_check.to_i
			end
		end

		# set up some more variables
		addedAmps_scaling = 0
		added_amplitudes = 0.0
		temp_table = Array.new($TABLE_SIZE, 0.0)

		# Overall amplitude of the synthesized waveform is scaled
		# to avoid an arithmetic overflow.
		for i in (0..32)
			unless harmonic_amplitudes[i] == nil
				addedAmps_scaling += harmonic_amplitudes[i]
			end
		end

		# harmonics are added together, one wavetable index at a time
		for i in (0...$TABLE_SIZE)
			added_amplitudes = 0
			for x in (0..32)
				added_amplitudes += ((harmonic_amplitudes[x].to_f / 100.to_f) *
					$waveTable[((x+1) * i) % $TABLE_SIZE]) /
					(addedAmps_scaling.to_f / 100.to_f)
			end
			# added value is stored in a temporary table
			temp_table[i] = added_amplitudes
		end

		# main wavetable is replaced with temp table
		for i in (0...$TABLE_SIZE)
			$waveTable[i] = temp_table[i]
		end
	end
end

# This class is used to initiate and run the program with user input.
class UserInterface
	# for producing prompt info:
	@promptParameter = nil
	# for command processing purposes:
	@command = nil # holds an user command
	@ui_section = nil # so self.process_local_commands prints correct info
	@loop_set = true # for prompt loops
	@write_melody = false # for 'melody creation' prompt loop
	@octave = 3 # for pitch calculation in 'melody creation' loop
	# initiate file creation parameters
	@filename, @numChannels, @sampleRate, @bitsPerSample = nil, nil, nil, nil

# ------------------------------------------------------------------------
# |                 METHODS INTENDED FOR INTERNAL USE ONLY:               |
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

	# print prompt info, based on prompting parameter
	def self.print_prompt
		# print appropriate prompt info
		if @promptParameter == 'timbre'
			puts "Choose timbre for wavetable:"
			puts "  1) Sine wave", "  2) Square wave", "  3) Custom timbre"
		elsif @promptParameter == 'filename'
			puts "What do you want to call the .wav file? (must end with '.wav')"
		elsif @promptParameter == 'numChannels'
			puts "Will #{@filename} be mono or stereo?", "  1) Mono", "  2) Stereo"
		elsif @promptParameter == 'sampleRate'
			puts "Choose sample rate for #{@filename}:", "  1) 22050 Hz"
			puts "  2) 32000 Hz", "  3) 44100 Hz (recommended)", "  4) 48000 Hz"
		elsif @promptParameter == 'bitsPerSample'
			puts "Choose sample bit-depth for #{@filename}:"
			puts "  1) 16-bit", "  2) 32-bit"
		elsif @promptParameter == 'note'
			print " Note: "
			return
		elsif @promptParameter == 'duration'
			print "  Its duration: "
			return
		elsif @promptParameter == 'tempo'
			puts "Enter tempo in beats/min:"
		end
		# print the actual prompt
		print ">> "
	end

	# actually prompts, processes info and abort commands, else returns command
	# to self.initialize_with_user_input() method for processing
	def self.process_local_commands
		@command = STDIN.gets.chomp
		if @command == 'z' and @ui_section == 'init'
			print "\nMAKE WAV INFO:\n\n"
			print "This program writes a .wav file (following the RIFF specification) and "
			print "\nallows you to fill the file with audio data created through wavetable"
			print "\nsynthesis.  After it is created, the file should be playable by any"
			print "\nstandard audio player (e.g. iTunes)."
			print "\n\n  WAV FILE PARAMETERS:\n  --------------------\n"
			print "    'timbre' => The waveform that is used for wavetable synthesis.\n"
			print "    'filename' => The name of the WAV file that will be created.  This\n"
			print "                MUST end in the '.wav' file extension.\n"
			print "    'number of channels' => One channel creates a mono file.  Two channels\n"
			print "                            creates a stereo file.  These are functionally\n"
			print "                            equivalent if both channels contain the same info,\n"
			print "                            but the stereo file will be twice as large.\n"
			print "    'sample rate' => The number of samples per second of audio.  A higher\n"
			print "                     sampe rate translates to a greater available bandwidth\n"
			print "                     for the audio signal.  44100 Hz is recommended.\n"
			print "    'bit-depth => The number of bits in each audio sample.  Higher bit-depth\n"
			print "                  means more precise amplitude values, assuming ideal DAC\n"
			print "                  performance.\n\n", "  LOCAL COMMANDS:\n"
			print "  --------------\n", "    z   --->  Print (this) info\n"
			print "    x   --->  Abort program\n\n"
			self.print_prompt
			return -1
		elsif @command == 'z' and @ui_section == 'melody_creation'
			print "\nMELODY CREATION:\n\n"
			print "Compose the melody to be written to #{@filename} by entering information\n"
			print "for each successive note.  EXAMPLE:\n\n"
			print "  Note: a#                <-------- Writes an A-sharp in the current octave...\n"
			print "   Its duration: 1/8      <-------- ...for an 'eighth note' duration.\n"
			print "  Note: cb                <-------- Writes a C-flat in the current octave...\n"
			print "   Its duration: 1        <-------- ...for a 'whole note' duration.\n\n"
			print "  LOCAL COMMANDS:\n", "  --------------\n", "    +   --->  Go up an octave\n"
			print "    -   --->  Go down an octave\n", "    w   --->  Write the file\n"
			print "    z   --->  Print (this) info\n", "    x   --->  Abort program\n\n"
			self.print_prompt
			return -1
		elsif @command == '+' and @ui_section == 'melody_creation'
			if @octave == 5
				puts "Already at highest octave"
			else
				@octave += 1
				puts "OCTAVE = #{@octave}"
			end
			self.print_prompt
			return -1
		elsif @command == '-' and @ui_section == 'melody_creation'
			if @octave == 2
				puts "Already at lowest octave"
			else
				@octave -= 1
				puts "OCTAVE = #{@octave}"
			end
			self.print_prompt
			return -1
		elsif @command == 'x'
			puts "PROGRAM ABORTED"
			exit
		else
			return @command
		end
	end

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# |                       ...END INTERNAL METHODS                         |
# ------------------------------------------------------------------------

	# this method prompts user for .wav file parameter info and initializes
	# a Wav object with those values
	def self.initialize_with_user_input
		# ----------------------  COLLECT USER INPUT  ----------------------
		@ui_section = 'init'
		# print program info
		puts "\n\t  ---------------------------------------------------"
		puts "\t  |               ---- MAKE WAV ----                |"
		puts "\t  ---------------------------------------------------\n"
		puts "type 'z' and hit RETURN for info"
		puts "type 'x' and hit RETURN to abort program\n\n"
		# prompt for timbre
		@promptParameter = 'timbre'; self.print_prompt
		# command processing loop...
		while @loop_set do
			@command = self.process_local_commands
			if @command == -1
				next
			else
				@loop_set = false
				if @command.to_i == 1
					puts "Creating sine wave..."
					WaveTable.sine
				elsif @command.to_i == 2
					puts "Creating square wave..."
					WaveTable.square
				elsif @command.to_i == 3
					WaveTable.custom
				else
					print "\tERROR: Please enter 1, 2, or 3\n", '>> '
					redo
				end
			end
		end
		# prompt for file name
		@promptParameter = 'filename'; self.print_prompt
		# command processing loop...
		@loop_set = true
		while @loop_set do
			@command = self.process_local_commands
			if @command == -1
				next
			else
				@filename = @command.to_s
				@loop_set = false
			end
		end
		# prompt for number of channels
		@promptParameter = 'numChannels'; self.print_prompt
		# command processing loop...
		@loop_set = true
		while @loop_set do
			@command = self.process_local_commands
			if @command == -1
				next
			else
				@loop_set = false
				if @command.to_i == 1 || @command.to_i == 2
					@numChannels = @command.to_i
				else
					print "\tERROR: Please enter 1 or 2\n", '>> '
					redo
				end
			end
		end
		# prompt for sample rate
		@promptParameter = 'sampleRate'; self.print_prompt
		# command processing loop...
		@loop_set = true
		while @loop_set do
			@command = self.process_local_commands
			if @command == -1
				next
			else
				@loop_set = false
				if @command.to_i == 1
					@sampleRate = 22050
				elsif @command.to_i == 2
					@sampleRate = 32000
				elsif @command.to_i == 3
					@sampleRate = 44100
				elsif @command.to_i == 4
					@sampleRate = 48000
				else
					print "\tERROR: Please enter 1, 2, 3, or 4\n", '>> '
					redo
				end
			end
		end
		# prompt for bit depth
		@promptParameter = 'bitsPerSample'; self.print_prompt
		# command processing loop...
		@loop_set = true
		while @loop_set do
			@command = self.process_local_commands
			if @command == -1
				next
			else
				@loop_set = false
				if @command.to_i == 1
					@bitsPerSample = 16
				elsif @command.to_i == 2
					@bitsPerSample = 32
				else
					print "\tERROR: Please enter 1 or 2\n", '>> '
					redo
				end
			end
		end
		# -----------  INITIALIZE A WAV OBJECT WITH USER INPUT  ------------
		return Wav.new(@filename, @numChannels, @sampleRate, @bitsPerSample)
	end

	# This method prompts the user to create a melody,
	# then writes the melody to file.
	def self.create_melody(initialized_wav)
		# ----------------------  COLLECT USER INPUT  ----------------------
		@ui_section = 'melody_creation'
		# array of 'base pitches' from which to calculate pitch
		baseHZ = [27.5, 29.14, 30.87, 32.7, 34.65, 36.71, 38.89, 41.2,
    		43.65, 46.25, 49.0, 51.91]
    	tempo = nil # holds tempo value
    	pitch, duration = nil, nil # temporary holders for pitch incrementer and duration
		# arrays in which to put melody data
		pitch_array, duration_array = [], []

		# print info to terminal
		print "\n\t\t ---- WRITE A MELODY ----\n\n"
		print "type '+' and hit RETURN to go up an octave\n"
		print "type '-' and hit RETURN to go down an octave\n"
		print "type 'w' and hit RETURN to synthesize melody\n"
		print "type 'z' and hit RETURN for melody creation info\n"
		print "type 'x' and hit RETURN to abort program\n\n"
		# prompt for tempo
		@promptParameter = 'tempo'; self.print_prompt
		# command processing loop...
		@loop_set = true
		while @loop_set do
			@command = self.process_local_commands
			if @command == -1
				next
			else
				if @command.to_i > 400 or @command.to_i < 40
					print "\tERROR: Tempo must be an integer 40 <= X <= 400\n", '>> '
					redo
				else
					tempo = @command.to_i
					@loop_set = false
				end
			end
		end
		# CREATE MELODY:
		puts "\nWrite the melody:", "----------------", "CURRENT OCTAVE = 3"
		until @write_melody 
			# prompt for note
			@promptParameter = 'note'; self.print_prompt
			# command processing loop...
			@loop_set = true
			while @loop_set do
				@command = self.process_local_commands
				if @command == -1
					next
				else
					@loop_set = false
					# calculate pitch incrementer, based on note name
					if @command == 'a'
						pitch = (baseHZ[0] * (2 ** @octave).to_f)/ 110.to_f
					elsif @command == 'a#' or @command == 'bb'
						pitch = (baseHZ[1] * (2 ** @octave).to_f)/ 110.to_f
					elsif @command == 'b' or @command == 'cb'
						pitch = (baseHZ[2] * (2 ** @octave).to_f)/ 110.to_f
					elsif @command == 'c' or @command == 'b#'
						pitch = (baseHZ[3] * (2 ** @octave).to_f)/ 110.to_f
					elsif @command == 'c#' or @command == 'db'
						pitch = (baseHZ[4] * (2 ** @octave).to_f)/ 110.to_f
					elsif @command == 'd'
						pitch = (baseHZ[5] * (2 ** @octave).to_f)/ 110.to_f
					elsif @command == 'd#' or @command == 'eb'
						pitch = (baseHZ[6] * (2 ** @octave).to_f)/ 110.to_f
					elsif @command == 'e' or @command == 'fb'
						pitch = (baseHZ[7] * (2 ** @octave).to_f)/ 110.to_f
					elsif @command == 'f' or @command == 'e#'
						pitch = (baseHZ[8] * (2 ** @octave).to_f)/ 110.to_f
					elsif @command == 'f#' or @command == 'gb'
						pitch = (baseHZ[9] * (2 ** @octave).to_f)/ 110.to_f
					elsif @command == 'g'
						pitch = (baseHZ[10] * (2 ** @octave).to_f)/ 110.to_f
					elsif @command == 'g#'
						pitch = (baseHZ[11] * (2 ** @octave).to_f)/ 110.to_f
					elsif @command == 'w'
						puts "\t      -------- end of function --------\n"
						@write_melody = true
						break
					else
						puts "\tERROR: Please enter a note name (enter 'z' for an example)"
						print ' Try again: '
						redo
					end
					# add pitch to pitch_array
					pitch_array.push(pitch)
				end
			end
			# if command 'w' is received, break from 'melody creation' loop
			if @write_melody
				break
			end
			# prompt for duration
			@promptParameter = 'duration'; self.print_prompt
			# command processing loop...
			@loop_set = true
			while @loop_set and !@write_melody do
				@command = self.process_local_commands
				if @command == -1
					next
				else
					@loop_set = false
					if @command == '1'
						duration = ((60.to_f / tempo.to_f) * 1000.to_f) * 4.to_f
					elsif @command == '1/2'
						duration = ((60.to_f / tempo.to_f) * 1000.to_f) * 2.to_f
					elsif @command == '1/4'
						duration = (60.to_f / tempo.to_f) * 1000.to_f
					elsif @command == '1/8'
						duration = ((60.to_f / tempo.to_f) * 1000.to_f) / 2.to_f
					elsif @command == '1/16'
						duration = ((60.to_f / tempo.to_f) * 1000.to_f) / 4.to_f
					elsif @command == '1/32'
						duration = ((60.to_f / tempo.to_f) * 1000.to_f) / 8.to_f
					elsif @command == 'w'
						puts "\t      -------- end of function --------\n"
						@write_melody = true; duration = 0.0
						break
					else
						puts "\tERROR: Please enter 1, 1/2, 1/4, 1/8, 1/16, or 1/32"
						print '  Try again: '
						redo
					end
					# add duration to duration_array
					duration_array.push(duration.round)
				end
			end
		end
		# -----------------------  WRITE THE FILE  -------------------------
		puts "\nCREATING #{Dir.pwd()}/#{@filename} PLEASE WAIT...\n"
		# write the RIFF chunk header for the file
		initialized_wav.write_wav_header
		# for loop that writes melody
		for i in (0...pitch_array.length)
			# create a new dataBlock for each note
			initialized_wav.compose_new_dataBlock(pitch_array[i])
			# then write the dataBlock for the note's duration value (in miliseconds)
			initialized_wav.write_dataBlock_to_file(duration_array[i])
		end
		# adjust the subchunk size parameters in the RIFF header
		initialized_wav.finalize_wav_header
		puts "...FINISHED\n"
	end
end


# ------------------------------------------------------------------------
# |                           -- MAIN --                                  |
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# initialize the program with user input
wave = UserInterface.initialize_with_user_input
# write a melody to file with user input
UserInterface.create_melody(wave) 