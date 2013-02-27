require 'find'

define :virtualenv, :action => :create, :owner => "root", :group => "root", :mode => 0755, :wrapped => [], :packages => {} do
  virtualenv_path = params[:name]
  if params[:action] == :create
    # Create VirtualEnv
    package("python-pip")
    package("python-virtualenv")
    directory virtualenv_path do
      recursive true
      owner params[:owner]
      group params[:group]
      mode params[:mode]
    end
    execute "create virtualenv #{virtualenv_path}" do
      command "virtualenv #{virtualenv_path} --system-site-packages"
      not_if "test -f  #{virtualenv_path}/bin/python"
    end
    params[:packages].each do |package|
      pip = "#{virtualenv_path}/bin/pip"
      execute "{pip} install #{package} -> #{virtualenv_path}" do
        command "#{pip} install \"#{package}\""
        not_if "[ `#{pip} freeze | grep #{package}` ]"
      end
    end
  elsif params[:action] == :delete
    directory virtualenv_path do
      action :delete
      recursive true
    end
  end
end

define :virtualenv_wrapping, :env => nil, :to => "/usr/local/bin", :from => nil do
  if params[:env] and params[:from]
    env = File.join(params[:env],"bin")
    from = File.join(params[:from],"bin")
    to = params[:to]
    Find.find("#{from}/") do |file|
      next if FileTest.directory?(file)
      name = file.split("/").last
      template "#{to}/#{name}" do
        source "virtualenv.erb"
        mode 0755
        owner "root"
        group "root"
        variables({
          :env => "#{env}",
          :from => "#{env}/#{name}",
          :to => "#{to}/#{name}"
        })
      end
    end
  else
    Chef::Log.fail "Not defined env or from params"
  end
end

define :pfs_install_with_env, :virtualenv => nil do
  package("git")
  package("python-setuptools")
  package("python-pip")
  package("python-dev")

  # prepare vurtualenv if invoked virtualenv for python
  package("python-virtualenv") if params[:virtualenv]

  current_virtualenv = params[:virtualenv] ? "#{params[:virtualenv]}/bin/" : ""

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
    current_pip_cmd = "pip install --index-url http://#{proxy_addr}:#{proxy_port}/files/pip_cache/simple/"
  else
    # use external server
    current_pip_cmd = "pip install"
  end

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
        package pkg do
          version pkg_version if pkg_version != pkg
        end
      end

      # install pip packages
      pip_deps.each do |pkg|
        execute "pip_install_#{pkg}" do
          command "#{current_virtualenv}#{current_pip_cmd} '#{pkg}'"
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
      command "#{current_virtualenv}#{current_pip_cmd} -r tools/pip-requires"
    end
    execute "setup_#{current_name}" do
      cwd install_path
      command "#{current_virtualenv}python setup.py develop"
      creates "#{install_path}/#{current_name == "nova_dashboard" ? "horizon":current_name}.egg-info"
    end
    # select pip packages include in name clients
    pip_deps = current_attrs[:pfs_deps].select{|p| p.include?("client") }.collect{|p| p.gsub(/^pip:\/\//,"") }
    pip_deps.each do |pkg|
      execute "pip_install_clients_#{pkg}_for_#{current_name}" do
        command "#{current_virtualenv}#{current_pip_cmd} '#{pkg}'"
      end
    end
  end
end
