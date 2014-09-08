# Cloudpad

> Cloudpad is a tool to consolidate commands for the building and deployment of Docker containers.

Cloudpad is designed to be used in a repository strictly responsible for the deployment of code to a cluster of CoreOS or docker-capable machines. It will take you from source-controlled code to running containers across multiple hosts, while abstracting and reducing reduntant tasks.

When deploying containers with Cloudpad, you must complete the following steps:

1. Identify the container types that are going to be deployed
2. Define the configuration for each container type (including it's Dockerfile and context)
3. Locally update source code to the context to be deployed prior to build
4. Build container images in a fashion that best utilizes the cache
5. Push the image to a private docker registry after a successful build
6. Deploy containers to the host using Fleet, SSH, etc.
7. Seamlessly manage and update running containers (i.e. code updates)

Cloudpad provides conventions for building containers with defined roles, and allows for remote execution of certain tasks. This library is also capable of deriving the cluster hosts using a cached manifest or connecting to an API. The principle purpose of using Capistrano is to provide for the remote execution of commands in an easy manner. Many of the guides for CoreOS assume commands are ran from one of the CoreOS hosts, which may not be optimal in all cases. Also, by using Capistrano, we can execute Docker deployment commands on non-CoreOS hosts.

## Installation

Create a directory and add a Gemfile:

    $ mkdir app-deploy
    $ cd app-deploy
    $ touch Gemfile

Add this line to your application's Gemfile:

    gem 'cloudpad', :github => 'agquick/cloudpad'
    gem 'cloudpad-starter', :github => 'agquick/cloudpad-starter' # if you want cloudpad base dockerfiles, etc. This is optional.

And then execute:

    $ bundle install
    $ bundle exec cap install

Update your Capfile:

    # Capfile

    require 'capistrano/setup'
    # require 'capistrano/deploy' # comment this line out
    require 'cloudpad'
    require 'cloudpad/starter'

Now install the starter files:

    $ bundle exec cap starter:install:all

Create your configuration file for deployment:

    $ mkdir config
		$ touch config/deploy.rb

Define your hosts for your cloud:

    # config/cloud/production.yml

    ---
    hosts:
    - internal_ip: 10.6.3.20
			name: sfa-host1
			roles:
    	- host
    	provider: manual
			user: ubuntu
    	os: ubuntu
    containers: []

Now you're ready to build your configuration file.

## Configuration

Before you can execute any commands, you need to specify your configuration options. Most of your configuration can be specified in *config/deploy.rb*. Any stage-specific configuration should be specified in *config/deploy/[stage].rb*

### Global Options

```ruby
set :application, "CoolTodoList"
set :app_key, 'ctl'
```

| Param				| Expected Value	| Notes					|
| ---					| ---							| ---						|
| application	|	string					|	
| app_key			|	string					|	Short string prepended to docker container names|
| registry		|	ip address			|	IP of docker registry|
| log_level		| :debug, :info		| :info recommended					
|	images			| Hash						| Image configuration (see section)
| container_types | Hash				| Container type configuration (see section)
| repos				| Hash						| Repository configuration (see section)
| services		|	Hash						| Services configuration (see section)

### Images Options

```ruby
set :images, {
	api: {
		manifest: 'base-app',
		repos: {api: '/app'},
		available_services: ['unicorn', 'nginx'],
	},
	proxy: {
		manifest: 'base-proxy',
		services: ['haproxy']
	}
}
```

The `images` hash defines the configuration for all the docker images defined for this application.
| Param				| Expected Value	| Notes					|
| ---					| ---							| ---						|
| manifest		|	string					|	Name of manifest to use (found in manifests directory)
| repos				| Hash						| Name of repository to use (specified by symbol) with the value pointing to the path the repository should be stored to within the container
| available_services | Array		| Array of services that should be installed to the docker container, but not enabled (will be enabled selectively using the init script and environment variables)
| services		| Array						| Array of services to be installed in the container and enabled

## Usage

Running a command in cloudpad will generally take the following form:

		$ bundle exec cap <stage> <command> <option flags>
		$ bundle exec cap production docker:add type=job

### docker:build

Builds a docker container

## Tips

* It might be helpful to ignore .git subdirectories in your context. To do so, add a .dockerignore file:

		# context/.dockerignore

		src/api/.git

## Contributing

1. Fork it ( http://github.com/<my-github-username>/cloudpad/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
