source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.1.2'

gem 'rails', '~> 6.0.4'
gem 'pg', '>= 0.18', '< 2.0'
gem 'puma', '~> 5.6'
gem 'sass-rails', '>= 6'
gem 'webpacker', '~> 5.4'
gem 'jbuilder', '~> 2.11'

gem 'bootsnap', '>= 1.4.2', require: false

group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'dotenv-rails'
end

group :development do
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '~> 3.7'
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

group :test do
  gem 'capybara', '>= 2.15'
  gem 'selenium-webdriver'
  gem 'webdrivers'
end

gem 'ferrum'
gem 'administrate'
gem 'activerecord-missing'
gem 'sidekiq'
gem 'sidekiq-limit_fetch'
gem 'sinatra', require: false
gem 'redis-namespace'
gem 'algoliasearch-rails'
