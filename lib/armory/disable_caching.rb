if RAILS_ENV == "worker"
	# Monkey patch to disable query caching
	module ActiveRecord
	  module ConnectionAdapters
	    module QueryCache
	      private
	      def cache_sql(sql)
	        yield
	      end
	    end
	  end
	end
end