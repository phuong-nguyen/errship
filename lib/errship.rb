require 'rescuers/active_record'
require 'rescuers/mongoid'
require 'rescuers/mongo_mapper'

module Errship
  class Engine < ::Rails::Engine
    paths['app/routes']      = 'config/routes.rb'
    paths['app/views']      << 'app/views'
    paths['config/locales'] << 'config/locales'
  end

  module Rescuers
    def self.included(base)
      unless Rails.application.config.consider_all_requests_local
        base.rescue_from Exception, :with => :render_error
        base.rescue_from ActionController::RoutingError, :with => :render_404_error
        base.rescue_from ActionController::UnknownController, :with => :render_404_error
        base.rescue_from ActionController::UnknownAction, :with => :render_404_error
      end
    end

    def render_error(exception, errship_scope = false)
      airbrake_class.send(:notify, exception) if airbrake_class
      render :template => '/errship/standard', :locals => { 
        :status_code => 500, :errship_scope => errship_scope }
    end

    def render_404_error(exception = nil, errship_scope = false)
      render :template => '/errship/standard', :locals => { 
        :status_code => 404, :errship_scope => errship_scope }
    end

    # A blank page with just the layout and flash message, which can be redirected to when
    # all else fails.
    def errship_standard(errship_scope = false)
      flash[:error] ||= 'An unknown error has occurred, or you have reached this page by mistake.'
      render :template => '/errship/standard', :locals => { 
        :status_code => 500, :errship_scope => errship_scope }
    end

    # Set the error flash and attempt to redirect back. If RedirectBackError is raised,
    # redirect to error_path instead.
    def flashback(error_message, exception = nil)
      airbrake_class.send(:notify, exception) if airbrake_class
      flash[:error] = error_message
      begin
        redirect_to :back
      rescue ActionController::RedirectBackError
        redirect_to error_path
      end
    end

  private
    def airbrake_class
      return Airbrake if defined?(Airbrake)
      return HoptoadNotifier if defined?(HoptoadNotifier)
      return false
    end

  end
end
