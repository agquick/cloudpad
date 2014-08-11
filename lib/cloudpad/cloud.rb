require 'yaml'
require 'fileutils'

module Cloudpad

  class Cloud

    def initialize(env)
      @env = env
      @hosts = []
      @containers = []
    end

    def hosts
      @hosts
    end

    def containers
      @containers
    end

    def update
      @hosts = []
      @containers = []
      case @env.fetch(:cloud_provider)
      when :boxchief
        data = get_boxchief_cloud
      else
        data = get_cached_cloud
      end
      data[:containers] ||= []
      @hosts = data[:hosts]
      @containers = data[:containers]
      update_cache
    end

    def cache_file_path
      File.join(cloud_dir_path, "#{@env.fetch(:stage)}.yml")
    end

    def cloud_dir_path
      File.join(Dir.pwd, "config", "cloud")
    end

    def update_cache
      if !File.directory?(cloud_dir_path)
        FileUtils.mkdir_p(cloud_dir_path)
      end

      File.open(cache_file_path, "w") do |f|
        f.write({"hosts" => @hosts.collect(&:data), "containers" => @containers.collect(&:data)}.to_yaml)
      end
    end

    def get_cached_cloud
      return {hosts: [], containers: []} if !File.exists?(cache_file_path)
      data = YAML.load_file(cache_file_path)
      #puts data
      data["hosts"] ||= []
      data["containers"] ||= []
      return {
        hosts: data["hosts"].collect{|h| Host.new(h)},
        containers: data["containers"].collect{|h| Container.new(h)}
      }
    end

    def get_boxchief_cloud
      conn = Faraday.new(url: "http://boxchief.com") do |f|
        #f.response :logger
        f.adapter Faraday.default_adapter
      end

      ret = conn.get "/api/servers/list", {app_token: @env.fetch(:boxchief_app_token)}
      #puts ret.inspect
      #puts "BODY = #{ret.body}"
      resp = JSON.parse(ret.body)
      if resp["success"] == false
        raise "Boxchief Error: #{resp["error"]}"
      end

      hosts = resp["data"].collect do |sd|
        host = Host.new
        host[:name] = sd["hostname"]
        host[:external_ip] = sd["ip"]
        host[:roles] = sd["roles"]
        host[:cloud_provider] = "boxchief"
        host
      end
      return {hosts: servers}
    end

  end

  ## CLOUDELEMENT
  class CloudElement

    def initialize(opts)
      @data = opts.stringify_keys
      #puts self.methods.inspect
      #puts "#{self.respond_to?(:roles)} - #{@data["roles"]}"
    end

    def data
      @data.to_hash
    end

    def [](field)
      @data[field.to_s]
    end

    def []=(field, val)
      @data[field.to_s] = val
    end

    def method_missing(name, *args)
      if name.to_s.ends_with?("=")
        @data[name.to_s] = args[0]
      else
        @data[name.to_s]
      end
    end

  end

  class Host < CloudElement

    def internal_ip
      self["internal_ip"] || self["external_ip"]
    end

    def roles
      (@data["roles"] || []).collect(&:to_sym)
    end

    def has_id?(val)
      val = [val] unless val.is_a?(Array)
      ([internal_ip, external_ip, name] & val).length > 0
    end

  end

  class Container

    attr_accessor :host, :name, :instance, :type, :ports, :image_options, :app_key, :image, :state, :status, :ip_address

    def self.prepare(params, img_opts, host)
      ct = self.new
      ct.type = params[:type]
      ct.instance = params[:instance]
      ct.app_key = params[:app_key]
      ct.image = "#{img_opts[:name]}:latest"
      ct.host = host
      ct.image_options = img_opts
      ct.state = :ready
      return ct
    end

    def name
      @name ||= "#{app_key}.#{type}.#{instance}"
    end

    def ports
      @ports ||= begin
        # parse ports
        pts = []
        image_options[:ports].each do |if_name, po|
          host_port = po[:hport] || po[:cport]
          ctnr_port = po[:cport]
          unless po[:no_range] == true
            host_port += instance
          end
          pts << {name: if_name, container: ctnr_port, host: host_port}
        end unless image_options[:ports].nil?
        pts
      end
    end

    def env_data
      ret = {
        "name" => name,
        "type" => type,
        "instance" => instance,
        "image" => image,
        "host" => host.name,
        "host_ip" => host.internal_ip,
        "ports" => ports.collect{|p| p[:name].to_s}.join(",")

      }
      ports.each do |p|
        ret["port_#{p[:name]}_c"] = p[:container]
        ret["port_#{p[:name]}_h"] = p[:host]
      end
      return ret
    end

    def run_args(opts)
      cname = self.name
      cimg = "#{opts[:registry]}/#{self.image}"
      fname = "--name #{cname}"
      fports = self.ports.collect { |port|
        cp = port[:container]
        hp = port[:host]
        "-p #{hp}:#{cp}"
      }.join(" ")
      fenv = self.env_data.collect do |key, val|
        "--env CNTR_#{key.upcase}=#{val}"
      end.join(" ")
      return "#{fname} #{fports} #{fenv} #{cimg}"
    end

  end

end
