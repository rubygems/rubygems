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
      puts "WARNING:\n#{statement}"
      ask(question) if question 
    end
    
    def alert_error(statement, question=nil)
      puts "ERROR:\n#{statement}"
      ask(question) if question
    end

    def terminate_interaction!(code=nil)
      exit!
    end
    
    def terminate_interaction(code=nil)
      exit(code)
    end
  end
end
