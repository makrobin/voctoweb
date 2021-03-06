# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "ubuntu/bionic64"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network "private_network", ip: "192.168.23.42"
  config.vm.hostname = "media.ccc.vm"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
     # Customize the amount of memory on the VM:
     vb.memory = "4096"
     vb.cpus = 4
     vb.name = "voctoweb-dev"
  end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Define a Vagrant Push strategy for pushing to Atlas. Other push strategies
  # such as FTP and Heroku are also available. See the documentation at
  # https://docs.vagrantup.com/v2/push/atlas.html for more information.
  # config.push.define "atlas" do |push|
  #   push.app = "YOUR_ATLAS_USERNAME/YOUR_APPLICATION_NAME"
  # end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  config.vm.provision "shell", inline: <<-SHELL
    set -ev
    echo "nameserver 9.9.9.9" | tee /etc/resolv.conf

    export DEBIAN_FRONTEND="noninteractive"
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
    echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-6.x.list
    apt-get update
    apt-get install -y apt-transport-https
    apt-get install -y redis-server postgresql nodejs libssl-dev build-essential libpq-dev libsqlite3-dev nginx
    apt-get install -y --no-install-recommends openjdk-11-jre
    apt-get install -y elasticsearch

    # ruby
    if [ ! -x "$(command -v ruby)" ]; then
      gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
      curl -sSL https://get.rvm.io | bash -s stable --ruby
    fi

    # postgresql
    echo "create role voctoweb with createdb login password 'voctoweb';" | sudo -u postgres psql

    # elasticsearch
    sed -i -e 's/#START_DAEMON/START_DAEMON/' /etc/default/elasticsearch
    systemctl restart elasticsearch

    # rails
    chown vagrant -R /usr/local/rvm/gems/ruby-2.6.0/
    set +v
    sudo -u vagrant -i <<EOF
    cd /vagrant
    source /usr/local/rvm/scripts/rvm
    rvm use 2.6.0 --default
    rvm use 2.6.0@voctoweb --default
    gem install bundler
    bin/setup
EOF

    # Puma
    tee /etc/systemd/system/voctoweb-puma.service <<UNIT
[Unit]
Description=Puma application server for voctoweb
After=network.target vagrant.mount
Depends=vagrant.mount

[Service]
WorkingDirectory=/vagrant
Environment=RAILS_ENV=development
User=vagrant
PIDFile=/vagrant/tmp/pids/puma.pid
ExecStart=/usr/local/bin/bundle exec rails s -b 0.0.0.0
Restart=always
SyslogIdentifier=voctoweb-puma
RestartSec=5s
StartLimitInterval=0

[Install]
WantedBy=default.target
Depends=vagrant.mount
UNIT
    systemctl enable --now voctoweb-puma

    tee /etc/systemd/system/voctoweb-sidekiq.service <<UNIT
[Unit]
Description=Sidekiq job runner for media.ccc.de
After=network.target

[Service]
Type=simple
WorkingDirectory=/vagrant
User=vagrant
ExecStart=/usr/local/bin/bundle exec sidekiq --index 0 --environment development
Restart=always
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=voctoweb-sidekiq

[Install]
WantedBy=default.target
UNIT
    systemctl enable --now voctoweb-sidekiq

    # nginx
    tee /etc/nginx/sites-enabled/default <<NGINX
upstream puma {
	server localhost:3000;
}

server {
	listen 80 default_server;
	listen [::]:80 default_server;
	server_name _;
	root /vagrant/public;
	location @puma {
		set \\$remote_addr_v4 \\$remote_addr;
		if (\\$remote_addr ~* ^::ffff:(.*)) {
			set \\$remote_addr_v4 \\$1;
		}
		proxy_set_header  X-Forwarded-For \\$remote_addr_v4;
		proxy_set_header  X-Forwarded-Proto \\$scheme;
		proxy_set_header  X-Real-IP  \\$remote_addr;
		proxy_set_header  Host \\$http_host;
		proxy_redirect    off;
		proxy_pass        http://puma;
	}
	try_files /system/maintenance.html \\$uri \\$uri/index.html \\$uri.html @puma;
}
NGINX
    systemctl enable --now nginx

    echo "cd /vagrant" >> .profile

  SHELL
end
