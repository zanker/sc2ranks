require "yaml"
module Armory
	class Job < ActiveRecord::Base
		MAX_RUN_TIME = 600
		JOB_RANDOM_LIMIT = 40
		set_table_name :armory_jobs
		
		def delete_all
			destroy_all()
		end
		
		def self.clear_locks!(worker_name)
			update_all("locked_by = null, locked_at = null", ["locked_by = ?", worker_name])
		end
		
		def self.queue_position(conditions)
			# Find the record we want the queue position of so we have the initial info
			queue = Armory::Job.find(:first, :conditions => conditions, :order => "created_at DESC")
			return 0 if queue.nil?
			
			# Found all the records at our priority level created before us, or those that have a higher priority
			return Armory::Job.count(:all, :conditions => ["(priority = ? and created_at <= ?) or (priority > ?)", queue.priority, queue.created_at, queue.priority])
		end
		
		def unlock
			#begin
			#	self.class.update(self.id, :locked_by => nil, :locked_at => nil, :priority => self.priority, :retries => self.retries)
			#rescue ActiveRecord::RecordNotFound
			#end
			Rails.cache.delete("lock/#{self.id}")
		end
		
		def bump_priority
			# Don't let them get bumped below 2
			self.priority -= 1 if self.priority > 1
			self.retries += 1
			self.created_at = Time.now.utc
			self.save
			self.unlock
		end
		
		def lock_exclusively!(worker_name)
			# Make sure we have no locks already
			result = Rails.cache.read("lock/#{self.id}")
			return nil unless result.nil?

			# Lock it for ourselves
			Rails.cache.write("lock/#{self.id}", "#{worker_name}", :expires_in => 5.minutes)
			
			# Check lock again to make sure nobody else got it
			result = Rails.cache.read("lock/#{self.id}")
			return true if result == worker_name
			
			nil
=begin			
			# We don't own the job, so lock it that we do, provided it's unlocked or it timed out on another worker
			affected_rows = if self.locked_by != worker_name
				self.class.update_all(["locked_at = ?, locked_by = ?", now, worker_name], ["id = ? and (locked_at is null or locked_at < ?)", self.id, now - MAX_RUN_TIME])
			# We own the job already, but it must have crashed. Refresh our lock
			else
				self.class.update_all(["locked_at = ?", now], ["id = ? and locked_by = ?", self.id, worker_name])
			end
			
			# We secured the lock, so lock it to us
			if affected_rows == 1
				self.locked_at = now
				self.locked_by = worker_name
				return true
			end

			return nil
=end
		end
		
		def aquire_lock?(worker_name)
			#puts "#{worker_name}: aquiring lock on #{self.class_name} ##{self.id}"

			# Make sure we got the lock
			unless lock_exclusively!(worker_name)
				logger.warn "#{worker_name}: failed to aquire exclusive lock for #{self.class_name} ##{self.id}"
				return nil
			end
						
			return true
		end
						
		def self.enqueue(klass, args)
			raise NoClassError.new("Jobs must be given a class.") if klass.to_s.empty?						
			if args[:passed_args] and args[:passed_args][:name]
				args[:passed_args][:name] = args[:passed_args][:name].gsub("%5C", "")
			end			

			create(:region => args[:region], :bnet_id => args[:passed_args][:bnet_id], :tag => args[:tag], :class_name => klass.to_s, :yaml_args => args[:passed_args].to_yaml, :priority => args[:priority], :retries => 0)
		end
		
		def self.find_job(node)
			conditions = (Rails.cache.fetch("maint/checks", :expires_in => 5.minutes) do
				list = []
				REGIONS.each do |region|
					if Rails.cache.read("maint/#{region}").to_i >= 100
						list.push("'#{region}'")
					end
				end
				
				(list.length > 0 ? "region NOT IN(#{list.join(",")})" : nil)
			end)
			
			records = find(:all, :conditions => conditions, :order => "priority DESC, created_at ASC", :limit => JOB_RANDOM_LIMIT, :offset => (Rails.env == "production" ? rand(5) : 0))
			return records.sort_by{ rand() }
		end


		def inspect
			return "(Job{%s} %s | %s | %s)" % [self.class_name, self.bnet_id, self.tag, self.yaml_args.inspect]
		end
	    
		def self.db_time_now
			(ActiveRecord::Base.default_timezone == :utc) ? Time.now.utc : Time.zone.now
	    end
	end
end
