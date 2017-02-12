# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
#RAILS_GEM_VERSION = '2.3.14' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')
	
if RAILS_ENV == "production"
	require 'rack/throttle'
	require "memcache"
end

Rails::Initializer.run do |config|
	config.gem "nokogiri"
	config.gem "haml"
	config.gem "system_timer"

	config.time_zone = "UTC"
	
	if RAILS_ENV == "production"
		config.middleware.use Rack::Throttle::Hourly, :cache => MemCache.new(["10.60.157.151:11211"]), :max => 500
	end
end
