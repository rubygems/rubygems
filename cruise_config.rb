# Project-specific configuration for CruiseControl.rb
require 'socket'

Project.configure do |project|
  # To add a build for a new interpreter (from ccrb root):
  # ./cruise add RubyGems-x_y_z-pxxx -s git -r git://github.com/rubygems/rubygems.git
  interpreter = Regexp.new(/RubyGems-(.*)$/i).match(project.name)[1]
  interpreter.gsub!('_','.')

  # only send notifications from the official ci box
  if Socket.gethostname =~ /cibuilder.pivotallabs.com/
    # explicitly enable dev list notification only for interpreters which should be green
    interpreters_with_enabled_notification = [
      '1.8.7-p330',
      '1.9.1-p378',
      '1.9.2-p136'
    ]
    if interpreters_with_enabled_notification.include?(interpreter)
      project.email_notifier.emails = ['rubygems-developers@rubyforge.org']
    end

    # Always notify the following for all interpreters:
    project.email_notifier.emails.concat([
      'thewoolleyman+rubygems-ci@gmail.com'
    ])
  end

  project.build_command = "./ci_build.sh '#{interpreter}@rubygems'"

  project.email_notifier.from = 'thewoolleyman+rubygems-ci@gmail.com'
  project.scheduler.polling_interval = 5.minutes
end
