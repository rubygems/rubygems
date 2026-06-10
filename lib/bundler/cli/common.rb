# frozen_string_literal: true

module Bundler
  module CLI::Common
    def self.validate_cooldown!(value)
      return if value.nil?
      return if value.is_a?(Integer) && value >= 0
      raise InvalidOption, "Expected `--cooldown` to be a non-negative integer, got #{value.inspect}"
    end

    def self.output_post_install_messages(messages)
      return if Bundler.settings["ignore_messages"]
      messages.to_a.each do |name, msg|
        print_post_install_message(name, msg) unless Bundler.settings["ignore_messages.#{name}"]
      end
    end

    def self.print_post_install_message(name, msg)
      Bundler.ui.confirm "Post-install message from #{name}:"
      Bundler.ui.info msg
    end

    def self.output_fund_metadata_summary
      return if Bundler.settings["ignore_funding_requests"]
      definition = Bundler.definition
      current_dependencies = definition.requested_dependencies
      current_specs = definition.specs

      count = current_dependencies.count {|dep| current_specs[dep.name].first.metadata.key?("funding_uri") }

      return if count.zero?

      intro = count > 1 ? "#{count} installed gems you directly depend on are" : "#{count} installed gem you directly depend on is"
      message = "#{intro} looking for funding.\n  Run `bundle fund` for details"
      Bundler.ui.info message
    end

    def self.output_without_groups_message(command)
      return if Bundler.settings[:without].empty?
      Bundler.ui.confirm without_groups_message(command)
    end

    def self.without_groups_message(command)
      command_in_past_tense = command == :install ? "installed" : "updated"
      groups = Bundler.settings[:without]
      "Gems in the #{verbalize_groups(groups)} were not #{command_in_past_tense}."
    end

    def self.verbalize_groups(groups)
      groups.map! {|g| "'#{g}'" }
      group_list = [groups[0...-1].join(", "), groups[-1..-1]].
        reject {|s| s.to_s.empty? }.join(" and ")
      group_str = groups.size == 1 ? "group" : "groups"
      "#{group_str} #{group_list}"
    end

    def self.select_spec(name, regex_match = nil)
      specs = []
      regexp = Regexp.new(name) if regex_match

      Bundler.definition.specs.each do |spec|
        return spec if spec.name == name
        specs << spec if regexp && spec.name.match?(regexp)
      end

      default_spec = default_gem_spec(name)
      specs << default_spec if default_spec

      case specs.count
      when 0
        dep_in_other_group = Bundler.definition.current_dependencies.find {|dep|dep.name == name }

        if dep_in_other_group
          raise GemNotFound, "Could not find gem '#{name}', because it's in the #{verbalize_groups(dep_in_other_group.groups)}, configured to be ignored."
        else
          raise GemNotFound, gem_not_found_message(name, Bundler.definition.dependencies)
        end
      when 1
        specs.first
      else
        ask_for_spec_from(specs)
      end
    rescue RegexpError
      raise GemNotFound, gem_not_found_message(name, Bundler.definition.dependencies)
    end

    def self.default_gem_spec(name)
      gem_spec = Gem::Specification.find_all_by_name(name).last
      gem_spec if gem_spec&.default_gem?
    end

    def self.ask_for_spec_from(specs)
      specs.each_with_index do |spec, index|
        Bundler.ui.info "#{index.succ} : #{spec.name}", true
      end
      Bundler.ui.info "0 : - exit -", true

      num = ask_for_number(specs.count)
      num && num > 0 ? specs[num - 1] : nil
    end

    # Reads a menu selection in the range 0..max, returning the chosen number
    # or nil if no selection was made (Ctrl-D/EOF). When stdin/stdout are a TTY,
    # a choice is accepted on a single keypress as soon as it is unambiguous,
    # i.e. no larger valid number has the typed digits as a prefix (so "1" is
    # accepted instantly when there are < 10 options, but waits for a second
    # digit when "10"/"11"/... are also valid). Enter resolves the prefix to
    # the number typed so far (e.g. selecting "1" while "10" exists), backspace
    # edits, and Ctrl-C aborts (exit 130). Falls back to a line-based prompt otherwise.
    def self.ask_for_number(max)
      return Bundler.ui.ask("> ").to_i unless single_keypress_supported?

      buf = String.new
      # The prompt, echo and newlines are written straight to $stdout (rather
      # than through Bundler.ui) because this path only runs on an interactive
      # TTY, where we need precise, unbuffered control over the cursor.
      $stdout.print "> "
      $stdout.flush

      loop do
        ch = $stdin.getch
        # "No selection" -- the same outcome as choosing 0/exit -- via either a
        # real EOF (nil, e.g. the terminal detached) or Ctrl-D, which getch's
        # raw mode delivers as a byte (4 = EOT) rather than as EOF.
        if ch.nil? || ch == 4.chr
          $stdout.print "\n"
          return
        end
        # Ctrl-C arrives as a raw byte because getch disables the terminal's
        # signal keys. Re-raising Interrupt here would be re-rescued and printed
        # by with_friendly_errors; instead exit with the conventional SIGINT
        # status (130) so Bundler still terminates with proper signal semantics
        # (see rubygems/bundler#6092) but without dumping a backtrace.
        if ch == 3.chr
          $stdout.print "\n"
          exit(128 + Signal.list["INT"])
        end

        case ch
        when "\r", "\n"
          if valid_number?(buf, max)
            $stdout.print "\n"
            return buf.to_i
          end
        when "\u007f", "\b" # backspace / delete
          unless buf.empty?
            buf.chop!
            $stdout.print "\b \b"
            $stdout.flush
          end
        when /\A[0-9]\z/
          candidate = buf + ch
          # Ignore a digit that cannot lead to any valid selection.
          next unless prefix_of_valid?(candidate, max)
          buf = candidate
          $stdout.print ch
          $stdout.flush
          if valid_number?(buf, max) && !has_longer_valid?(buf, max)
            $stdout.print "\n"
            return buf.to_i
          end
        end
      end
    end

    def self.single_keypress_supported?
      return false unless $stdin.tty? && $stdout.tty?
      require "io/console"
      $stdin.respond_to?(:getch)
    rescue LoadError
      false
    end

    # buf is exactly a valid token (no leading zeros) within 0..max.
    def self.valid_number?(buf, max)
      !buf.empty? && buf == buf.to_i.to_s && buf.to_i <= max
    end

    # Some valid token in 0..max starts with the typed digits (incl. equal).
    def self.prefix_of_valid?(buf, max)
      (0..max).any? {|i| i.to_s.start_with?(buf) }
    end

    # A *longer* valid token in 0..max starts with the typed digits, so the
    # selection is still ambiguous (e.g. "1" while "10" is also valid).
    def self.has_longer_valid?(buf, max)
      (0..max).any? {|i| i.to_s != buf && i.to_s.start_with?(buf) }
    end

    def self.gem_not_found_message(missing_gem_name, alternatives)
      message = "Could not find gem '#{missing_gem_name}'."
      alternate_names = alternatives.map {|a| a.respond_to?(:name) ? a.name : a }
      if alternate_names.include?(missing_gem_name.downcase)
        message += "\nDid you mean '#{missing_gem_name.downcase}'?"
      elsif defined?(DidYouMean::SpellChecker)
        suggestions = DidYouMean::SpellChecker.new(dictionary: alternate_names).correct(missing_gem_name)
        message += "\nDid you mean #{word_list(suggestions)}?" unless suggestions.empty?
      end
      message
    end

    def self.ensure_all_gems_in_lockfile!(names, locked_gems = Bundler.locked_gems)
      return unless locked_gems

      locked_names = locked_gems.specs.map(&:name).uniq
      names.-(locked_names).each do |g|
        raise GemNotFound, gem_not_found_message(g, locked_names)
      end
    end

    def self.configure_gem_version_promoter(definition, options)
      patch_level = patch_level_options(options)
      patch_level << :patch if patch_level.empty? && Bundler.settings[:prefer_patch]
      raise InvalidOption, "Provide only one of the following options: #{patch_level.join(", ")}" unless patch_level.length <= 1

      definition.gem_version_promoter.tap do |gvp|
        gvp.level = patch_level.first || :major
        gvp.strict = options[:strict] || options["filter-strict"]
        gvp.pre = options[:pre]
      end
    end

    def self.patch_level_options(options)
      [:major, :minor, :patch].select {|v| options.keys.include?(v.to_s) }
    end

    def self.clean_after_install?
      clean = Bundler.settings[:clean]
      return clean unless clean.nil?
      clean ||= Bundler.feature_flag.bundler_5_mode? && Bundler.settings[:path].nil?
      clean &&= !Bundler.use_system_gems?
      clean
    end

    def self.word_list(words)
      if words.empty?
        return ""
      end

      words = words.map {|word| "'#{word}'" }

      if words.length == 1
        return words[0]
      end

      [words[0..-2].join(", "), words[-1]].join(" or ")
    end
  end
end
