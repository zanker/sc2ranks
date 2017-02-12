module Armory
	class Queue
		def self.force_character(args)
			Armory::Job.enqueue("Jobs::Profile", :region => args[:region], :priority => 9, :tag => args[:tag] || -1, :passed_args => args)
		end
		
		def self.mass_array_characters(characters)
			return if characters.length == 0
			characters.each do |character|
				if Armory::Job.exists?(:class_name => "Jobs::Profile", :bnet_id => character[:bnet_id])
					character[:blacklist] = true
				end
			end
			
			return if characters.length == 0
			ActiveRecord::Base.transaction do
				characters.each do |character|
					next if character[:blacklist]
					Armory::Job.enqueue("Jobs::Profile", :region => character[:region], :priority => 11, :tag => 2, :passed_args => {:region => character[:region], :name => character[:name], :bnet_id => character[:bnet_id]})
				end
			end
		end
		
		def self.mass_characters(region, characters)
			return if characters.length == 0
			Armory::Job.all(:conditions => ["region = ? AND bnet_id IN (?) AND class_name = ?", region, characters.keys, "Jobs::Profile"]).each do |job|
				characters.delete(job.bnet_id)
			end
			
			return if characters.length == 0
			
			ActiveRecord::Base.transaction do
				characters.each do |bnet_id, character|
					Armory::Job.enqueue("Jobs::Profile", :region => region, :priority => 10, :tag => 20, :passed_args => {:region => region, :name => character[:name], :bnet_id => bnet_id})
				end
			end
		end
		
		def self.character(args)
			args[:priority] = 11
			args[:priority] = 12 if args[:force]

			job = Armory::Job.first(:conditions => {:class_name => "Jobs::Profile", :bnet_id => args[:bnet_id], :region => args[:region], :locked_by => nil})
			if job.nil?
				args[:priority] ||= priority
				Armory::Job.enqueue("Jobs::Profile", :region => args[:region], :tag => args[:tag] || -1, :priority => args[:priority], :passed_args => args)
				# Bump priority if necessary
			elsif job && ( job.priority.nil? || job.priority < args[:priority] )
				job.priority = args[:priority]
				job.yaml_args = args.to_yaml
				job.save
			end
		end

		def self.achievement(args)
			args[:priority] = 11
			args[:priority] = 12 if args[:force]

			job = Armory::Job.first(:conditions => {:class_name => "Jobs::PullAchievements", :bnet_id => args[:bnet_id], :region => args[:region], :locked_by => nil})
			if job.nil?
				args[:priority] ||= priority
				Armory::Job.enqueue("Jobs::PullAchievements", :region => args[:region], :tag => args[:tag] || -1, :priority => args[:priority], :passed_args => args)
				# Bump priority if necessary
			elsif job && job.priority && args[:priority] && job.priority < args[:priority]
				job.priority = args[:priority]
				job.yaml_args = args.to_yaml
				job.save
			end
		end
		
		def self.division(args)
			args[:priority] = 11
			args[:priority] = 12 if args[:force]

			job = Armory::Job.first(:conditions => {:region => args[:region], :class_name => "Jobs::DivisionChars", :bnet_id => args[:bnet_id], :locked_by => nil})
			if job.nil?
				division = Division.first(:conditions => { :region => args[:region], :bnet_id => args[:bnet_id] } )
				if ( args[:force] == false or args[:force].nil? ) and division
					total = (Rails.cache.fetch("armory/jobs", :expires_in => 10.minutes) do
						Armory::Job.count
					end).to_i
					
					return if args[:is_auto] and total >= 10000
					return if total >= 10000 and division.updated_at >= 48.hours.ago
				end
				
			  	args[:priority] = 20 if division.nil?
				args[:league] = division.league if division
				
				Armory::Job.enqueue("Jobs::DivisionChars", :region => args[:region], :priority => args[:priority], :tag => args[:tag] || -1, :passed_args => args)
			# Bump priority if necessary
			elsif job && job.priority < args[:priority]
				job.priority = args[:priority]
				job.yaml_args = args.to_yaml
				job.save
			end
		end
	end
end
