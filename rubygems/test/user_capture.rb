module UserCapture
  def reset_ui
    @ui = Gem::UserInteraction.capture
    @error = ""
    @warning = ""
    @output = ""
    @terminated = false
    @with_a_bang = false
    
    @ui.on_alert_warning do |message, question|
      @warning << message.to_s
    end
    
    @ui.on_alert_error do |message, question|
      @error << message.to_s
    end
    
    @ui.on_say do |statement|
      @output << statement.to_s
    end

    @ui.on_terminate_interaction! do
      @terminated = true
    end

    @ui.on_terminate_interaction do
      @terminated = true
      @with_a_bang = true
    end
  end
end
