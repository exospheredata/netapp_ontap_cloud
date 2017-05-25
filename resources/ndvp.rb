# Cookbook Name:: netapp_ontap_cloud
# Resource:: ndvp
#
# Author:: Jeremy Goodrum
# Email:: chef@exospheredata.com
#
# Version:: 0.1.0
# Date:: 2017-04-02
#
# Copyright (c) 2017 Exosphere Data LLC, All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'net/http'
require 'net/https'
require 'uri'
require 'json'

default_action :config

# OCCM Required Properties
property :server, String, required: true
property :occm_user, String, required: true
property :occm_password, String, required: true, identity: false, sensitive: true
property :ontap_name, String, required: true, name_property: true # Regex is evaluated in the action
property :tenant_name, String # Future Property
property :svm_password, String, required: true, identity: false, sensitive: true

# NetApp Docker Volume Plugin
property :ndvp_config, String, required: true, default: 'config.json'

action :install do
  case node['platform']
  when 'debian', 'ubuntu'
    package 'nfs-common' do
      action :install
    end
  when 'centos', 'redhat', 'amazon'
    package 'nfs-utils' do
      action :install
    end
  else
    raise 'Unsupported platform.  Unable to install the NetApp docker volume plug-in'
  end

  service 'rpcbind' do
    action [:enable, :start]
  end

  service 'docker' do
    action [:enable, :start]
  end

  # Download the current and most recent version of the NetApp Docker Volume Plug-in
  #
  # TODO: Add checks to ensure Docker version at supported levels as well
  execute 'Install NetApp Docker Volume Plugin' do
    command 'docker plugin install netapp/ndvp-plugin:latest --alias netapp --grant-all-permissions'
    not_if 'docker plugin list | grep netapp:latest'
  end

  execute 'Enable NetApp Docker Volume Plugin' do
    command 'docker plugin enable netapp:latest'
    only_if 'docker plugin list | grep netapp:latest | grep false'
  end

  directory '/etc/systemd/system/docker.service.d/' do
    recursive true
  end

  cookbook_file '/etc/systemd/system/docker.service.d/netappdvp.conf' do
    source 'systemd/netappdvp.override.conf'
    notifies :run, 'execute[systemctl daemon-reload]', :immediately
  end

  execute 'systemctl daemon-reload' do
    action :nothing
    notifies :restart, 'service[docker]', :immediately
  end

  return new_resource.updated_by_last_action(true)
end

action :config do
  # Ensure that this host has OnCommand Cloud Manager up and running.  If recently started then
  # we need to wait for the service to respond.
  server_responding?(new_resource.server, 1)

  # For some reason, the regex on the property name only works when the parameter is sent as ontap_name and not as the name property.
  # This ensures that the validation is set correctly.
  raise ArgumentError, "Option ontap_name's value #{new_resource.ontap_name} does not match regular expression [/^[A-Za-z][A-Za-z0-9_]{2,39}$/]" unless new_resource.ontap_name =~ /^[A-Za-z][A-Za-z0-9_]{2,39}$/

  # Need to store the authentication credentials in a cookie object to be leveraged later.  Setting as a
  # global variable since we need it in so many places.
  @auth_cookie = authenticate_server(new_resource.server, new_resource.occm_user, new_resource.occm_password)

  # Check to see if the instance already exists
  validate_system = get_ontap_env(new_resource.server, new_resource.ontap_name)
  raise ArgumentError, "The ONTAP Cloud System #{new_resource.ontap_name} was not found" unless validate_system

  fields = %w(ontapClusterProperties svms capacityFeatures)
  output_content = get_ontap_details(new_resource.server, validate_system['publicId'], fields)

  directory '/etc/netappdvp' do
    action :create
  end

  ontap_interfaces = output_content['ontapClusterProperties']['nodes'][0]['lifs']
  ontap_mgmt_ip = ontap_interfaces.select { |lif| lif['lifType'] == 'SVM Management' }[0]['ip']
  ontap_data_ip = ontap_interfaces.select { |lif| lif['lifType'] == 'Data' && lif['dataProtocols'].include?('nfs') }[0]['ip']
  ontap_aggr = output_content['svms'].detect { |svm| svm['name'] == "svm_#{new_resource.ontap_name}" }['allowedAggregates'][0]

  template "/etc/netappdvp/#{new_resource.ndvp_config}" do
    source 'netappdvp_config.json.erb'
    variables(
      ontap_mgmt_ip: ontap_mgmt_ip,
      ontap_data_ip: ontap_data_ip,
      ontap_svm_name: output_content['svmName'],
      svm_username: 'vsadmin',
      svm_password: new_resource.svm_password,
      ontap_aggr: ontap_aggr,
      size: '20GB',
      export_policy: "export-svm_#{new_resource.ontap_name}"
    )
    sensitive true
  end

  return new_resource.updated_by_last_action(true)
end

action :delete do
  # Future Property that does nothing as of now
  return new_resource.updated_by_last_action(true)
end

action_class do
  def whyrun_supported?
    true
  end

  def connect_server(url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 600
    http
  end

  def authenticate_server(host, user, password)
    url = URI.parse("https://#{host}/occm/api/auth/login")
    connection = connect_server(url)
    body = {}
    body['email'] = user
    body['password'] = password
    response = http_post(connection, url, body)
    # Return the actual Cookie object
    response.response['set-cookie'].split('; ')[0]
  end

  def server_responding?(host, wait = nil)
    proceed = false
    step_count = 0
    url = URI.parse("https://#{host}/occm/api/occm/system/about")
    connection = connect_server(url)
    until proceed
      begin
        http_get(connection, url)
        return true
      rescue Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Errno::ENETUNREACH
        Chef::Log.info('OnCommand Cloud manager service not reachable')
        return false if wait.nil?
        if step_count < wait
          Chef::Log.info('Pausing for 5 seconds to retry the connection.')
          sleep(5)
          step_count += 1
        else
          Chef::Log.debug('Failed to wait for the server connection')
          raise 'The Service never returned despite waiting patiently'
        end
      else
        # In theory, we should only hit this point if the OnCommand Cloud Manager service
        # is not running or the server is unreachable.
        raise Exception.inspect
      end
    end
  end

  def new_ontap(host, body)
    url = URI.parse("https://#{host}/occm/api/vsa/working-environments")
    begin
      connection = connect_server(url)
    rescue
      raise connection.inspect
    end
    response = http_post(connection, url, body)
    http_response_check(response)
  end

  def delete_ontap(host, public_id)
    url = URI.parse("https://#{host}/occm/api/vsa/working-environments/#{public_id}")
    begin
      connection = connect_server(url)
    rescue
      raise connection.inspect
    end
    response = http_delete(connection, url)
    http_response_check(response)
  end

  def get_ontap_env(host, ontap_name)
    url = URI.parse("https://#{host}/occm/api/vsa/working-environments")
    connection = connect_server(url)
    response = http_get(connection, url)
    we_environments = JSON.parse(response.body)
    we_environments.each do |we_environment|
      # We will return the entire VSA object if the unique name matches.  This is dependent on OCCM
      # maintaining that the name must be unique within the environment.
      return we_environment if we_environment['name'] == ontap_name
    end
    false
  end

  def get_ontap_details(host, public_id, fields = nil)
    uri = "https://#{host}/occm/api/vsa/working-environments/#{public_id}"
    uri += "?fields=#{fields.join(',')}" if fields
    url = URI.parse(uri)
    connection = connect_server(url)
    response = http_get(connection, url)
    we_environment = JSON.parse(response.body)
    return we_environment if we_environment['publicId'] == public_id
    false
  end

  def wait_ontap(host, public_id, action_type = 'Create Vsa Working Environment')
    url = URI.parse("https://#{host}/occm/api/audit?workingEnvironmentId=#{public_id}")
    connection = connect_server(url)
    counter = 0
    while counter < 90 # This provides a wait period of 45mins in the event it takes a long time to execute
      response = http_get(connection, url)
      we_env = JSON.parse(response.body)
      we_env.each do |log|
        next unless log['actionName'] == action_type
        case log['status']
        when 'Success'
          return true
        when 'Failed'
          raise log['errorMessage']
        else
          Chef::Log.info('Waiting for completion of OnCommand Cloud Manager process')
          puts JSON.pretty_generate(log['records'].first)
          sleep(30)
          counter += 1
        end
      end
    end
    raise 'Failed to wait for ONTAP Cloud system'
  end

  def get_tenant_id(host, tenant_name)
    url = URI.parse("https://#{host}/occm/api/tenants")
    connection = connect_server(url)
    response = http_get(connection, url)
    tenants = JSON.parse(response.body)
    tenants.each do |tenant|
      return tenant['publicId'] if tenant['name'] == tenant_name
    end
    raise ArgumentError, "Tenant #{tenant_name} was not found on this server #{host} or is not accessible to this user #{new_resource.occm_user}"
  end

  def validate_vpc_id(host, region, vpc_id)
    url = URI.parse("https://#{host}/occm/api/vsa/metadata/vpcs?region=#{region}")
    connection = connect_server(url)
    response = http_get(connection, url)
    vpcs = JSON.parse(response.body)
    vpcs.each do |vpc|
      return vpc if vpc['vpcId'] == vpc_id
    end
    raise ArgumentError, "VPC #{vpc_id} was not found in the list of available VPCs for this user"
  end

  def validate_subnet_id(host, region, vpc_id, subnet_id)
    vpc = validate_vpc_id(host, region, vpc_id)
    vpc['subnets'].each do |subnet|
      return subnet['subnetId'] if subnet['subnetId'] == subnet_id
    end
    raise ArgumentError, "Subnet #{subnet_id} was not found in the list of available subnets for the VPC #{vpc_id}"
  end

  def http_get(conn, url)
    request = Net::HTTP::Get.new(url)
    request.content_type = 'application/json'
    request['Referrer'] = 'CHEF'
    request['Cookie'] = @auth_cookie if @auth_cookie

    begin
      response = conn.start { |http| http.request(request) }
    rescue Timeout::Error => e
      Chef::Log.info(e.message)
      raise "Timeout::Error: #{e.message}"
    end
    http_response_check(response)
  end

  def http_post(conn, url, body)
    request = Net::HTTP::Post.new(url)
    request.content_type = 'application/json'
    request['Referrer'] = 'CHEF'
    request['Cookie'] = @auth_cookie if @auth_cookie
    body = body.to_json if body.is_a?(Hash)
    request.body = body

    begin
      response = conn.start { |http| http.request(request) }
    rescue Timeout::Error => e
      Chef::Log.info(e.message)
      raise "Timeout::Error: #{e.message}"
    end
    http_response_check(response)
  end

  def http_delete(conn, url)
    request = Net::HTTP::Delete.new(url)
    request.content_type = 'application/json'
    request['Referrer'] = 'CHEF'
    request['Cookie'] = @auth_cookie if @auth_cookie

    begin
      response = conn.start { |http| http.request(request) }
    rescue Timeout::Error => e
      Chef::Log.info(e.message)
      raise "Timeout::Error: #{e.message}"
    end
    http_response_check(response)
  end

  def http_response_check(rsp)
    case rsp
    when Net::HTTPOK, Net::HTTPNoContent, Net::HTTPAccepted
      rsp
    when Net::HTTPUnauthorized
      raise ArgumentError, "Authentication Failed due to invalid credentials: #{JSON.pretty_generate(rsp.body)}"
    when Net::HTTPBadRequest
      output = JSON.parse(rsp.body)
      raise ArgumentError, "OnCommand Cloud Manager - Bad HTTP request error 400: #{output['message']}#{' - ' + output['violations'] if output['violations']}"
    when Net::HTTPClientError,
          Net::HTTPInternalServerError
      raise "Unknown OCCM Server error: #{rsp.body.inspect}"
    else
      raise rsp.inspect
    end
  end
end
