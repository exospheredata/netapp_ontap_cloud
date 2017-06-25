module Occm
  module Helper
    ##########
    # OnCommand Cloud Manager Methods
    ##########
    def connect_server(url)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.read_timeout = 600
      http
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

    def server_configured?(host)
      url = URI.parse("https://#{host}/occm/api/occm/config")
      connection = connect_server(url)
      response = http_get(connection, url, ignore: true)
      return false if JSON.parse(response.body)['message'] == 'OCCM must be setup before performing this operation.'
      true
    end

    def setup_server(host, body)
      url = URI.parse("https://#{host}/occm/api/occm/setup/init")
      connection = connect_server(url)
      http_post(connection, url, body)
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

    ##########
    # ONTAP Cloud Methods
    ##########
    def get_ontap_env(host, ontap_name, auth_token)
      url = URI.parse("https://#{host}/occm/api/vsa/working-environments")
      connection = connect_server(url)
      response = http_get(connection, url, auth_cookie: auth_token)
      we_environments = JSON.parse(response.body)
      we_environments.each do |we_environment|
        # We will return the entire VSA object if the unique name matches.  This is dependent on OCCM
        # maintaining that the name must be unique within the environment.
        return we_environment if we_environment['name'] == ontap_name
      end
      false
    end

    def get_ontap_details(host, public_id, auth_token, fields: [])
      uri = "https://#{host}/occm/api/vsa/working-environments/#{public_id}"
      uri += "?fields=#{fields.join(',')}" if fields
      url = URI.parse(uri)
      connection = connect_server(url)
      response = http_get(connection, url, auth_cookie: auth_token)
      we_environment = JSON.parse(response.body)
      return we_environment if we_environment['publicId'] == public_id
      false
    end

    def get_aggregate_details(host, public_id, auth_token)
      uri = "https://#{host}/occm/api/vsa/aggregates?workingEnvironmentId=#{public_id}"
      url = URI.parse(uri)
      connection = connect_server(url)
      response = http_get(connection, url, auth_cookie: auth_token)
      we_environment = JSON.parse(response.body)
      return we_environment if we_environment
      false
    end

    def get_tenant_id(host, tenant_name, auth_token)
      url = URI.parse("https://#{host}/occm/api/tenants")
      connection = connect_server(url)
      response = http_get(connection, url, auth_cookie: auth_token)
      tenants = JSON.parse(response.body)
      tenants.each do |tenant|
        return tenant['publicId'] if tenant['name'] == tenant_name
      end
      raise ArgumentError, "Tenant #{tenant_name} was not found on this server #{host} or is not accessible to this user."
    end

    ##########
    # AWS Methods
    ##########
    def validate_vpc_id(host, region, vpc_id, auth_token)
      url = URI.parse("https://#{host}/occm/api/vsa/metadata/vpcs?region=#{region}")
      connection = connect_server(url)
      response = http_get(connection, url, auth_cookie: auth_token)
      vpcs = JSON.parse(response.body)
      vpcs.each do |vpc|
        return vpc if vpc['vpcId'] == vpc_id
      end
      raise ArgumentError, "VPC #{vpc_id} was not found in the list of available VPCs for this user"
    end

    def validate_subnet_id(host, region, vpc_id, subnet_id, auth_token)
      vpc = validate_vpc_id(host, region, vpc_id, auth_token)
      vpc['subnets'].each do |subnet|
        return subnet['subnetId'] if subnet['subnetId'] == subnet_id
      end
      raise ArgumentError, "Subnet #{subnet_id} was not found in the list of available subnets for the VPC #{vpc_id}"
    end

    ##########
    # HTTP Methods
    ##########
    def http_get(conn, url, ignore: nil, auth_cookie: nil)
      request = Net::HTTP::Get.new(url)
      request.content_type = 'application/json'
      request['Referrer'] = 'ExosphereDataLLC'
      request['Cookie'] = auth_cookie if auth_cookie

      begin
        response = conn.start { |http| http.request(request) }
      rescue Timeout::Error => e
        Chef::Log.info(e.message)
        raise "Timeout::Error: #{e.message}"
      end
      return response if ignore
      http_response_check(response)
    end

    def http_post(conn, url, body, auth_cookie: nil)
      request = Net::HTTP::Post.new(url)
      request.content_type = 'application/json'
      request['Referrer'] = 'ExosphereDataLLC'
      request['Cookie'] = auth_cookie if auth_cookie
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

    def http_put(conn, url, body, auth_cookie: nil)
      request = Net::HTTP::Put.new(url)
      request.content_type = 'application/json'
      request['Referrer'] = 'ExosphereDataLLC'
      request['Cookie'] = auth_cookie if auth_cookie
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

    def http_delete(conn, url, auth_cookie: nil)
      request = Net::HTTP::Delete.new(url)
      request.content_type = 'application/json'
      request['Referer'] = 'ExosphereDataLLC'
      request['Cookie'] = auth_cookie if auth_cookie

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
end
Chef::Recipe.send(:include, Occm::Helper)
Chef::Resource.send(:include, Occm::Helper)
