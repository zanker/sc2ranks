Dir["#{RAILS_ROOT}/lib/jobs/*.rb"].each do |file|
	require file
end

Dir["#{RAILS_ROOT}/lib/armory/*.rb"].each do |file|
	require file
end