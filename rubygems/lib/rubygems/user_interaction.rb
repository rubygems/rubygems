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
  end
end
