module Gem
  module UserInteraction

    def choose_from_list(question, list)
      puts question
      list.each_with_index do |item, index|
        puts " #{index+1}. #{item}"
      end
      print "> "
      result = STDIN.gets.strip.to_i - 1
      return list[result], result
    end
    
    def ask(question)
      print(question)
      STDIN.gets
    end
    
    def say(statement="")
      puts statement
    end
    
    def alert(statement, question=nil)
      puts "INFO:\n#{statement}"
      return ask(question) if question 
    end
    
    def alert_warning(statement, question=nil)
      STDERR.puts "WARNING:\n#{statement}"
      ask(question) if question 
    end
    
    def alert_error(statement, question=nil)
      STDERR.puts "ERROR:\n#{statement}"
      ask(question) if question
    end

    def terminate_interaction!(status=-1)
      exit!(status)
    end
    
    def terminate_interaction(status=0)
      exit(status)
    end

    def self.capture
      Capture.new
    end
        
    ##
    # The following class lets you capture IO
    #
    class Capture
      def initialize
        [:ask, :say, :choose_from_list, :alert, :alert_error, 
         :alert_warning, :terminate_interaction!, :terminate_interaction].each do |m|
          UserInteraction.send(:define_method, m, &method(m))
        end
      end
      
      def on_choose_from_list(&block)
        @on_choose_from_list = block
      end
      
      def on_ask(&block)
        @on_ask = block
      end
      
      def on_say(&block)
        @on_say = block
      end
      
      def on_alert(&block)
        @on_alert = block
      end
      
      def on_alert_warning(&block)
        @on_alert_warning = block
      end
      
      def on_alert_error(&block)
        @on_alert_error = block
      end
      
      def on_terminate_interaction!(&block)
        @on_terminate_interaction_bang = block
      end

      def on_terminate_interaction(&block)
        @on_terminate_interaction = block
      end
      
      def choose_from_list(question, list)
        @on_choose_from_list.call(question, list) if @on_choose_from_list
      end
      
      def ask(question)
        @on_ask.call(question) if @on_ask
      end
      
      def say(statement="")
        @on_say.call(statement) if @on_say
      end
      
      def alert(statement, question=nil)
        @on_alert.call(statement, question) if @on_alert
      end
      
      def alert_warning(statement, question=nil)
        @on_alert_warning.call(statement, question) if @on_alert_warning
      end
      
      def alert_error(statement, question=nil)
        @on_alert_error.call(statement, question) if @on_alert_error
      end

      def terminate_interaction!(status=-1)
        @on_terminate_interaction_bang.call(status) if @on_terminate_interaction_bang
      end
      
      def terminate_interaction(status=0)
        @on_terminate_interaction.call(status) if @on_terminate_interaction
      end      
    end
  end
end


