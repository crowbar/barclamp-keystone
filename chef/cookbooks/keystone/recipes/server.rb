apt_repository "KeystoneRCB" do
  uri "http://ops.rcb.me/packages"
  distribution node["lsb"]["codename"]
  components ["diablo-d5"]
  action :add
end

user = node[:openstack][:keystone][:user]
uid = node[:openstack][:keystone][:uid]
grp = node[:openstack][:keystone][:group]

user node[:openstack][:keystone][:user] do
   uid uid
   group grp
end

package "keystone"

template "/etc/keystone/keystone.conf" do
    source "keystone.conf.erb"
    mode "0644"
    owner user
    group grp
end

service "keystone" do
  action [:enable, :start ]
end