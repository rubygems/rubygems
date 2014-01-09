# let's shoot for http://tools.ietf.org/html/draft-staykov-hu-json-canonical-form-00
module CanonicalJSON
  # shamelessly copied from
  # https://github.com/tent/tent-canonical-json-ruby/blob/master/lib/tent-canonical-json.rb
  def self.dump data
    case data
    when Hash
      string = data.keys.sort.map do |key|
        "#{key.to_s.inspect.gsub("\\n", "\n")}:#{dump data[key]}"
      end.join(",")
      "{#{string}}"
    when Array
      json = data.map { |i|
        dump(i)
      }.join(",")
      "[#{json}]"
    when Fixnum
      data
    when String, TrueClass, FalseClass
      data.to_s.inspect
    when NilClass
      "null"
    else
      raise TypeError
    end
  end
end
