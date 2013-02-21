define :virtualenv, :action => :create, :owner => "root", :group => "root", :mode => 0755, :wrapped => [], :packages => {}, :root => "/usr/local/vitrualenv/" do
  path = params[:path] ? params[:path] : File.join(params[:root], params[:name]).to_s
  if params[:action] == :create
    # Create VirtualEnv
    package "python-pip" do
      action :install
    end
    directory path do
      recursive true
      owner params[:owner]
      group params[:group]
      mode params[:mode]
    end
    execute "create virtualenv #{path}" do
      command "virtualenv #{path} --system-site-packages"
      not_if "test -f #{path}/bin/python"
    end
    params[:packages].each_pair do |package, version|
      pip = "#{path}/bin/pip"
      execute "{pip} install #{package} #{version} -> #{path}" do
        command "#{pip} install #{package}==#{version}"
        not_if "[ `#{pip} freeze | grep #{package} | cut -d'=' -f3` = '#{version}' ]"
      end
    end
    (params[:wrapped] || []).each do |programm|
      next if File.exist? programm+'.origin'
      wrapped = programm+'.origin'
      Chef::Log.info "Wrapper #{wrapped} => #{programm} with python virtualenv #{path}"
      ::File.rename(programm,wrapped)
      template programm do
        source "virtualenv_wrapper.erb"
        variables({
            :enviroment => path,
            :wrapped => wrapped
        })
      end
      file programm do
        mode 0755
      end
    end
  elsif params[:action] == :delete
    # Delete VirtualEnv
    (params[:wrapped] || []).each do |programm|
      next if !File.exist? programm+'.origin'
      wrapped = programm+'.origin'
      Chef::Log.info "Restore wrapped #{programm} => #{wrapped}"
      FileUtils.mv(wrapped, programm)
    end
    directory path do
      action :delete
      recursive true
    end
  end
end
