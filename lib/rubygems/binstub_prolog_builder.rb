# frozen_string_literal: true

class Gem::BinstubPrologBuilder

  def prolog(shebang)
    shebang.sub!(/\r$/, '')
    shebang.sub!(/\A(\#!.*?ruby\b)?/) do
      if prolog_script.end_with?("\n")
        prolog_script + ($1 || "#!ruby\n")
      else
        $1 ? prolog_script : "#{prolog_script}\n"
      end
    end
    shebang
  end

  private

  def prolog_script
    @prolog_script ||= resolve_prolog_script
  end

  def resolve_prolog_script
    bindir = RbConfig::CONFIG["bindir"]
    libdir = RbConfig::CONFIG[RbConfig::CONFIG.fetch("libdirname", "libdir")]
    load_relative = RbConfig::CONFIG["LIBRUBY_RELATIVE"] == 'yes'
    ruby_install_name = RbConfig::CONFIG["ruby_install_name"]

    script = +<<~EOS
      bindir="#{load_relative ? '${0%/*}' : bindir.gsub(/\"/, '\\\\"')}"
    EOS

    if !load_relative and libpathenv = RbConfig::CONFIG["LIBPATHENV"]
      pathsep = File::PATH_SEPARATOR
      script << <<~EOS
        libdir="#{load_relative ? '$\{bindir%/bin\}/lib' : libdir.gsub(/\"/, '\\\\"')}"
        export #{libpathenv}="$libdir${#{libpathenv}:+#{pathsep}$#{libpathenv}}"
      EOS
    end

    script << %Q[exec "$bindir/#{ruby_install_name}" "-x" "$0" "$@"\n]

    if load_relative || /\s/ =~ bindir
      <<~EOS
        #!/bin/sh
        # -*- ruby -*-
        _=_\\
        =begin
        #{script.chomp}
        =end
      EOS
    else
      "#!#{bindir}/#{ruby_install_name}"
    end
  end

end
