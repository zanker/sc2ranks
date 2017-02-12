class Notifier < ActionMailer::Base
	def alert(title, message)
		subject title
		from "services@sc2ranks.com"
		recipients "alerts@sc2ranks.com"
		body :message => message
	end
end
