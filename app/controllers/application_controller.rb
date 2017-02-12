class ApplicationController < ActionController::Base
	helper :all
	helper_method :parameterize

	if RAILS_ENV == "production"
		rescue_from Exception, :with => :render_error
		rescue_from ActionController::UnknownAction, :with => :render_404
		rescue_from ActionController::RoutingError, :with => :render_404
		rescue_from ActionController::MethodNotAllowed, :with => :render_home
		rescue_from ActiveRecord::RecordNotFound, :with => :render_404
	end
	
	private
	def maintenance
	  redirect_to("/")
  end
	
	def parameterize(text)
		return text.match(/[a-zA-Z]+/) ? text.parameterize : ""
	end

	def render_home
		flash[:message] = "Only POST requests are allowed on this URL"
		redirect_to root_path
	end
	
	def render_404
		render :template => "errors/404", :status => 404
		return
	end
	
	def render_error(except)
		env = []
		encoded_env = []
		begin
			for header in request.env.select {|k,v| v.is_a?(String)}
				return if header[0] == "HTTP_USER_AGENT" && header[1] == "Mediapartners-Google"
				
				if header[0] and !header[0].match(/^rack/)
					env.push(header.to_json)
					
					if header[0] == "REQUEST_URI" or header[0] == "PATH_INFO" then
						encoded_env.push(([header[0], Base64.encode64(header[1])]).to_json)
					end
				end
			end
			
			raise env.join("\n<br />")
		rescue Exception => e
		end
		
		trace = ActiveSupport::JSON.decode(except.backtrace.inspect.to_s)
		logger.info "#{except.class}: #{except.message}"
		logger.info trace
		Notifier.deliver_alert("Exception #{except.message}", "Env:<br />#{env}<br /><br />Encoded env:<br />#{encoded_env}<br /><br />Exception: #{except.message}<br /><br />#{trace.join("<br />")}")
		render :template => "errors/500.html.haml", :status => 500
		return
	end
end
