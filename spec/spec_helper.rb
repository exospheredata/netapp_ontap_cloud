require 'chefspec'
require 'chefspec/berkshelf'
require 'webmock/rspec'

WebMock.disable_net_connect!(allow_localhost: true)

at_exit { ChefSpec::Coverage.report! }
