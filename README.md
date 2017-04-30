# NetApp OnCommand Cloud Manager and ONTAP Cloud
### _A cookbook to manage OCCM and ONTAP Cloud deployments_
This cookbook installs, configures and manages NetApp OnCommand Cloud Manager systems.  The included resources also deploy, manage and destroy NetApp ONTAP Cloud systems.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Requirements](#requirements)
  - [Platforms](#platforms)
  - [Chef](#chef)
  - [Cookbooks](#cookbooks)
  - [Data bags](#data-bags)
  - [Amazon Web Services](#amazon-web-services)
    - [OnCommand Cloud Manager for AWS Machine Image:](#oncommand-cloud-manager-for-aws-machine-image)
    - [ONTAP Cloud for AWS:](#ontap-cloud-for-aws)
    - [Cloud Manager Admin credentials for AWS:](#cloud-manager-admin-credentials-for-aws)
- [Node Attributes](#node-attributes)
  - [OnCommand Cloud Manager](#oncommand-cloud-manager)
  - [ONTAP Cloud](#ontap-cloud)
- [Custom Resource](#custom-resource)
  - [netapp_ontap_cloud_occm](#netapp_ontap_cloud_occm)
    - [Action :setup](#action-setup)
      - [Properties:](#properties)
        - [Server Configuration properties](#server-configuration-properties)
        - [User Management properties](#user-management-properties)
        - [Tenant properties](#tenant-properties)
        - [AWS properties](#aws-properties)
      - [Examples:](#examples)
        - [Configure a minimal installation of Cloud Manager without AWS credentials](#configure-a-minimal-installation-of-cloud-manager-without-aws-credentials)
  - [netapp_ontap_cloud_ontap_aws](#netapp_ontap_cloud_ontap_aws)
    - [Action :create](#action-create)
      - [Properties:](#properties-1)
        - [OnCommand Cloud Manager properties](#oncommand-cloud-manager-properties)
        - [Amazon Web Services properties](#amazon-web-services-properties)
        - [ONTAP Instance properties](#ontap-instance-properties)
        - [AWS properties](#aws-properties-1)
        - [CHEF properties](#chef-properties)
      - [Examples:](#examples-1)
        - [Deploy ONTAP Cloud instance and wait for launch to complete](#deploy-ontap-cloud-instance-and-wait-for-launch-to-complete)
  - [netapp_ontap_cloud_ndvp](#netapp_ontap_cloud_ndvp)
    - [Action :install (default)](#action-install-default)
    - [Action :config](#action-config)
    - [Action :delete](#action-delete)
      - [Properties:](#properties-2)
        - [OnCommand Cloud Manager properties](#oncommand-cloud-manager-properties-1)
        - [ONTAP Instance properties](#ontap-instance-properties-1)
        - [NetApp Docker Volume  properties](#netapp-docker-volume--properties)
      - [Examples:](#examples-2)
        - [Configure and Install the NetApp Docker Volume Plug-in with a default configuration file.](#configure-and-install-the-netapp-docker-volume-plug-in-with-a-default-configuration-file)
- [Recipes](#recipes)
  - [default](#default)
  - [occm_install](#occm_install)
  - [occm_setup](#occm_setup)
  - [ontap_cloud_aws_standalone](#ontap_cloud_aws_standalone)
  - [ontap_cloud_aws_standalone_delete](#ontap_cloud_aws_standalone_delete)
  - [docker_volume_plugin](#docker_volume_plugin)
- [Upload to Chef Server](#upload-to-chef-server)
- [Matchers/Helpers](#matchershelpers)
  - [Matchers](#matchers)
- [Cookbook Testing](#cookbook-testing)
  - [OnCommand Cloud Manager software](#oncommand-cloud-manager-software)
  - [Before you begin](#before-you-begin)
  - [Data_bags for Test-Kitchen](#data_bags-for-test-kitchen)
  - [Rakefile and Tasks](#rakefile-and-tasks)
  - [Chefspec and Test-Kitchen](#chefspec-and-test-kitchen)
  - [Compliance Profile](#compliance-profile)
- [Contribute](#contribute)
- [License & Authors](#license-&-authors)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Requirements

### Platforms
- Centos 7.1 and 7.2
- Redhat 7.1 and 7.2
- [Official AWS Machine Image (Ami)](https://aws.amazon.com/marketplace/pp/B018REK8QG)

### Chef
- Chef 12.5+

### Cookbooks
- There are currently no outside dependencies

### Data bags

- Optional Data_bag `occm` and item `aws`.  Handles AWS keys to be passed during initial OCCM setup.
```
{
  "id": "aws",
  "aws_access_key": "AKIA################",
  "aws_secret_key": "29######################################"
}
```
- Required Data_bag `occm` and item `admin_credentials`.  Handles OCCM Admin credentials used in recipes.
```
{
  "id": "admin_credentials",
  "email_address": "test@lab.test",
  "password": "Netapp1"
}
```
- Required Data_bag `occm` and item `<ontap-cloud-name>`.  Handles ONTAP Cloud Cluster Admin credentials assigned to the controller.
```
{
  "id": "demolab",
  "svm_password": "Netapp123"
}
```

### Amazon Web Services
#### OnCommand Cloud Manager for AWS Machine Image:

This cookbook can create a local or remote OnCommand Cloud Manager host.  If deployed in Amazon, we advise using the existing NetApp AWS Marketplace Machine Image (OCCM-AMI).  Visit the [official page for OnCommand Cloud Manager in the AWS Marketplace](https://aws.amazon.com/marketplace/pp/B018REK8QG]) for more information.

#### ONTAP Cloud for AWS:

This cookbook will need access to your Amazon Web Services account and details contained therein.  As part of the process, we will deploy ONTAP Cloud for AWS systems.  Before this can happen, you must accept the official NetApp ONTAP Cloud Amazon Machine Image (ONTAP-AMI) end user license agreement.  Visit the [official page for ONTAP Cloud in the AWS Marketplace](https://aws.amazon.com/marketplace/pp/B011KEZ734]) for more information.

#### Cloud Manager Admin credentials for AWS:

The OnCommand Cloud Manager system requires that credentials exist either for the individual user or, if running in AWS, an IAM Instance Role for the EC2 server with the correct policy.  [Review the official IAM policy requirements for OCCM](https://s3.amazonaws.com/occm-sample-policies/Policy_for_Cloud_Manager_3.2.json)


## Node Attributes
### OnCommand Cloud Manager
- `node['occm']['server']` - String.  Hostname or IP address of the OnCommand Cloud Manager system.  Default is `localhost`.
- `node['occm']['company_name']` - String.  Company name to which this installation should be registered.
- `node['occm']['tenant_name']` - String.  The tenant name in OCCM.  Default value is 'Default Tenant'

- `node['occm']['installer']` - URL.  Full HTTP path to the installation media.  Default is nil.  Not required except when performing a local installation or not using the [official Cloud Instance](#platforms)
- `node['occm']['install_pkg']` - Boolean.  Determines if the setup recipe should also install OCCM.  Default is false

### ONTAP Cloud
- `node['ontap_cloud']['ontap']['standalone']['name']` - String.  ONTAP Cloud system name.<br>**Value must match regex: [/^[A-Za-z][A-Za-z0-9_]{2,39}$/]**
- `node['ontap_cloud']['ontap']['standalone']['ebs_type']` - String. AWS EBS Volume type.  Supported values are ['gp2', 'st1', 'sc1'].  Default value is 'gp2'
- `node['ontap_cloud']['ontap']['standalone']['size']` - String. Size of the EBS Volume. Supported values are ['100GB', '500GB', '1TB', '2TB', '4TB', '8TB'].  Default value is '1TB'
- `node['ontap_cloud']['ontap']['standalone']['instance_type']` - String. ONTAP Cloud for AWS instance type.  Default value is 'm4.xlarge'.
- `node['ontap_cloud']['ontap']['standalone']['license_type']` - String. ONTAP Cloud license type.  Supported values are ['cot-explore-paygo', 'cot-standard-paygo', 'cot-premium-paygo']. Default value is 'cot-explore-paygo'

- `node['ontap_cloud']['aws']['region']` - String.  Required for AWS deployments.  <br> **Value must match regex:[/^[a-z]{2}-[a-z]+-\d$/]**

- `node['ontap_cloud']['aws']['vpc_id']` - String.  Required for AWS deployments.  <br> **Value must match regex: [/^vpc-[a-zA-Z0-9]{8}$/]**

- `node['ontap_cloud']['aws']['subnet_id']` - String. Required for AWS deployments.  <br> **Value must match regex: [/^subnet-[a-zA-Z0-9]{8}$/]**

## Custom Resource

### netapp_ontap_cloud_occm
Manages an existing OnCommand Cloud Manager setup
#### Action :setup
---
Configures OnCommand Cloud Manager first-time setup

##### Properties:
_NOTE: properties in bold are required_

###### Server Configuration properties

| Property | Type | Description |
| ------------- |-------------|-------------|
| **`server`** | String | Hostname or IP address of the OnCommand Cloud Manager system |
| **`email_address`** | String | Email address assigned to the newly created user for first-time setup |
| **`password`** | String | Password for the user used in the setup |
| **`company`** | String | Company name to which this installation should be registered |
| `site` | String | Site or Datacenter to where the OnCommand Cloud Manager system is deployed |

###### User Management properties

| Property | Type | Description |
| ------------- |-------------|-------------|
| `first_name` | String | First name of the User to manage.  Default is 'occm' |
| `last_name` | String | Last name of the User to manage.  Default is 'admin' |
| `role_name` | String | Sets the access level of the user.  Valid options ['Cloud Manager Admin', 'Tenant Admin', 'Working Environment Admin']  Default is 'Cloud Manager Admin' |

###### Tenant properties

| Property | Type | Description |
| ------------- |-------------|-------------|
| **`tenant_name`** | String | Name of the OnCommand Cloud Manager Tenant. |
| `description` | String | Optional long description for the OCCM Tenant. |
| `cost_center` | String | Optional cost-center identifier for the OCCM Tenant. |

###### AWS properties

| Property | Type | Description |
| ------------- |-------------|-------------|
| `aws_key` | String | Used to add AWS credentials to the newly created user.  If none supplied, then provisioning of ONTAP Cloud systems will be disabled. Sensitve and will not print in the logs.<br><br>_**NOTE: When running in AWS, an instance role can be assigned to the Cloud Manager system and these credentials can be skipped.**_|
| `aws_secret` | String | Used to add AWS credentials to the newly created user.  If none supplied, then provisioning of ONTAP Cloud systems will be disabled. Sensitve and will not print in the logs.<br><br>_**NOTE: When running in AWS, an instance role can be assigned to the Cloud Manager system and these credentials can be skipped.**_|

##### Examples:
###### Configure a minimal installation of Cloud Manager without AWS credentials
```ruby
netapp_ontap_cloud_occm 'Setup Cloud Manager' do
  server 'localhost'
  email_address 'occm@lab.test'
  password 'Netapp1'
  company 'My Company'
  tenant_name 'Default Tenant'
  action :setup
end

```

### netapp_ontap_cloud_ontap_aws
Deploys and configures ONTAP Cloud in AWS systems
#### Action :create
---
Deploys an ONTAP Cloud for AWS system

##### Properties:
_NOTE: properties in bold are required_

###### OnCommand Cloud Manager properties

| Property | Type | Description |
| ------------- |-------------|-------------|
| **`server`** | String | Hostname or IP address of the OnCommand Cloud Manager system |
| **`occm_user`** | String | Email address of the OCCM user |
| **`occm_password`** | String | Password for the user supplied |
| **`ontap_name`** | String | **NAME Property.**  The name of the ONTAP Cloud system to be created.  This is the name property for the resource block. <br><br> **Value must match regex: [/^[A-Za-z][A-Za-z0-9_]{2,39}$/]**|
| **`tenant_name`** | String | OCCM Tenant name to which the user has access and the new ONTAP Cloud will be deployed |

###### Amazon Web Services properties

| Property | Type | Description |
| ------------- |-------------|-------------|
| **`region`** | String | The region to which the OCCM server can communicate and the new ONTAP Cloud should be deployed.<br><br> **Value must match regex:[/^[a-z]{2}-[a-z]+-\d$/]** |
| **`vpc_id`** | String | The AWS VPC to which the OCCM server can communicate and the new ONTAP Cloud should be deployed.<br><br> **Value must match regex: [/^vpc-[a-zA-Z0-9]{8}$/]** |
| **`subnet_id`** | String | The subnet in the VPC to which the OCCM server can communicate and the new ONTAP Cloud should be deployed.<br><br> **Value must match regex: [/^subnet-[a-zA-Z0-9]{8}$/]** |
| `aws_tags` | String | Future Property |

###### ONTAP Instance properties

| Property | Type | Description |
| ------------- |-------------|-------------|
| **`instance_type`** | String | AWS Instance Type.  Default value is 'm4.xlarge'. |
| **`license_type`** | String | NetApp license type.  Supported values are ['cot-explore-paygo', 'cot-standard-paygo', 'cot-premium-paygo'].  Devault value is 'cot-explore-paygo' |
| `ontap_version` | String | Sets the version of ONTAP to deploy.  Default is 'latest' |
| `use_latest` | Booelean | Should be set to `true` if ontap_version is `latest`.  Default is true |
| `platform_license` | String | Future Property |
| `ebs_volume_type` | String | Sets the AWS EBS volume type for new storage attached to the ONTAP Cloud system. Supported values are 'gp2','st1','sc1'.  Default value is 'gp2'|
| `ebs_volume_size` | String | Configures the EBS volume size.  Supported values are '100GB','500GB','1TB','2TB','4TB','8TB'.  Default value is '1TB' |
| `bypass_snapshot` | Booelean | Skips the default action by OCCM to create an EBS snapshot on first instantiation of ONTAP Cloud. |
| `data_encryption_type` | String | Future Property.  Supported values are 'NONE', 'AWS', 'ONTAP'.  Default value is 'NONE' |
| `clusterKeyPairName` | String | Future Property |
| **`svm_password`** | String | Sets the password on the cluster admin account for the ONTAP Cloud system.  Sensitve and will not print in the logs. |

###### AWS properties

| Property | Type | Description |
| ------------- |-------------|-------------|
| `aws_key` | String | Used to add AWS credentials to the newly created user.  If none supplied, then provisioning of ONTAP Cloud systems will be disabled.<br><br>_**NOTE: When running in AWS, an instance role can be assigned to the Cloud Manager system and these credentials can be skipped.**_|
| `aws_secret` | String | Used to add AWS credentials to the newly created user.  If none supplied, then provisioning of ONTAP Cloud systems will be disabled.<br><br>_**NOTE: When running in AWS, an instance role can be assigned to the Cloud Manager system and these credentials can be skipped.**_|

###### CHEF properties

| Property | Type | Description |
| ------------- |-------------|-------------|
| `wait_execution` | Boolean | This can be used with resource actions like `:create` to force the process to wait until after the exeuction of the job before moving on.  Default is false |


##### Examples:
###### Deploy ONTAP Cloud instance and wait for launch to complete
```ruby
netapp_ontap_cloud_ontap_aws 'myontap' do
  server 'localhost'
  occm_user 'occm@lab.test'
  occm_password 'Netapp1'
  tenant_name 'Default Tenant'
  svm_password 'Netapp123'
  region 'us-east-1'
  vpc_id 'vpc-12345678'
  subnet_id 'subnet-1a2b3c4d'
  ebs_volume_size '100GB'
  bypass_snapshot true
  wait_execution true
  action :create
end

```

### netapp_ontap_cloud_ndvp
Deploys and configures the NetApp Docker Volume Plug-in and creates a connection to the ONTAP Cloud system selected.

_NOTE: Requires that the host already installs Docker Engine 17.03+_
#### Action :install (default)
---
Installs the NFS client package for the host and installs the current version of the NetApp Docker Volume Plug-in

#### Action :config
---
Determines the configuration details of the selected ONTAP Cloud system and creates the required configuration file for the ONTAP Cloud system based on details from the OnCommand Cloud Manager system.

#### Action :delete
---
Future action and currently not implemented.

##### Properties:
_NOTE: properties in bold are required_


property :server, String, required: true
property :occm_user, String, required: true
property :occm_password, String, required: true, identity: false, sensitive: true
property :ontap_name, String, required: true, name_property: true # Regex is evaluated in the action
property :tenant_name, String, required: true
property :svm_password, String, required: true, identity: false, sensitive: true

###### OnCommand Cloud Manager properties

| Property | Type | Description |
| ------------- |-------------|-------------|
| **`server`** | String | Hostname or IP address of the OnCommand Cloud Manager system |
| **`occm_user`** | String | Email address of the OCCM user |
| **`occm_password`** | String | Password for the user supplied |
| **`ontap_name`** | String | **NAME Property.**  The name of the ONTAP Cloud system to be used.  This system must already exist and be visible to the selected OCCM server.  This is the name property for the resource block. <br><br> **Value must match regex: [/^[A-Za-z][A-Za-z0-9_]{2,39}$/]**|
| **`tenant_name`** | String | OCCM Tenant name to which the user has access and the new ONTAP Cloud will be deployed |

###### ONTAP Instance properties

| Property | Type | Description |
| ------------- |-------------|-------------|
| **`svm_password`** | String | Sets the password on the cluster admin account for the ONTAP Cloud system.  Sensitve and will not print in the logs. |

###### NetApp Docker Volume  properties

| Property | Type | Description |
| ------------- |-------------|-------------|
| **`ndvp_config`** | String | Name for the configuration file and will be saved to `/etc/netappdvp`.  Default value is 'config.json'.|


##### Examples:
###### Configure and Install the NetApp Docker Volume Plug-in with a default configuration file.
```ruby
netapp_ontap_cloud_ndvp 'myontap' do
  server 'localhost'
  occm_user 'occm@lab.test'
  occm_password 'Netapp1'
  tenant_name 'Default Tenant'
  svm_password 'Netapp123'
  action [:config, :install]
end

```

## Recipes
### default

This is an empty recipe and should _not_ be used

### occm_install

Installs NetApp OnCommand Cloud Manager application.  This recipe does not perform the setup or configuration

### occm_setup

Installs and configures NetApp OnCommand Cloud Manager service using the default configuration and setup.  Includes the recipe::occm_install.

### ontap_cloud_aws_standalone

Configures NetApp OnCommand Cloud Manager service using the default configuration and setup.  Deploys a new ONTAP Cloud for AWS system in a standalone configuratione.

### ontap_cloud_aws_standalone_delete

Removes an existing standalone ONTAP Cloud for AWS system.

### docker_volume_plugin

Installs and configures NFS and the NetApp Docker Volume Plug-in on the host to which this recipe is run.

_NOTE: Requires that the host already installs Docker Engine 17.03+_

## Upload to Chef Server
This cookbook should be included in each organization of your CHEF environment.  When importing, leverage Berkshelf:

`berks upload`

_NOTE:_ use the --no-ssl-verify switch if the CHEF server in question has a self-signed SSL certificate.

`berks upload --no-ssl-verify`


## Matchers/Helpers

### Matchers
_Note: Matchers should always be created in `libraries/matchers.rb` and used for validating calls to LWRP_

**Tests the LWRP (netapp_ontap_cloud_occm) with an action**
* `setup_netapp_ontap_cloud_occm(resource_name)`

**Tests the LWRP (netapp_ontap_cloud_ontap_aws) with an action**
* `create_netapp_ontap_cloud_ontap_aws(resource_name)`
* `delete_netapp_ontap_cloud_ontap_aws(resource_name)`

**Tests the LWRP (netapp_ontap_cloud_ndvp) with an action**
* `install_netapp_ontap_cloud_ndvp(resource_name)`
* `config_netapp_ontap_cloud_ndvp(resource_name)`

## Cookbook Testing

### OnCommand Cloud Manager software
If you are testing locally, the installation media needs to be downloaded directly from NetApp's software download site.  The media can be placed in `files/default` in this cookbook or hosted on a webserver.  If hosted on the webserver, then the kitchen attribute `installer` needs to be set with the link.

_Note: If Cloud Manager is provisioned locally, your OCCM server needs network connectivity to the cloud network where the ONTAP system is deployed.  The process will run but ultimately fail to launch ONTAP Cloud without this connectivity._

### Before you begin
Setup your testing and ensure all dependencies are installed.  Open a terminal windows and execute:

```ruby
gem install bundler
bundle install
berks install
```

### Data_bags for Test-Kitchen

This cookbook requires the use of a data_bag for setting certain values.  Local JSON version need to be stored in the directory structure as indicated below:

```
├── chef-repo/
│   ├── cookbooks
│   │   ├── netapp_ontap_cloud_occm
│   │   │   ├── .kitchen.yml
│   ├── data_bags
│   │   ├── data_bag_name
│   │   │   ├── data_bag_item.json

```

**Note**: Storing local testing versions of the data_bags at the root of your repo is considered best practice.  This ensures that you only need to maintain a single copy while protecting the cookbook from being accientally committed with the data_bag.  However, if you must change this location, then update the following key in the .kitchen.yml file.

```
data_bags_path: "../../data_bags/"
```

### Rakefile and Tasks
This repo includes a **Rakefile** for common tasks

| Task Command | Description |
| ------------- |-------------|
| **rake** | Run Style, Foodcritic, Maintainers, and Unit Tests |
| **rake style** | Run all style checks |
| **rake style:chef** | Run Chef style checks |
| **rake style:ruby** | Run Ruby style checks |
| **rake style:ruby:auto_correct** | Auto-correct RuboCop offenses |
| **rake unit** | Run ChefSpec examples |
| **rake integration** | Run all kitchen suites |
| **rake integration:kitchen:occm-centos-72** | Run occm-centos-72 test instance |
| **rake integration:kitchen:occm-web-install-72** | Run occm-web-install-72 test instance |
| **rake integration:kitchen:ontap-aws-centos-72** | Run ontap-aws-centos-72 test instance |
| **rake maintainers:generate** | Generate MarkDown version of MAINTAINERS file |

### Chefspec and Test-Kitchen

1. `bundle install`: Installs and pulls all ruby gems dependencies from the Gemfile.

2. `berks install`: Installs all cookbook dependencies based on the [Berksfile](Berksfile) and the [metadata.rb](metadata.rb)

3. `rake`: This will run all of the local tests - syntax, lint, unit, and maintainers file.
4. `rake integration`: This will run all of the kitchen tests

### Compliance Profile
Included in this cookbook is a set of Inspec profile tests used for supported platforms in Test-Kitchen.  These profiles can also be loaded into Chef Compliance to ensure on-going validation.  The Control files are located at `test/inspec/suite_name`

## Contribute
 - Fork it
 - Create your feature branch (git checkout -b my-new-feature)
 - Commit your changes (git commit -am 'Add some feature')
 - Push to the branch (git push origin my-new-feature)
 - Create new Pull Request

## License & Authors

**Author:** Jeremy Goodrum ([jeremy@exospheredata.com](mailto:jeremy@exospheredata.com))

**Copyright:** 2017 Exosphere Data, LLC

```text
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
