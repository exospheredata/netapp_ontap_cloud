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
- [Attributes](#attributes)
  - [OnCommand Cloud Manager](#oncommand-cloud-manager)
- [Resource/Provider](#resourceprovider)
  - [netapp_ontap_cloud_occm](#netapp_ontap_cloud_occm)
    - [Action :setup](#action-setup)
      - [Properties:](#properties)
      - [Examples:](#examples)
- [Usage](#usage)
  - [default](#default)
  - [occm_install recipe](#occm_install-recipe)
- [Upload to Chef Server](#upload-to-chef-server)
- [Matchers/Helpers](#matchershelpers)
  - [Matchers](#matchers)
- [Cookbook Testing](#cookbook-testing)
  - [Before you begin](#before-you-begin)
  - [Data_bags for Test-Kitchen](#data_bags-for-test-kitchen)
  - [Rakefile and Tasks](#rakefile-and-tasks)
  - [Chefspec and Test-Kitchen](#chefspec-and-test-kitchen)
  - [Compliance Profile](#compliance-profile)
- [Contribute](#contribute)
- [License and Author](#license-and-author)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Requirements

### Platforms
- Centos 7.1 and 7.2
- Redhat 7.1 and 7.2

### Chef

- Chef 12.5+

### Cookbooks

- There are currently no outside dependencies

## Attributes
### OnCommand Cloud Manager
- `node['occm']['server']` - String.  Hostname or IP address of the OnCommand Cloud Manager system.  Default is `localhost`.
- `node['occm']['user']['email_address']` - String.  Email address of the new user used in the setup.  Default `role` is `Cloud Manage Admin`.
- `node['occm']['user']['password']` - String.  Password for the user used in the setup.
- `node['occm']['company_name']` - String.  Company name to which this installation should be registered.


## Resource/Provider

### netapp_ontap_cloud_occm
Manages an existing OnCommand Cloud Manager setup
#### Action :setup
---
Configures OnCommand Cloud Manager first-time setup

##### Properties:
_NOTE: properties in bold are required_
* **`server`** - Hostname or IP address of the OnCommand Cloud Manager system.
* **`email_address`** - Email address assigned to the newly created user for first-time setup.
* **`password`** - Password for the user used in the setup.
* **`company`** - Company name to which this installation should be registered.
* `aws_key` - Used to add AWS credentials to the newly created user.  If none supplied, then provisioning of ONTAP Cloud systems will be disabled.  _NOTE: When running in AWS, an instance role can be assigned to the Cloud Manager system and these credentials can be skipped._
* `aws_secret` - Used to add AWS credentials to the newly created user.  If none supplied, then provisioning of ONTAP Cloud systems will be disabled.  _NOTE: When running in AWS, an instance role can be assigned to the Cloud Manager system and these credentials can be skipped._

##### Examples:
```ruby
# Configure a minimal installation of Cloud Manager without AWS credentials
netapp_ontap_cloud_occm 'Setup Cloud Manager' do
  server 'localhost'
  email_address 'occm@lab.test'
  password 'Netapp1'
  company 'My Company'
  action :setup
end

```

## Usage
### default

This is an empty recipe and should _not_ be used

### occm_install recipe

Installs and configures NetApp OnCommand Cloud Manager service using the default configuration and setup


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


## Cookbook Testing

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
| **rake integration:kitchen:occm-centos-72** | Run catalog-windows-2012r2 test instance |
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

## License and Author

- Author:: Jeremy Goodrum ([jeremy@exospheredata.com](mailto:jeremy@exospheredata.com))

```text
The MIT License

Copyright (c) 2016 Exosphere Data, LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```
