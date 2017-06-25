# Cookbook Name:: netapp_ontap_cloud
# Resource:: ontap_aws
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
property :ontap_name, String, required: true, name_property: true # Regex is evaluated in the action
property :tenant_name, String, required: true

# AWS Configuration
#
# TODO: Move the required aspect of these into an actual method to be called.  These properties are not
# required for every action.
property :region, String, required: true, regex: [/^[a-z]{2}-[a-z]+-\d$/]
property :vpc_id, String, required: true, regex: [/^vpc-[a-zA-Z0-9]{8}$/]
property :subnet_id, String, required: true, regex: [/^subnet-[a-zA-Z0-9]{8}$/]
property :aws_tags, String # Future property

# VsaMetadata
property :instance_type, String, required: true, default: 'm4.xlarge' # TODO: Create a list of supported Instance Types and a method to validate

# Future licenseType = 'cot-premium-byol'
property :license_type, String, equal_to: ['cot-explore-paygo', 'cot-standard-paygo', 'cot-premium-paygo'], default: 'cot-explore-paygo', required: true
property :ontap_version, String, default: 'latest'
property :use_latest, [TrueClass, FalseClass], default: true
property :platform_license, String # Future property

# EBS Volume Types and details
# Supported versions found at https://<occm-host>/occm/api/vsa/metadata/ebs-volume-types
# TODO:  Create a method to match approved sizes to disk types.
#
property :ebs_volume_type, String, equal_to: %w(gp2 st1 sc1), default: 'gp2'
property :ebs_volume_size, String, equal_to: %w(100GB 500GB 1TB 2TB 4TB 8TB), default: '1TB'

property :clusterKeyPairName, String # Future property
property :svm_password, String, required: true, identity: false, sensitive: true

# Maps to skipSnapshots to override if an EBS snapshot should be taken on first deploy
property :bypass_snapshot, [TrueClass, FalseClass], default: false
property :data_encryption_type, String, equal_to: %w(NONE AWS ONTAP), default: 'NONE'

# Sets the writing speed for the ONTAP Cloud system.
#
# WARNING: Changing the write speed of a running ONTAP Cloud system will require that the system reboot
# this will cause an outage to any existing connected clients and servers.
property :write_speed, [String, nil], equal_to: %w(normal high)

# This can be used with resource actions like :create to force the process to wait until after the exeuction
# of the job before moving on.
property :wait_execution, [TrueClass, FalseClass], default: false

# TODO:  Add custom method to verify that account has access to Subscription:
# https://<occm-host>/occm/api/vsa/metadata/validate-subscribed-to-ontap-cloud

action :create do
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
  if validate_system
    Chef::Log.info("ONTAP Cloud system #{new_resource.ontap_name} exists")
    return new_resource.updated_by_last_action(false)
  end

  Chef::Log.info("Creating a new ONTAP Cloud system - #{new_resource.ontap_name}")
  payload = {}
  payload['name'] = new_resource.ontap_name
  payload['tenantId'] = get_tenant_id(new_resource.server, new_resource.tenant_name, @auth_cookie)
  payload['region'] = new_resource.region
  payload['vpcId'] = validate_vpc_id(new_resource.server, new_resource.region, new_resource.vpc_id, @auth_cookie)['vpcId']
  payload['subnetId'] = validate_subnet_id(new_resource.server, new_resource.region, new_resource.vpc_id, new_resource.subnet_id, @auth_cookie)
  payload['ebsVolumeType'] = new_resource.ebs_volume_type

  ebs_volume_metadata = {}
  # Split the provided size into an array to have the number and letters split out.
  ebs_volume_metadata['size'] = (ebs_volume_size.split.map { |x| x[/\d+/] }).join
  ebs_volume_metadata['unit'] = (ebs_volume_size.split.map { |x| x[/[a-zA-Z]+/] }).join

  payload['ebsVolumeSize'] = ebs_volume_metadata
  payload['skipSnapshots'] = new_resource.bypass_snapshot
  payload['dataEncryptionType'] = new_resource.data_encryption_type

  vsa_metadata = {}
  vsa_metadata['platformLicense'] = new_resource.platform_license if new_resource.platform_license
  vsa_metadata['ontapVersion'] = new_resource.ontap_version
  vsa_metadata['useLatestVersion'] = new_resource.use_latest
  vsa_metadata['licenseType'] = new_resource.license_type
  vsa_metadata['instanceType'] = new_resource.instance_type

  payload['vsaMetadata'] = vsa_metadata
  payload['svmPassword'] = new_resource.svm_password
  payload['writingSpeedState'] = new_resource.write_speed.upcase if new_resource.write_speed

  response = new_ontap(new_resource.server, payload)

  output = JSON.parse(response.body)
  Chef::Log.info("ONTAP Cloud System deployment has started - #{output['publicId']}")
  return new_resource.updated_by_last_action(true) unless new_resource.wait_execution
  Chef::Log.info("Waiting on the new ONTAP Cloud system - #{new_resource.ontap_name}")
  wait_ontap(new_resource.server, response['Oncloud-Request-Id'])
  return new_resource.updated_by_last_action(true)
end

action :set_write_speed do
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
  unless validate_system
    Chef::Log.info("The ONTAP Cloud System #{new_resource.ontap_name} was not found")
    return new_resource.updated_by_last_action(false)
  end

  Chef::Log.info("Waiting on the new ONTAP Cloud system - #{new_resource.ontap_name}")

  payload = {}
  payload['writingSpeedState'] = new_resource.write_speed.upcase
  response = set_write_speed(new_resource.server, validate_system['publicId'], payload)

  Chef::Log.info('ONTAP Cloud write speed has been set.  The system will now reboot.')
  wait_ontap(new_resource.server, response['Oncloud-Request-Id'])
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
  unless validate_system
    Chef::Log.info("The ONTAP Cloud System #{new_resource.ontap_name} was not found")
    return new_resource.updated_by_last_action(false)
  end

  Chef::Log.info("Delete ONTAP Cloud system - #{new_resource.ontap_name}")
  response = delete_ontap(new_resource.server, validate_system['publicId'])

  Chef::Log.info("Waiting on the ONTAP Cloud system to Delete - #{new_resource.ontap_name}")

  wait_ontap(new_resource.server, response['Oncloud-Request-Id'])
  return new_resource.updated_by_last_action(true)
end

action_class do
  def whyrun_supported?
    true
  end

  def new_ontap(host, body)
    url = URI.parse("https://#{host}/occm/api/vsa/working-environments")
    begin
      connection = connect_server(url)
    rescue
      raise connection.inspect
    end
    response = http_post(connection, url, body, auth_cookie: @auth_cookie)
    http_response_check(response)
  end

  def set_write_speed(host, public_id, body)
    url = URI.parse("https://#{host}/occm/api/vsa/working-environments/#{public_id}/writing-speed")
    begin
      connection = connect_server(url)
    rescue
      raise connection.inspect
    end
    response = http_put(connection, url, body, auth_cookie: @auth_cookie)
    http_response_check(response)
  end

  def delete_ontap(host, public_id)
    url = URI.parse("https://#{host}/occm/api/vsa/working-environments/#{public_id}")
    begin
      connection = connect_server(url)
    rescue
      raise connection.inspect
    end
    response = http_delete(connection, url, auth_cookie: @auth_cookie)
    http_response_check(response)
  end

  def wait_ontap(host, request_id)
    url = URI.parse("https://#{host}/occm/api/audit/#{request_id}")
    connection = connect_server(url)
    Chef::Log.info('Waiting for completion of OnCommand Cloud Manager process')

    counter = 0
    while counter < 90 # This provides a wait period of 45mins in the event it takes a long time to execute
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
        sleep(30)
        counter += 1
      end
    end
    raise 'Failed to wait for aggregate process'
  end
end
