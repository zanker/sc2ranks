class TeamsFromPatch
	# Basic idea is you call TeamsFromPatch.p103 and you will get a model that calls team_patch_103 allowing you to stats off a specific patch
	# if it's the latest patch, it will give you Team
	cattr_accessor :cached_classes
	self.cached_classes = {}
	
	def self.method_missing(str)
		patch = str.to_s.gsub(/p/, "").to_i
		if patch > 0
			return cached_classes[patch] if cached_classes[patch]
			
			if patch == LATEST_PATCH
				klass = Team
			else
				klass = Class.new(ActiveRecord::Base)
				klass.class_eval {
					set_table_name "teams_patch_#{patch}"
				}
			end
			
			cached_classes[patch] = klass
			return klass
		end
		
		throw NoMethodError.new("undefined method `#{str}`")
	end
end
