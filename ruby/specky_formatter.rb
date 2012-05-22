
require 'rspec/core/formatters/base_text_formatter'
require 'pathname'

### SpeckyFormatter: A basic RSpec 2.x text formatter, to be used
### with the 'Specky' vim plugin (or from the command line, if you
### dig it over the default 'documentation' format!)
###
### rspec -r /path/to/this/specky_formatter.rb -f SpeckyFormatter specs
###
class SpeckyFormatter < RSpec::Core::Formatters::BaseTextFormatter

	def initialize( *args )
		super
		@indent_level  = 0
		@failure_index = 0
		@failures      = []
		@txt           = ''
		@summary       = ''
	end


	########################################################################
	### R S P E C  H O O K S
	########################################################################

	### Example group hook -- increase indentation, emit description
	###
	def example_group_started( example_group )
		self.out '+', '-' * (example_group.description.length + 2), '+'
		self.out '| ', example_group.description, ' |'
		self.out '+', '-' * (example_group.description.length + 2), '+'
		@indent_level += 1
	end


	### Example group hook -- decrease indentation
	###
	def example_group_finished( example_group )
		@indent_level -= 1
	end


	### Called on example success
	###
	def example_passed( example )
		msg = self.format_example( example )
		msg << ')'
		self.out msg
	end


	### Called on a pending example
	###
	def example_pending( example )
		msg = self.format_example( example )
		pending_msg = example.metadata[ :execution_result ][ :pending_message ]
		msg << ", PENDING%s)" % [ ": #{pending_msg}" || '' ]
		self.out msg
	end


	### Called on example failure
	###
	def example_failed( example )
		@failure_index += 1
		msg = self.format_example( example )
		msg << ", FAILED - #%d)" % [ @failure_index ]
		self.out msg

		@failures << example
	end

	### Called after all examples are run.  Emit details for each failed example,
	### for Vim to fold.
	###
	def dump_failures
		self.out "\n" unless @failures.empty?
        cwd = Dir.pwd

		@failures.each_with_index do |example, index|
            srcproc = example.metadata[:example_group_block]
            srcfileline = srcproc.to_s.split('@')
            srcfile, srcline = srcfileline.last.split(/:|>$/)
			#desc      = example.metadata[ :full_description ]
			desc      = example.metadata[ :description ]
			exception = example.execution_result[ :exception ]
			full_filename = line = nil

			self.out "FAILURE - #%d) #{desc}" % [ index + 1 ]

            point_of_failure_file = nil
            if exception.respond_to?( :pending_fixed? ) && exception.pending_fixed?
              self.out "%s FIXED" % [ desc ]
              self.out "Expected pending '%s' to fail.  No error was raised." % [
                example.metadata[ :execution_result ][ :pending_message ]
              ]
            else
              self.out "Caught Exception (#{exception.class.name}):"
              exception.message.split("\n").each {|l| self.out "   |   #{l}" }

              # remove files and characters from backtrace that are just noise
              #
              # this is optimal, but we want to make sure we show just files from
              # this project (cwd) or files from our own included gems, without
              # the noise of rspec source files.  So, we stop printing backtrace
              # once we iterate to files older than our current spec file in the
              # backtrace.  Additionally, use relative paths for conciseness.
              # These backtrace optimizations keep the noise to a minimum without
              # cutting off deeper stacktrace lines that we need to see.
              #
              self.out "Exception Backtrace:"
              max_fd = 0
              first_line = nil
              done = false
              cwd_path = Pathname.new(cwd)
              srcfile_path = Pathname.new(srcfile)
              exception.backtrace.each_with_index { |exline, index|
                begin
                  mp = exline.index(':')
                  filename = exline[0..mp-1]
                  filepath = Pathname.new(filename)
                  trace_line = "#{filepath.relative_path_from(cwd_path)}#{exline[mp..-1]}"
                rescue => ex
                  trace_line = exline
                end
                self.out "   |   #{index}:  #{trace_line}" unless trace_line.nil?
                first_line = [exline, trace_line] if first_line.nil? and !trace_line.nil?
                break if exline.start_with? srcfile
              }
              unless first_line.nil?
                parts = first_line[0].split(':')
                full_filename = parts[0]
                point_of_failure_file = first_line[1].split(':')[0]
                line = parts[1].split(/[^0-9]/)[0].to_i - 1
              end

              self.out "During RSpec:"
              self.out "   | file @ #{srcfile_path.relative_path_from(cwd_path)}"
              self.out "   | line #{srcline}:  #{read_failed_line(exception, example).strip}"

              # logic taken from the base class
              example.example_group.ancestors.push(example.example_group).each do |group|
                if group.metadata[:shared_group_name]
                  self.out "Shared Example Group: \"#{group.metadata[:shared_group_name]}\" called from " +
                    "#{backtrace_line(group.metadata[:example_group][:location])}"
                  break
                end
              end
            end

            self.out "Point of Failure:"
            self.out "   |  @  #{point_of_failure_file}:#{line}"
            self.out "   |  ---------------------------------------------------------------------------------"
            self.out exception_source( full_filename, line ) if full_filename && line
        end
	end


	### Emit the source of the exception, with context lines.
	###
	def exception_source( file, line )
		context = ''
		low, high = line - 3, line + 3

		File.open( file ).each_with_index do |cline, i|
			cline.chomp!.rstrip!
			next unless i >= low && i <= high
			context << "  %s%4d: %s\n" % [ ( i == line ? '>>' : ' |' ), i, cline ]
		end

		return context

	rescue
		'Unable to parse exception context lines.'
	end


	### Emit summary data for all examples.
	###
	def dump_summary( duration, example_count, failure_count, pending_count )
		succeeded = example_count - failure_count - pending_count
		@summary << "+%s+\n" % [ '-' * 49 ]
		@summary << "|%s-- Summary --%s|\n" % [ ' ' * 18, ' ' * 18 ]
		@summary << "+----------+-----------+--------+---------+-------+\n"
		@summary << "| Duration | Succeeded | Failed | Pending | Total |\n"
		@summary << "+----------+-----------+--------+---------+-------+\n"

		@summary << "| %7ss | %9s | %6s | %7s | %5s |\n" % [
			"%0.3f" % duration, succeeded, failure_count,
			pending_count, example_count
		]

		@summary << "+----------+-----------+--------+---------+-------+\n\n"
	end


	### End of run.  Dump it all out!
	###
	def close
		output.puts @summary
		output.puts @txt
	end


	#########
	protected
	#########

	### Send a string to the output IO object, after indentation.
	###
	def out( *msg )
		msg = msg.join
		@txt << "%s%s\n" % [ '  ' * @indent_level, msg ]
	end

	### Format the basic example information, along with the run duration.
	###
	def format_example( example )
		metadata    = example.metadata
		duration    = metadata[ :execution_result ][ :run_time ]
		description = metadata[ :description ]
		return "| %s (%0.3fs" % [ description, duration ]
	end
end # SpeckyFormatter


### Identical to the regular SpeckyFormatter, but it puts summary
### information at the bottom of the screen instead of the top, and just
### spits out rudamentary failure info.
###
class SpeckyFormatterConsole < SpeckyFormatter
	def close
		puts "Failures:" unless @failures.empty?
		@failures.each do |test|
			metadata = test.metadata
			msg = "- %s\n  %s\n  %s:%d\n\n" % [
				metadata[:full_description],
				test.exception.message,
				metadata[:file_path],
				metadata[:line_number]
			]
			puts msg
		end
		output.puts @summary
	end
end

