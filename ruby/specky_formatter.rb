
require 'rspec/core/formatters/base_text_formatter'

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
	end

	########################################################################
	### R S P E C  H O O K S
	########################################################################

	### Example group hook -- increase indentation, emit description
	###
	def example_group_started( example_group )
		output.puts
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
		self.out "\n\n\n" unless @failures.empty?

		@failures.each_with_index do |example, index|
			desc      = example.metadata[ :full_description ]
			exception = example.execution_result[ :exception ]

			self.out "FAILURE - #%d)" % [ index + 1 ]

			if RSpec::Core::PendingExampleFixedError === exception
				self.out "%s FIXED" % [ desc ]
				self.out "Expected pending '%s' to fail.  No error was raised." % [
					example.metadata[ :execution_result ][ :pending_message ]
				]
			else
				self.out desc
				self.out "Failure/Error: %s" %  [ read_failed_line( exception, example).strip ]
				exception.message.split("\n").each {|l| self.out l}

				# logic taken from the base class
				example.example_group.ancestors.push(example.example_group).each do |group|
					if group.metadata[:shared_group_name]
						self.out "Shared Example Group: \"#{group.metadata[:shared_group_name]}\" called from " +
							"#{backtrace_line(group.metadata[:example_group][:location])}"
						break
					end
				end
			end
			self.out "\n"
		end
	end


	### Emit summary data for all examples.
	###
	def dump_summary( duration, example_count, failure_count, pending_count )
		succeeded = example_count - failure_count - pending_count
		self.out '+', '-' * 49, '+'
		self.out '|', ' ' * 18, '-- Summary --', ' ' * 18, '|'
		self.out '+----------+-----------+--------+---------+-------+'
		self.out '| Duration | Succeeded | Failed | Pending | Total |'
		self.out '+----------+-----------+--------+---------+-------+'

		self.out "| %7ss | %9s | %6s | %7s | %5s |" % [
			"%0.3f" % duration, succeeded, failure_count,
			pending_count, example_count
		]

		self.out '+----------+-----------+--------+---------+-------+'
	end


	#########
	protected
	#########

	### Send a string to the output IO object, after indentation.
	###
	def out( *msg )
		msg = msg.join
		output.puts "%s%s" % [ '  ' * @indent_level, msg ]
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

