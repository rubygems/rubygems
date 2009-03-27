require 'rubygems'

install_extensions = Gem.find_files 'rubygems/discover_install'

install_extensions.each do |extension|
  begin
    load extension
  rescue => e
    warn "error loading #{extension.inspect}: #{e.message} (#{e.class})"
  end
end

