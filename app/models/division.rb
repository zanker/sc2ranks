class Division < ActiveRecord::Base
	def simple_name
		return self.name.gsub(/Division/, "").strip
	end
end
