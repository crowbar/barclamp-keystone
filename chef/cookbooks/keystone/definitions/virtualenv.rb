define :virtualenv, :action => :create, :owner => "root", :site => nil,  :group => "root", :mode => 0755, :wrapped => [], :packages => {}, :root => "/opt/virtualenv/" do
  path = params[:path] ? params[:path] : File.join(params[:root], params[:name]).to_s
  if params[:action] == :create
    # Create VirtualEnv
    puts "Cookbook: #{params[:name]}"
    package("python-pip")
    package("python-virtualenv")
    directory path do
      recursive true
      owner params[:owner]
      group params[:group]
      mode params[:mode]
    end
    execute "create virtualenv #{path}" do
      if params[:site] == :system
        command "virtualenv #{path} --system-site-packages"
      else
        command "virtualenv #{path} --no-site-packages"
      end
      not_if "test -f #{path}/bin/python"
    end
    params[:packages].each do |package|
      pip = "#{path}/bin/pip"
      execute "{pip} install #{package} -> #{path}" do
        command "#{pip} install \"#{package}\""
        not_if "[ `#{pip} freeze | grep #{package}` ]"
      end
    end
  elsif params[:action] == :delete
    directory path do
      action :delete
      recursive true
    end
  end
end

define :pfs_install_with_env do
  package("git")
  package("python-setuptools")

  package("python-pip")

  # prepare vurtualenv if invoked virtualenv for python
  package("python-virtualenv") if params[:virtualenv]
  current_virtualenv = params[:virtualenv] ? "virtualenv #{params[:virtualenv]} && " : ""

  current_name = params[:name]
  current_node = params[:node] || node
  current_book = params[:cookbook] || @cookbook_name
  current_attrs = current_node[current_book]

  # prepare git params
  install_path = params[:path] || "/opt/#{current_name}"
  current_git_ref = params[:reference] || current_attrs[:git_refspec]
  current_git_url ||= nil

  current_pip_cmd ||= nil

  if current_attrs[:use_gitbarclamp]
    # install from node with git-proposal or instance
    filter = nil
    if current_attrs[:git_instance]
      # instance declared, make filter
      filter = " AND git_config_environment:git-config-#{current_attrs[:git_instance]}"
    end
    # looking for a suitable node
    git_node = search(:node, "roles:git#{filter}").first
    current_git_url = "git@#{git_node[:fqdn]}:#{current_book}/#{current_name}.git"
  else
    # install from external
    current_git_url = current_attrs[:gitrepo]
  end

  # prepare pip command
  if current_attrs[:use_pip_cache]
    # use provisioner server
    provisioner = search(:node, "roles:provisioner-server").first
    proxy_addr = provisioner[:fqdn]
    proxy_port = provisioner[:provisioner][:web_port]
    current_pip_cmd = "#{current_virtualenv}pip install --index-url http://#{proxy_addr}:#{proxy_port}/files/pip_cache/simple/"
  else
    # use external server
    current_pip_cmd = "#{current_virtualenv}pip install"
  end

  puts current_pip_cmd

  # sync source with git repo
  git install_path do
    repository current_git_url
    reference current_git_ref
    action :sync
  end

  if current_attrs
    unless current_attrs[:pfs_deps].nil?

      # select apt packages
      apt_deps = current_attrs[:pfs_deps].select{|p| !p.start_with? "pip://" }

      # select pip packages without client in name
      pip_deps = current_attrs[:pfs_deps].select{|p| p.start_with?("pip://") and !p.include?("client") }.collect{|p| p.gsub(/^pip:\/\//,"") }
      # agordeev: add setuptools-git explicitly
      pip_deps.unshift("setuptools-git")

      # install apt packages
      apt_deps.each do |pkg|
        pkg_version = pkg.split("==").last
        puts "+++ #{pkg}"
        package pkg do
          version pkg_version if pkg_version != pkg
        end
      end

      # install pip packages
      pip_deps.each do |pkg|
        puts "+++ #{pkg}"
        execute "pip_install_#{pkg}" do
          command "#{current_pip_cmd} '#{pkg}'"
        end
      end

    end
  end

  unless params[:without_setup]
    # workaround for swift
    execute "remove_https_from_pip_requires_for_#{current_name}" do
      cwd install_path
      command "sed -i '/github/d' tools/pip-requires"
      only_if { current_name == "swift" }
    end
    execute "pip_install_requirements_#{current_name}" do
      cwd install_path
      command "#{current_pip_cmd} -r tools/pip-requires"
    end
    execute "setup_#{current_name}" do
      cwd install_path
      command "python setup.py develop"
      creates "#{install_path}/#{current_name == "nova_dashboard" ? "horizon":current_name}.egg-info"
    end
    # select pip packages include in name clients
    pip_deps = current_attrs[:pfs_deps].select{|p| p.include?("client") }.collect{|p| p.gsub(/^pip:\/\//,"") }
    pip_deps.each do |pkg|
      execute "pip_install_clients_#{pkg}_for_#{current_name}" do
        command "#{current_pip_cmd} '#{pkg}'"
      end
    end
  end
end
