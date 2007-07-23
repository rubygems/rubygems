require 'open-uri'
require 'yaml'
require 'zlib'
require 'rubygems/command'

class Gem::Commands::MirrorCommand < Gem::Command

  def initialize
    super 'mirror', 'mirror a gem repository'
  end

  def execute
    config_file = File.join Gem.user_home, '.gemmirrorrc'

    raise "Config file #{config_file} not found" unless File.exist? config_file

    mirrors = YAML.load_file config_file

    raise "Invalid config file #{config_file}" unless mirrors.respond_to? :each

    mirrors.each do |mir|
      raise "mirror missing 'from' field" unless mir.has_key? 'from'
      raise "mirror missing 'to' field" unless mir.has_key? 'to'

      get_from = mir['from']
      save_to = File.expand_path mir['to']

      raise "Directory not found: #{save_to}" unless File.exist? save_to
      raise "Not a directory: #{save_to}" unless File.directory? save_to

      gems_dir = File.join save_to, "gems"

      if File.exist? gems_dir then
        raise "Not a directory: #{gems_dir}" unless File.directory? gems_dir
      else
        Dir.mkdir gems_dir
      end

      sourceindex_text = ''

      puts "fetching: #{get_from}/yaml.Z"
      open "#{get_from}/yaml.Z", "r" do |y|
        sourceindex_text = Zlib::Inflate.inflate y.read
        open File.join(save_to, "yaml"), "wb" do |out|
          out.write sourceindex_text
        end
      end

      sourceindex = YAML.load sourceindex_text

      sourceindex.each do |fullname, gem|
        gem_file = "#{fullname}.gem"
        gem_dest = File.join gems_dir, gem_file
        unless File.exists? gem_dest then
          puts "fetching: #{gem_file}"

          begin
            open "#{get_from}/gems/#{gem_file}", "r" do |g|
              contents = g.read
              open gem_dest, "wb" do |out|
                out.write contents
              end
            end
          rescue
            old_gf = gem_file
            gem_file = gem_file.downcase
            retry if old_gf != gem_file
            puts $!
          end
        end
      end
    end
  end

end

