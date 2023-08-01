# frozen_string_literal: true

require "date"

# Ruby 1.8.7 makes Time#to_datetime private, but we need it
unless Time.public_instance_methods.include? :to_datetime
  class Time
    public :to_datetime
  end
end
