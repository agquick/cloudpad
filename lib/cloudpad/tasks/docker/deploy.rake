namespace :docker do

  ### ADD
  desc "Add docker containers on most available host"
  task :add do
    type = ENV['type'].to_sym
    count = ENV['count'] ? ENV['count'].to_i : 1
    filt = ENV['chost'] ? ENV['chost'].split(',') : nil
    Cloudpad::Docker.add_container(type: type, count: count, host_filter: filt)
  end


  ### REMOVE
  desc "Stop and remove all containers running on hosts for this application"
  task :remove do
    name = ENV['name']
    type = ENV['type']
    Cloudpad::Docker.remove_container(name: name, type: type)
  end


  ### UPDATE
  desc "Update running containers"
  task :update do
    tf = ENV['type'].split(',') if ENV['type']
    cts = fetch(:running_containers).select {|c|
      tf.nil? || tf.include?(c.type.to_s)
    }

    on roles(:host) do |server|
      host = server.properties.source
      cts.each do |ct|
        if ct.host == host
          # stop container
          execute ct.stop_command(env)
          execute ct.start_command(env)
        end
      end
    end
    Rake::Task["docker:check_running"].execute
  end

  ### DEPLOY
  task :deploy do
    invoke "docker:build"
    invoke "docker:maintain"
  end


  ### CHECK_RUNNING
  desc "Check running containers"
  task :check_running do
    Cloudpad::Docker.check_running(do_print: true)
  end

  ### CHECK_IMAGES
  desc "Check launcher images"
  task :check_launcher_images do
    Cloudpad::Docker.check_launcher_images
  end

  ### LIST
  task :list do
    invoke "docker:check_running"
  end

  ### UPDATE_HOST_IMAGES
  desc "Update host images from registry"
  task :update_host_images do
    reg = fetch(:registry_url)
    app_key = fetch(:app_key)
    images = fetch(:images)
    insecure = fetch(:insecure_registry)
    on roles(:host) do
      filtered_image_types.each do |type|
        img_opts = images[type.to_sym]
        execute "sudo docker pull #{reg}/#{img_opts[:name_with_tag]}"
      end
    end
  end

  ### SSH
  task :ssh do
    name = ENV['name']
    ci = container_with_name(name)
    server = server_running_container(ci)

    on server do |host|
      execute "rm -f /tmp/container.key"
      upload!(File.join(context_path, 'keys', 'container.key'), "/tmp/container.key")
      execute "chmod 400 /tmp/container.key"
      #execute "ssh -i /tmp/container_key root@#{ci.ip_address}"
    end
    sh "ssh -t #{server.user}@#{server.hostname} ssh -t -i /tmp/container.key -o \\\"StrictHostKeyChecking no\\\" root@#{ci.ip_address}"
  end

  ### SHELL
  task :shell do
    name = ENV['name']
    ci = container_with_name(name)
    if ci.nil?
      puts "Container #{name} not found.".red
      next
    end
    server = server_running_container(ci)
    sh "ssh -t #{server.user}@#{server.hostname} sudo docker exec -i -t #{name} /bin/bash"
  end

  ### LOGS
  task :logs do
    name = ENV['name']
    ci = container_with_name(name)
    if ci.nil?
      puts "Container #{name} not found.".red
      next
    end
    server = server_running_container(ci)
    log_args = fetch(:docker_log_args) || ""
    sh "ssh -t #{server.user}@#{server.hostname} sudo docker logs #{log_args} #{name}"
  end

  ### MAINTAIN
  task :maintain do
    noop = parse_env("noop")
    changes = Cloudpad::Docker.compute_container_changes
    puts "#{changes.length} container changes needed.".yellow
    changes.each do |c|
      s = c[:spec]
      str = "- #{c[:action].upcase} #{s[:name]} on #{s[:hosts] || s[:host]}"
      str = (c[:action].to_sym == :delete) ? str.red : str.green
      puts str
    end
    if changes.length > 0 && !noop
      puts "Executing changes...".yellow
      invoke "docker:update_host_images"
      changes.each do |c|
        Cloudpad::Docker.execute_container_change(c)
      end
      Cloudpad::Docker.check_running
    end
  end


end

before "docker:add", "docker:update_host_images"
before "docker:add", "docker:check_running"

before "docker:remove", "docker:check_running"

before "docker:update", "docker:check_running"
before "docker:update", "docker:update_host_images"

before "docker:ssh", "docker:check_running"
before "docker:shell", "docker:check_running"
before "docker:logs", "docker:check_running"

before "docker:maintain", "docker:check_launcher_images"
before "docker:maintain", "docker:check_running"

before "docker:update_host_images", "hosts:clean_images"
