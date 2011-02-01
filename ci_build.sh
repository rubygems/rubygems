# You must ensure that rake, hoe, and minitest are already installed in specified RVM interpreter
export rvm_install_on_use_flag=1
export rvm_gemset_create_on_use_flag=1
rvm use $1
. "$HOME/.rvm/environments/ruby-$1" # There seems to be a bug where 'rvm use' from within a script doesn't override default interpreter, so we have to manually source the rvm environment file for the proper interpreter

# TODO: How can you make Hoe's check_extra_deps not use sudo?
#rake check_extra_deps default
# install gems manually for now
gem install 'rake' --no-ri --no-rdoc
gem install 'hoe' --no-ri --no-rdoc
gem install 'builder' -v '~> 2.1' --no-ri --no-rdoc
gem install 'hoe-seattlerb' -v '~> 1.2' --no-ri --no-rdoc
gem install 'minitest' -v '~> 1.4' --no-ri --no-rdoc
gem install 'session' -v '~> 2.4' --no-ri --no-rdoc
gem install 'rubyforge' --no-ri --no-rdoc

echo "----------------------------"
echo "Build environment:"
cat /etc/issue
uname -a
ruby -v
gem env
gem list
echo "----------------------------"

rake default
