# frozen_string_literal: true

class Gem::BinstubPrologBuilder

  def initialize(cmdtype)
    @cmdtype = cmdtype
  end

  def prolog(shebang)
    shebang.sub!(/\r$/, '')
    script = prolog_script[@cmdtype]
    shebang.sub!(/\A(\#!.*?ruby\b)?/) do
      if script.end_with?("\n")
        script + ($1 || "#!ruby\n")
      else
        $1 ? script : "#{script}\n"
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

    result = {}
    result["exe"] = "#!#{bindir}/#{ruby_install_name}"
    result["cmd"] = <<~EOS
      :""||{ ""=> %q<-*- ruby -*-
      @"%~dp0#{ruby_install_name}" -x "%~f0" %*
      @exit /b %ERRORLEVEL%
      };{#\n#{script.gsub(/(?=\n)/, ' #')}>,\n}
    EOS

    result.default = (load_relative || /\s/ =~ bindir) ?
                              <<~EOS : result["exe"]
      #!/bin/sh
      # -*- ruby -*-
      _=_\\
      =begin
      #{script.chomp}
      =end
    EOS

    result
  end

end
