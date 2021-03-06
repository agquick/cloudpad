# Dockerfile Instructions

The Dockerfile manifest specifies how a Docker image is to be built. For all configuration options, see the [official Dockerfile documentation](https://docs.docker.com/reference/builder/). The Dockerfile manifest is specified in the `images` configuration hash using the `manifest` option. Cloudpad looks for a manifest in the `manifests` directory with the file name of `<name>.dockerfile`.

By default, the manifest is an ERB file, meaning you can use ERB ruby tags to include Cloudpad configuration parameters. In order to reduce redundancy, Cloudpad includes a ERB-available command to run ruby commands directly within your dockerfile as it's being compiled to output dynamic commands.

## Usage

The command takes the format of:

```ruby
<%= dfi :command, [arg-1], [arg-n] %>
```

Or in a larger example:

```ruby
# vi:syntax=dockerfile

FROM phusion/baseimage:0.9.12
MAINTAINER Alan G. Graham "alan@productlab.com"

### PRIMARY PACKAGES

RUN apt-get update -q

<%= dfi :install_haproxy_153 %>

### ADDITIONAL PACKAGES

RUN apt-get install -qy git-core

<%= dfi :run, 'bin/setup_box.py', '--core' %>

### APP STUFF

ENV RACK_ENV <%= fetch(:stage) %>

### SERVICES

ADD conf/haproxy.conf.tmpl /root/conf/haproxy.conf.tmpl

### CONTAINER STUFF

ADD bin /root/bin

RUN echo "<%= container_public_key %>" >> /root/.ssh/authorized_keys

EXPOSE 80

CMD ["/sbin/my_init"]

<%= dfi :install_image_services %>
```

## Pre-defined Instructions

Cloudpad comes with a few pre-defined dockerfile instructions.

* `install_image_gemfiles` - Installs the cache Gemfiles in conf for all the specified image repos. 
* `install_image_repos` - Installs the source code for all the specified image repos.
* `install_image_services` - Installs `available_services` and activates `services`.
* `run` - [script, args*] Adds and runs the script located in the context.


## Custom Instructions

To add your own DFI helper commands, you set the global option `dockerfile_helpers` with a hash of command blocks:

```ruby
set :dockerfile_helpers, {
	install_ruby_200: lambda {
		# do logic here
		# must end with a string that adds command to manifest
		# Don't forget newlines for multiple commands
		"RUN string with command..."
	}
}
```

