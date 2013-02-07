source "http://rubygems.org"
# Add dependencies required to use your gem here.
# Example:
#   gem "activesupport", ">= 2.3.5"

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
gem 'redis'
gem 'rake'
gem 'jeweler'

group :development do
  gem 'guard', "~> 1.6.0"
  gem "guard-rspec",      "~> 1.2.0"
  gem 'rb-inotify', "~> 0.9.0", :require => false
  gem 'rb-fsevent', "~> 0.9.3", :require => false
  gem 'rb-fchange', "~> 0.0.6", :require => false
end

group :test do
  gem "rspec", "~> 2.8.0"
  gem "fakeredis", :require => "fakeredis/rspec", :git => "git://github.com/guilleiguaran/fakeredis.git"
end
