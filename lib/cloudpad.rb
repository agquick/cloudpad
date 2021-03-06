require 'colored'
require "cloudpad/version"
require "cloudpad/task_utils"
require "cloudpad/cloud"
require "cloudpad/docker"
require "cloudpad/kube"
require "active_support/core_ext"

module Cloudpad

  def self.gem_context_path
    File.expand_path("../../context", __FILE__)
  end

  def self.context=(ctx)
    @context = ctx
  end

  def self.context
    return @context
  end

  class Context
    def initialize(c)
      @context = c
    end
    def method_missing(name, *args, &block)
      @context.instance_eval {|obj|
        self.send name, *args, &block
      }
    end
  end

  module Puppet

    # install puppet
    def self.ensure_puppet_installed(c)
      # check if puppet already installed
      if !c.is_package_installed?("puppet") && !c.is_package_installed?("puppet-agent")
        c.info "Puppet not installed, installing..."
        c.execute "wget -O /tmp/puppetlabs.deb http://apt.puppetlabs.com/puppetlabs-release-pc1-`lsb_release -cs`.deb"
        c.execute "sudo dpkg -i /tmp/puppetlabs.deb"
        c.execute "sudo apt-get update"
        c.execute "sudo apt-get -y install puppet-agent"
        c.info "Puppet installation complete."
      else
        c.info "Puppet installed."
      end
    end

    def self.ensure_puppet_modules_installed(c)
      module_config = c.fetch(:puppet_modules)
      # get currently installed modules
      installed_modules = {}
      Dir.glob(File.join(c.puppet_path, "modules", "*", "metadata.json")).each {|fp|
        data = JSON.parse(File.read(fp))
        installed_modules[data["name"]] = data
      }
      mod_dir = File.join c.puppet_path, "modules"
      module_config.each do |mod_name, ver|
        next if !installed_modules[mod_name].nil?
        cmd = "sudo puppet module install #{mod_name} --modulepath #{mod_dir} --version #{ver}"
        c.execute cmd
      end
    end

    def self.puppet_apply(c, opts={})
      pbp = c.remote_file_exists?("/opt/puppetlabs/bin/puppet") ? "/opt/puppetlabs/bin/puppet" : "/usr/bin/puppet"
      mp = opts[:module_path] || "/etc/puppet/modules"
      mf = opts[:manifest] || "/etc/puppet/manifests/site.pp"
      cmd = "sudo #{pbp} apply --logdest syslog --modulepath #{mp} --verbose #{mf}"
      c.execute cmd
    end

  end

end

extend Cloudpad::TaskUtils

load File.expand_path("../cloudpad/tasks/cloudpad.rake", __FILE__)
load File.expand_path("../cloudpad/tasks/app.rake", __FILE__)
load File.expand_path("../cloudpad/tasks/launcher.rake", __FILE__)
load File.expand_path("../cloudpad/tasks/nodes.rake", __FILE__)
load File.expand_path("../cloudpad/tasks/hosts.rake", __FILE__)
load File.expand_path("../cloudpad/tasks/docker.rake", __FILE__)
load File.expand_path("../cloudpad/tasks/kube.rake", __FILE__)

Cloudpad.context = Cloudpad::Context.new(self)
