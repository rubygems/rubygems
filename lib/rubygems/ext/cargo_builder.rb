# frozen_string_literal: true
require 'rubygems/command'

class Gem::Ext::CargoBuilder < Gem::Ext::Builder
  TemplateScope = Struct.new(:extension_name) do
    def binding
      super
    end
  end

  attr_reader :spec

  def initialize(spec)
    @spec = spec
  end

  def build(extension, dest_path, results, args=[], lib_dir=nil, cargo_dir=Dir.pwd)
    build_rust_static_lib(extension, dest_path, results, args, lib_dir, cargo_dir)
    build_extconf(extension, dest_path, results, args, lib_dir, cargo_dir)
  end

  def build_rust_static_lib(extension, dest_path, results, args=[], lib_dir=nil, cargo_dir=Dir.pwd)
    manifest = File.join(cargo_dir, 'Cargo.toml')

    cmd = []
    cmd += ["cargo", "rustc", "--release"]
    cmd += ["--target-dir", dest_path]
    cmd += ["--manifest-path", manifest]
    cmd += Gem::Command.build_args
    cmd += [*cargo_rustc_args(dest_path)]

    self.class.run cmd, results, self.class.class_name, cargo_dir
    results
  end

  def build_extconf(extension, dest_path, results, args=[], lib_dir=nil, cargo_dir=Dir.pwd)
    require 'erb'

    gemext_dir = File.join(dest_path, 'gemext')
    FileUtils.mkdir_p(gemext_dir)

    locals = TemplateScope.new(spec.name)

    extension_name = spec.name
    compile_erb_template('extension.c.erb', locals, gemext_dir, "#{extension_name}.c")
    compile_erb_template('extension.h.erb', locals, gemext_dir, "#{extension_name}.h")
    compile_erb_template('extconf.rb.erb', locals, gemext_dir, 'extconf.rb')

    Gem::Ext::ExtConfBuilder.build('extconf.rb', dest_path, results, args, lib_dir, gemext_dir)
  end

  def compile_erb_template(name, locals, out_dir, out_path)
    src = File.read(File.expand_path("../cargo_builder/templates/#{name}", __FILE__))
    result = ERB.new(src).result(locals.__send__(:binding))

    File.write(File.join(out_dir, out_path), result)
  end

  def cargo_rustc_args(dest_dir)
    dynamic_linker_flags = RbConfig::CONFIG['DLDFLAGS'].strip

    [
      '--lib',
      '--',
      '-C',
      "link-args=#{dynamic_linker_flags}",
    ]
  end
end
