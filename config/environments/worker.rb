# Settings specified here will take precedence over those in config/environment.rb
#config.gem "slim-attributes"
#config.gem "smurf"
#config.gem "SystemTimer"

config.cache_store = :mem_cache_store, ["10.60.157.151:11211"]

#require "memcache"
#WorkerCache = MemCache.new(:namespace => "worker")
#WorkerCache.servers = ["72.14.191.151:11000", "72.14.187.10:11000"]

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true

# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true
config.action_view.cache_template_loading            = true

# See everything in the log (default is :info)
config.log_level = :info

# Use a different logger for distributed setups
# config.logger = SyslogLogger.new

# Use a different cache store in production
# config.cache_store = :mem_cache_store

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host = "http://assets.example.com"

# Disable delivery errors, bad email addresses will be ignored
# config.action_mailer.raise_delivery_errors = false

config.action_mailer.default_url_options = {:host => "http://sc2ranks.com"}

# Enable threaded mode
# config.threadsafe!
Sass::Plugin.options[:style] = :compressed
Haml::Template.options[:ugly] = true
