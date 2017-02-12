require "yaml"
require "system_timer"

module Armory
	class Worker
		LOCAL_TIMEOUT = 20.seconds
		SLEEP_TIME = 5
		
		attr_accessor :name_prefix
		cattr_accessor :logger, :request_retries
		
		self.request_retries = 0
	    self.logger = if defined?(Merb::Logger)
			Merb.logger
		elsif defined?(RAILS_DEFAULT_LOGGER)
			RAILS_DEFAULT_LOGGER
	    end
		
		def name
			result = "#{@name_prefix}:#{Socket.gethostname}" rescue "#{@name_prefix}:#{Process.pid}"
			return result || "No name"
		end
				
		# Run the actual job
		def run_job(job, node)
			return if @shutdown
			retries = 0
		
			begin
				return if @shutdown
				klass = job.class_name.constantize
				raise NoClassError.new("Job cannot find class #{job.inspect}.") if klass.to_s.empty?
				
				job_args = YAML::load(job.yaml_args)
				method, url_args = klass.get_url(job_args)
				
				# If a hash is passed as the 2nd argument, it's a request that pulls armory data
				doc, raw_xml = SystemTimer.timeout(LOCAL_TIMEOUT.to_i) do
					doc, raw_xml = node.pull_data(job, job_args, url_args)
				end
				
				if doc.blank? || raw_xml.blank?
					job.unlock
					return nil
				end
				
				klass.send(method, job_args, doc, raw_xml)
				Rails.cache.delete("lock/#{job.id}")
				
				if Rails.cache.read("maint/#{job.region}")
					total = Rails.cache.read("maint/#{job.region}") - 1
					Rails.cache.write("maint/#{job.region}", total, :expires_in => 15.minutes)
					if total <= 0
						Rails.cache.delete("maint/#{job.region}")
						Rails.cache.delete("maint/checks")
					end
				end
					
				job.delete
				return true
			# Shouldn't happen
			rescue Errno::ECONNRESET => e
				say "#{self.name}: Connection reset by peer"
				job.unlock
			# These are bad, it means something is wrong with a node
			rescue Timeout::Error, SocketError, Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EHOSTUNREACH, Errno::ENETUNREACH => e
				say "#{self.name}: Timeout error #{e.message}"

				# Not as accurate as increment, but increment isn't working correctly
				total = (Rails.cache.read("maint/#{job.region}").to_i + 1)
				Rails.cache.write("maint/#{job.region}", total, :expires_in => 15.minutes)
				Rails.cache.delete("maint/checks") if total == 25

				job.unlock
			# Armory temporarily unavailable, not too big of a deal
			rescue TemporarilyUnavailableError => e
				say "#{job.region && job.region.upcase || "??"} Armory temporarily unavailable (#{e.message}) (try ##{job.retries}, #{node.last_url})"
				if e.message =~ /503/
					# Not as accurate as increment, but increment isn't working correctly
					total = (Rails.cache.read("maint/#{job.region}").to_i + 1)
					Rails.cache.write("maint/#{job.region}", total, :expires_in => 15.minutes)
					Rails.cache.delete("maint/checks") if total == 25
				end
				
				# At >= 5 retries, do a priority bump
				job.retries ||= 0
				job.retries += 1
				if job.retries >= 5
					job.retries = 0
					job.bump_priority
				else
					job.save
					job.unlock
				end

			# Failure in parsing the armory
			rescue ArmoryParseError => e
				say "Armory error in #{job.class_name}, #{e.message} for #{job.bnet_id}"
				Armory::Error.new(:region => job.region, :error_type => e.message, :class_name => job.class_name, :bnet_id => job.bnet_id).save
				if e.message == "maintenance"
					# Not as accurate as increment, but increment isn't working correctly
					total = (Rails.cache.read("maint/#{job.region}").to_i + 1)
					Rails.cache.write("maint/#{job.region}", total, :expires_in => 15.minutes)
					Rails.cache.delete("maint/checks") if total == 25
				
					if job.retries >= 100
						Rails.cache.delete("lock/#{job.id}")
						job.delete
					else
						job.bump_priority
					end
				else
					job.delete
				end
			rescue ActiveRecord::StatementInvalid => e
				log_exception(job, node, "SQL Exception", e)
				job.unlock
			# Generic catch-all
			rescue Exception => e
				log_exception(job, node, "Exception", e)
				
				job.retries ||= 0
				job.retries += 1
				
				if job.retries >= 50 || RAILS_ENV != "production"
					Rails.cache.delete("lock/#{job.id}")
					job.delete
				elsif job.retries >= 10
					job.bump_priority
				else
					job.save
					job.unlock
				end
			end

			Rails.cache.delete("lock/#{job.id}")
			return nil
		end
		
		# Lock and get jobs ready to run
		def find_and_lock_job(node)
			Armory::Job.find_job(node).each do |job|
				return job if job.aquire_lock?(self.name)
			end
			
			return nil
		end
		
		def speedy_worker(node)
			loop do
				break if @shutdown
				
				job = find_and_lock_job(node)
				# No jobs, so just wait
				unless job
					say "#{name}: Sleeping for #{SLEEP_TIME} (wait for recheck)"
					sleep SLEEP_TIME
					next
				end
					
				# Onwards to victory!
				start = Time.now.to_f
				self.request_retries = 0
				finished = self.run_job(job, node)
									
				request_time = (Time.now.to_f - start) - node.request_time
				if !finished.nil?
					say "#{name}: Ran #{job.class_name} (#{job.region}), took %.2f seconds (%.2f http)" % [Time.now.to_f - start, node.request_time]
				else
					say "#{name}: Failed to run #{job.class_name} (#{job.region})"
				end
			end
		end
			
		# Monitor and basically dispatch jobs
		def start
			say "#{self.name}: Starting up..."
			startup
				
			begin
				node = Armory::Node.new
				say "#{self.name}: Starting speedy worker #{self.name}"
			rescue Exception => e
				log_exception(nil, node, "Node lock", e)
			end

			retries = 0
			begin
				self.speedy_worker(node)
			# Something bad happened :(
			rescue Exception => e
				log_exception(nil, node, "Catch-all (#{retries})", e)
				Armory::Job.clear_locks!(self.name)
				
				retries += 1
				retry if retries <= 5 and RAILS_ENV == "production"
			ensure
				Armory::Job.clear_locks!(self.name)
			end
			
			say "#{self.name}: Finished"
		end

	    # Runs all the methods needed when a worker begins its lifecycle.
	    def startup
			enable_gc_optimizations
			register_signal_handlers
	    end

	    # Enables GC Optimizations if you're running REE.
	    # http://www.rubyenterpriseedition.com/faq.html#adapt_apps_for_cow
	    def enable_gc_optimizations
			if GC.respond_to?(:copy_on_write_friendly=)
				GC.copy_on_write_friendly = true
			end
	    end

	    # Registers the various signal handlers a worker responds to.
	    #
	    # TERM: Shutdown immediately, stop processing jobs.
	    # INT: Shutdown immediately, stop processing jobs.
	    # QUIT: Shutdown after the current job has finished processing.
	    # USR1: Kill the forked child immediately, continue processing jobs.
	    # USR2: Don't process any new jobs
	    # CONT: Start processing jobs again after a USR2
		def register_signal_handlers
			trap('TERM') { shutdown! }
			trap('INT') { shutdown! }

			begin
				trap('QUIT') { shutdown }
			rescue ArgumentError
			end
		end

	    # Schedule this worker for shutdown. Will finish processing the
	    # current job.
	    def shutdown
			say "#{name}: Exiting..."
			@shutdown = true
	    end

	    # Kill the child and shutdown immediately.
	    def shutdown!
	      shutdown
	    end

		def log_exception(job, node, type, except)
			trace = ActiveSupport::JSON.decode(except.backtrace.inspect.to_s)
			if !job.nil?
				job = job.inspect
			else
				job = "<No job>"
			end
			
			last_url = "<No url>"
			if node.is_a?(Armory::Node)
				last_url = node.last_url if !node.last_url.blank?
			end
			
			say "#{except.class}: #{except.message}"
			say last_url
			say job if !job.nil?
			say trace.join("\n")
			say "---------------------"
			
			if RAILS_ENV == "production"
				Notifier.deliver_alert("#{name} (#{type})", "Job #{job}\n\nURL #{last_url}\n\nNode #{node.inspect}\n\n#{except.class}: #{except.message}\n#{trace.join("\n")}")
			end
		end
		
		def self.say(text)
			puts text unless @quiet
			logger.info text if logger
		end
		
		def say(text)
			puts text unless @quiet
			logger.info text if logger
		end
	end
end
