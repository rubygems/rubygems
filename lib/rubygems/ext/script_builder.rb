# frozen_string_literal: true

#--
# Copyright 2023 Samuel Williams.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

class Gem::Ext::ScriptBuilder < Gem::Ext::Builder
  def self.build(extension, dest_path, results, args=[], lib_dir=nil, extension_dir=Dir.pwd)
    env = {
      "PREFIX_PATH" => dest_path,
      "LIBRARY_PATH" => lib_dir,
      "EXTENSION_PATH" => extension_dir,
    }

    run([extension] + args, results, class_name, Dir.pwd, env)
  end
end
