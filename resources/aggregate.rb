#
# Cookbook:: netapp_ontap_cloud
# CustomResource:: aggregate
#
# maintainer:: Exosphere Data, LLC
# maintainer_email:: chef@exospheredata.com
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

Chef::Resource.send(:include, Occm::Helper)

require 'net/http'
require 'net/https'
require 'uri'
require 'json'

default_action :create

# OCCM Required Properties
property :server, String, required: true
property :occm_user, String, required: true
property :occm_password, String, required: true, identity: false, sensitive: true
property :ontap_name, String, required: true

property :aggregate, String, required: true, name_property: true, regex: /^[A-Za-z][A-Za-z0-9_]{2,39}$/
property :disk_count, Integer, default: 1

property :ebs_volume_type, String, equal_to: %w(gp2 st1 sc1), default: 'gp2'
property :ebs_volume_size, String, equal_to: %w(100GB 500GB 1TB 2TB 4TB 8TB), default: '1TB'

action :create do
  # Ensure that this host has OnCommand Cloud Manager up and running.  If recently started then
  # we need to wait for the service to respond.
  server_responding?(new_resource.server, 1)

  # Need to store the authentication credentials in a cookie object to be leveraged later.  Setting as a
  # global variable since we need it in so many places.
  @auth_cookie = authenticate_server(new_resource.server, new_resource.occm_user, new_resource.occm_password)

  # Check to see if the instance already exists
  validate_system = get_ontap_env(new_resource.server, new_resource.ontap_name, @auth_cookie)
  raise "ONTAP Cloud system #{new_resource.ontap_name} does not exist" unless validate_system

  aggregate_content = get_aggregate_details(node['occm']['server'], validate_system['publicId'], @auth_cookie)
  return new_resource.updated_by_last_action(false) if aggregate_content.map { |x| x['name'] }.include? new_resource.aggregate

  cluster_content = get_ontap_details(node['occm']['server'], validate_system['publicId'], @auth_cookie, fields: %w(ontapClusterProperties))
  home_node = cluster_content['ontapClusterProperties']['nodes'][0]['name']

  Chef::Log.info("Creating a new ONTAP Cloud system - #{new_resource.ontap_name}")
  payload = {}

  ebs_volume_metadata = {}
  # Split the provided size into an array to have the number and letters split out.
  ebs_volume_metadata['size'] = (ebs_volume_size.split.map { |x| x[/\d+/] }).join
  ebs_volume_metadata['unit'] = (ebs_volume_size.split.map { |x| x[/[a-zA-Z]+/] }).join

  payload['name'] = new_resource.aggregate
  payload['workingEnvironmentId'] = validate_system['publicId']
  payload['numberOfDisks'] = new_resource.disk_count
  payload['diskSize'] = ebs_volume_metadata
  payload['homeNode'] = home_node
  payload['providerVolumeType'] = new_resource.ebs_volume_type

  response = new_aggregate(new_resource.server, payload)

  Chef::Log.info("A new aggregate is being add to the ONTAP Cloud System: #{new_resource.ontap_name}")

  Chef::Log.info("Waiting on the new aggregate (#{new_resource.aggregate}) to be added.")
  wait_aggregate(new_resource.server, response['Oncloud-Request-Id'])
  return new_resource.updated_by_last_action(true)
end

action :add do
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
  validate_system = get_ontap_env(new_resource.server, new_resource.ontap_name, @auth_cookie)
  raise "ONTAP Cloud system #{node['ontap_cloud']['ontap']['standalone']['name']} does not exist" unless validate_system

  aggregate_content = get_aggregate_details(node['occm']['server'], validate_system['publicId'], @auth_cookie)
  raise "The aggregate (#{new_resource.aggregate}) does not exist for ONTAP Cloud system (#{new_resource.ontap_name})" unless aggregate_content.map { |x| x['name'] }.include? new_resource.aggregate

  Chef::Log.info("Add #{new_resource.disk_count} to aggregate (#{new_resource.aggregate}) for ONTAP Cloud system (#{new_resource.ontap_name})")
  response = add_disk_aggregate(new_resource.server, validate_system['publicId'], new_resource.aggregate, new_resource.disk_count)

  wait_aggregate(new_resource.server, response['Oncloud-Request-Id'])
  return new_resource.updated_by_last_action(true)
end

action :delete do
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
  validate_system = get_ontap_env(new_resource.server, new_resource.ontap_name, @auth_cookie)
  raise "ONTAP Cloud system #{node['ontap_cloud']['ontap']['standalone']['name']} does not exist" unless validate_system

  aggregate_content = get_aggregate_details(node['occm']['server'], validate_system['publicId'], @auth_cookie)
  return new_resource.updated_by_last_action(false) unless aggregate_content.map { |x| x['name'] }.include? new_resource.aggregate

  Chef::Log.info("Delete ONTAP Cloud system - #{new_resource.ontap_name}")
  response = delete_aggregate(new_resource.server, validate_system['publicId'], new_resource.aggregate)

  Chef::Log.info("Waiting on the ONTAP Cloud system to Delete - #{new_resource.ontap_name}")

  wait_aggregate(new_resource.server, response['Oncloud-Request-Id'])
  return new_resource.updated_by_last_action(true)
end

action_class do
  def whyrun_supported?
    true
  end

  def new_aggregate(host, body)
    url = URI.parse("https://#{host}/occm/api/vsa/aggregates")
    begin
      connection = connect_server(url)
    rescue
      raise connection.inspect
    end
    response = http_post(connection, url, body, auth_cookie: @auth_cookie)
    http_response_check(response)
  end

  def delete_aggregate(host, public_id, aggr_name)
    url = URI.parse("https://#{host}/occm/api/vsa/aggregates/#{public_id}/#{aggr_name}")
    begin
      connection = connect_server(url)
    rescue
      raise connection.inspect
    end
    response = http_delete(connection, url, auth_cookie: @auth_cookie)
    http_response_check(response)
  end

  def add_disk_aggregate(host, public_id, aggr_name, disk_count)
    url = URI.parse("https://#{host}/occm/api/vsa/aggregates/#{public_id}/#{aggr_name}/disks")
    begin
      connection = connect_server(url)
    rescue
      raise connection.inspect
    end
    body = {}
    body['numberOfDisks'] = disk_count
    response = http_post(connection, url, body, auth_cookie: @auth_cookie)
    http_response_check(response)
  end

  def wait_aggregate(host, request_id)
    url = URI.parse("https://#{host}/occm/api/audit/#{request_id}")
    connection = connect_server(url)
    Chef::Log.info('Waiting for completion of OnCommand Cloud Manager process')

    counter = 0
    while counter < 60 # This provides a wait period of 10mins in the event it takes a long time to execute
      response = http_get(connection, url, auth_cookie: @auth_cookie)
      log = JSON.parse(response.body)[0]
      case log['status']
      when 'Success'
        Chef::Log.info("-- Final action: #{log['records'].first['actionName']}")
        return true
      when 'Failed'
        raise log['errorMessage']
      else
        Chef::Log.info("-- Current action: #{log['records'].first['actionName']}")
        sleep(10)
        counter += 1
      end
    end
    raise 'Failed to wait for aggregate process'
  end
end
