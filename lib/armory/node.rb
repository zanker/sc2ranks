require "zlib"
require "nokogiri"
require "open-uri"
	
module Armory
	class Node
		attr_accessor :error_code
		cattr_accessor :request_time, :inflate_time, :last_url, :last_response
		
		self.request_time = 0
		self.inflate_time = 0
		
		def after_initialize
			@error_code = 0
		end

		def self.inflate_response(response)
			unless response.meta["content-encoding"] == "gzip"
				self.inflate_time = -1
				return response.read
			end
			
			begin
				start = Time.now.to_f
				content = Zlib::GzipReader.new(StringIO.new(response.read)).read
				self.inflate_time = Time.now.to_f - start
			# This really shouldn't happen, but if it does, return normally
			rescue Zlib::GzipFile::Error => e
				return response.read
			end
			
			return content
		end
		
		def self.base_pull(url)
			self.last_url = url
			#response = `curl --interface 'eth1:2' --silent -i --header "Accept-Encoding: gzip" --header "Cookie: int-SC2=1" --header "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_7) AppleWebKit/534.27 (KHTML, like Gecko) Chrome/12.0.712.0 Safari/534.27" '#{self.last_url}'`
			begin
				return Node.inflate_response(open(self.last_url,
					"Cookie" => "int-SC2=1; int-SC2-pricecut-promo=1; perm=1; int.c.hots-launch=2",
					"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_7) AppleWebKit/534.27 (KHTML, like Gecko) Chrome/12.0.712.0 Safari/534.27 (SC2Ranks Spider)",
					"Accept-Encoding" => "gzip,deflate"))
			rescue OpenURI::HTTPError => e
				raise OpenURI::HTTPError.new(e.io.status[0], e.io)
			end
		end

		def self.pull_custom_data(region, url_args)
			res = self.base_pull("#{BNET_URLS[region]}/sc2/#{LOCALES[region]}/#{url_args.join("/")}")
			return res, self.last_url
		end
		
		def self.cron_pull(region, path)
			self.base_pull("#{BNET_URLS[region]}/sc2/#{LOCALES[region]}/#{path}")
		end
		
		def pull_local_data(job, job_args, url_args)
			# SC2 URLs REQUIRE you to pass the locale for some stupid reason
			# Unless you are on the 
			#self.last_url = "#{BNET_URLS[job.region]}/sc2/#{LOCALES[job.region]}/#{url_args.join("/")}"
			#return Node.inflate_response(open(self.last_url,
			#	"Cookie" => "int-SC2=1",
			#	"User-Agent" => "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_4; en-US) AppleWebKit/534.3 (KHTML, like Gecko) Chrome/6.0.464.0 Safari/534.3",
			#	"Accept-Encoding" => "gzip,deflate"))

			Armory::Node.cron_pull(job.region, url_args.join("/"))
		end
		
		def pull_data(job, job_args, url_args)
			self.error_code = nil
			
			# Keep track of how many requests we have, this will get written when the node pings
			retries = 0
			
			start = Time.now.to_f
			begin
				data = pull_local_data(job, job_args, url_args)
			rescue EOFError => e
				return nil
			rescue OpenURI::HTTPError => e
				puts self.last_url if RAILS_ENV == "development"
				
				# For some stupid reason, the SC2 armory does not give you real errors if a character doesn't exist
				# instead you get 404s, so will guess and assume that means no character :|
				#self.error_code = e.io.status[0]
				self.error_code = e.message

				if self.error_code == "404"
					raise ArmoryParseError.new("noCharacter")
				elsif self.error_code == "503"
					raise ArmoryParseError.new("maintenance")
				elsif self.error_code == "500"
					raise ArmoryParseError.new("badmaint")
				end
				
				raise TemporarilyUnavailableError.new("Code: #{self.error_code}")
			ensure
				self.request_time = Time.now.to_f - start
			end
			
			# Check the data, make sure the armory isn't under maintenance or the character info is messed
			if !data.blank?
				start = Time.now.to_f
				# The site is down for maintenance. We'll be back soon!
				if data.match(/maintenancelogo\.gif/) || data.match(/thermaplugg\.jpg/) || data.match(/landing\-maintenance/)
					raise ArmoryParseError.new("maintenance")
				elsif data.match(/error\-header/) then
					raise ArmoryParseError.new("error")
				end
				
				doc = Nokogiri::HTML(data)
				if doc.blank?
					self.error_code = 500
					raise TemporarilyUnavailableError.new("500")
				end
				
				return doc, data
			end
		end
		
		def self.inspect
			return "{Node(Local) #{Armory::Worker.name}}"
		end
		
		def self.db_time_now
			(ActiveRecord::Base.default_timezone == :utc) ? Time.now.utc : Time.zone.now
	    end
	end
end
