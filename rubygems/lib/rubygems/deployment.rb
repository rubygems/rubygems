# The following is borrowed from setup.rb

class File; end

def File.binread(fname)
  open(fname, 'rb') {|f|
    return f.read
  }
end

# for corrupted windows stat(2)
def File.dir?(path)
  File.directory?((path[-1,1] == '/') ? path : path + '/')
end


module Gem
  
  module Deployment

    # The following is borrowed from setup.rb
    module FileOperations

      def mkdir_p(dirname, prefix = nil)
        dirname = prefix + File.expand_path(dirname) if prefix
        $stderr.puts "mkdir -p #{dirname}" if verbose?
        return if no_harm?

        # does not check '/'... it's too abnormal case
        dirs = File.expand_path(dirname).split(%r<(?=/)>)
        if /\A[a-z]:\z/i =~ dirs[0]
          disk = dirs.shift
          dirs[0] = disk + dirs[0]
        end
        dirs.each_index do |idx|
          path = dirs[0..idx].join('')
          Dir.mkdir path unless File.dir?(path)
        end
      end

      def rm_f(fname)
        $stderr.puts "rm -f #{fname}" if verbose?
        return if no_harm?

        if File.exist?(fname) or File.symlink?(fname)
          File.chmod 0777, fname
          File.unlink fname
        end
      end

      def rm_rf(dn)
        $stderr.puts "rm -rf #{dn}" if verbose?
        return if no_harm?

        Dir.chdir dn
        Dir.foreach('.') do |fn|
          next if fn == '.'
          next if fn == '..'
          if File.dir?(fn)
            verbose_off {
              rm_rf fn
            }
          else
            verbose_off {
              rm_f fn
            }
          end
        end
        Dir.chdir '..'
        Dir.rmdir dn
      end

      def no_harm?
        false
      end

      def verbose?
        false
      end

      def verbose_off(&block)
        block.call
      end

    end
  
    class Manager
    
      DEPLOYMENTS_DIR = "."
      DEPLOYMENTS_DB = "deployments.yaml"
      
      attr_reader :deployments
    
      def initialize(dir = DEPLOYMENTS_DIR, db = DEPLOYMENTS_DB)
        require 'yaml'
        require 'digest/sha1'
        @db_file = File.expand_path(File.join(dir, db))
        if File.exist?(@db_file)
          @deployments = YAML.load(File.binread(@db_file))
          @deployments.each {|deployment| deployment.manager = self}
        else
          @deployments = []
        end
      end
      
      def new_deployment(target_dir = nil)
        unless target_dir
          require 'rbconfig'
          target_dir = Config::CONFIG['sitelibdir']
        end
        target_dir = File.expand_path(target_dir)
        deployment = self[target_dir]
        unless deployment
          deployment = ActiveDeployment.new(target_dir)
          deployment.manager = self
          @deployments << deployment
        end
        deployment
      end
    
      def persist
        File.open(@db_file, "wb") {|f| f.puts @deployments.to_yaml}
      end
    
      def [](target_dir)
        target_dir = File.expand_path(target_dir)
        @deployments.each {|deployment| return deployment if deployment.target_directory == target_dir}
        nil
      end
    end
  
    class ActiveDeployment
      attr_reader :target_directory, :deployed_gems
      attr_accessor :manager
    
      def initialize(target_directory)
        @target_directory = target_directory
        @deployed_gems = []
      end

      def to_yaml_properties
        ['@target_directory', '@deployed_gems']
      end

      def prepare
        @deployed_gems.each {|gem| gem.prepare}
      end
    
      def deploy
        @deployed_gems.each {|gem| gem.deploy}
        if fully_deployed?
          @manager.persist
        else
          raise "ERROR: Did not fully deploy"
        end
      end

      def fully_deployed?
        @deployed_gems.each {|gem| return false unless gem.deployed?}
        return true
      end
    
      def add_all_gems
        Gem.source_index.each do |name, spec|
          @deployed_gems << DeployedGem.new(spec, @target_directory)
        end
        self
      end
    
      def add_gem(gem_to_add)
        @deployed_gems.each {|dg| return if gem_to_add.full_name == dg.gem_name}
        @deployed_gems << DeployedGem.new(gem_to_add, @target_directory)
        return self if gem_to_add.dependencies.size == 0
        # must fulfill dependencies
        sats = {}
        Gem.source_index.each do |name, gem|
          gem_to_add.dependencies.each do |dependency|
            (sats[dependency] ||= []) << gem if gem.satisfies_requirement?(dependency)
          end
        end
        sats.each_value {|list| add_gem list.sort.last}
        self
      end
    end

    class DeployedGem
      attr_reader :specification, :gem_name, :gem_path, :deployed_files
      
      def initialize(spec, target_directory)
        @gem_name = spec.full_name
        @gem_path = spec.full_gem_path
        @lib_paths = spec.require_paths
        @target_directory = target_directory
        @deployed_files = []
      end

      def to_yaml_properties
        ['@gem_name', '@gem_path', '@lib_paths', '@target_directory', '@deployed_files']
      end
      
      def prepare
        paths = @lib_paths.collect {|lib_path| File.expand_path(File.join(gem_path, lib_path))}
        paths.each do |path|
          Dir.glob("#{path}/**/*").each do |file|
            unless File.directory?(file)
              @deployed_files << DeployedFile.new(file, File.join(@target_directory, file[(path.size+1)..-1]))
            end
          end
        end
        @deployed_files.each {|df| df.prepare}
      end
      
      def deploy
        @deployed_files.each {|file| file.deploy}
      end
      
      def deployed?
        @deployed_files.each {|file| return false unless file.deployed?}
        return true
      end
    end
    
    class DeployedFile
      
      include FileOperations
      
      attr_reader :source_path, :destination_path, :checksum
      
      def initialize(source_path, destination_path)
        @source_path = source_path
        @destination_path = destination_path
      end
      
      def to_yaml_properties
        ['@source_path', '@destination_path', '@checksum']
      end
      
      def prepare
        @checksum ||= Digest::SHA1.new(File.binread(@source_path)).hexdigest
      end
      
      def deploy
        return if deployed?
        File.open(@source_path, "rb") do |source| 
          mkdir_p(File.dirname(@destination_path))
          File.open(@destination_path, "wb") do |destination|
            destination.write(source.read)
          end
        end
      end

      def deployed?
        return false unless File.exist?(@destination_path)
        return false if File.size(@source_path) != File.size(@destination_path)
        new_checksum = nil
        begin
          new_checksum = Digest::SHA1.new(File.binread(@destination_path)).hexdigest
        rescue
          puts $!
          puts $!.backtrace.join("\n")
        end
        new_checksum == @checksum
      end
    end
    
  end
end
