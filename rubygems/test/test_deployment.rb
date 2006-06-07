#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

$:.unshift '../lib'
require 'test/unit'
require 'rubygems'
Gem::manage_gems

class TestDeployment < Test::Unit::TestCase
  
  DEPLOYMENT_TEST_DIR = "deployment_test"
  
  def remove_temp_files
    @filectl.rm_rf(DEPLOYMENT_TEST_DIR) if File.exist?(DEPLOYMENT_TEST_DIR)
    @filectl.rm_f(Gem::Deployment::Manager::DEPLOYMENTS_DB) if File.exist?(Gem::Deployment::Manager::DEPLOYMENTS_DB)
  end
  
  def reset_paths
    remove_temp_files
    Dir.mkdir DEPLOYMENT_TEST_DIR
  end
  
  def test_deploy_dependencies
    return unless @rails_gem
    reset_paths
    dm = Gem::Deployment::Manager.new
    deployment = dm.new_deployment(DEPLOYMENT_TEST_DIR)
    deployment.add_gem(@rails_gem)
    assert deployment.deployed_gems.size > 1
  end
  
  def test_deploy_rails
    return unless @rails_gem
    reset_paths
    dm = Gem::Deployment::Manager.new
    deployment = dm.new_deployment(DEPLOYMENT_TEST_DIR)
    deployment.add_gem(@rails_gem)
    deployment.prepare
    deployment.deploy
    dm2 = Gem::Deployment::Manager.new
    deployment = dm2[DEPLOYMENT_TEST_DIR]
    
    assert_not_nil deployment
    assert_equal File.expand_path(DEPLOYMENT_TEST_DIR), deployment.target_directory
    #puts deployment.deployed_gems.collect {|gem| gem.gem_name}
    #deployment.fully_deployed?
  end

  def xtest_deploy_sources
    reset_paths
    dm = Gem::Deployment::Manager.new
    deployment = dm.new_deployment(DEPLOYMENT_TEST_DIR)
    deployment.add_gem(@sources_gem)
    deployment2 = dm[DEPLOYMENT_TEST_DIR]
    assert_not_nil deployment2
    assert_equal 1, deployment.deployed_gems.size
    deployed_sources = deployment.deployed_gems[0]
    assert_equal "sources-0.0.1", deployed_sources.gem_name
    assert_equal 0, deployed_sources.deployed_files.size
    deployment.prepare
    assert_equal 1, deployed_sources.deployed_files.size
    assert deployed_sources.deployed_files[0].source_path.include?("sources.rb")
    deployment.deploy
    assert File.exist?(File.join(DEPLOYMENT_TEST_DIR, "sources.rb"))
  end
  
  def test_deployed_file
    basename = "deploy_#{Time.now.to_i}"
    source_file = File.expand_path(basename+"1.tmp")
    dest_file = File.expand_path(basename+"2.tmp")
    File.open(source_file, "wb") {|file| file.print "Data"}
    df = Gem::Deployment::DeployedFile.new(source_file, dest_file)
    assert_equal source_file, df.source_path
    assert_equal dest_file, df.destination_path
    assert_nil df.checksum
    df.prepare
    assert_equal Digest::SHA1.new("Data").hexdigest, df.checksum
    df.deploy
    assert File.exist?(dest_file)
    assert df.deployed?
    assert_equal "Data", File.binread(dest_file)
    @filectl.rm_f source_file
    @filectl.rm_f dest_file
  end
  
  def teardown
    remove_temp_files
  end
  
  def setup
    @filectl = Object.new
    @filectl.extend Gem::Deployment::FileOperations
    @rails_gem = Gem.cache.search("rails").sort.last
    @sources_gem = Gem.cache.search("sources").sort.last
  end
end
