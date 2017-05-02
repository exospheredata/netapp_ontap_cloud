require 'chefspec'
require 'chefspec/berkshelf'
require 'webmock/rspec'

WebMock.allow_net_connect!

at_exit { ChefSpec::Coverage.report! }
