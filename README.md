# Description
This is a guide on how to setup a [DigitialOcean](http://www.digitalocean.com)
droplet to update and trigger package builds on the [OpenBuildService](http://build.opensuse.org).

The project is based heavily on GitHub's own [Webhooks Guide](https://developer.github.com/webhooks/)

The heart of this project is a thin server that listen to GitHub webhooks and
executes builds base on the POST data provided by GitHub's api.

The distro of choice for this tutorial is Debian stable.

# Getting started:

## Prerequistes:
Let's begin installing all the necessary packages.

```
wget -qO- http://download.opensuse.org/repositories/openSUSE:Tools/Debian_8.0/Release.key | apt-key add -
apt-get install firewalld sudo fail2ban zsh git-core vim-nox ipset osc
```

## Securing the server:
For security purpose, it is recommended one install firewalld and place
any public facing interface in the `public` zone.

Additionally, fail2ban should be installed and configure to block ssh-ddos and
ssh brute force attacks.
```
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime  = 86400
findtime = 14400
maxretry = 3
backend = polling
usedns = warn
banaction = firewallcmd-ipset
action = %(action_)s


[ssh]

enabled  = true
action   = firewallcmd-ipset
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3


[ssh-ddos]

enabled  = true
action   = firewallcmd-ipset
port     = ssh
filter   = sshd-ddos
logpath  = /var/log/auth.log
maxretry = 3
```

The following should be added to /etc/fail2ban/filter.d/sshd.conf, under
failregex. This will ban individuals who try to login with invalid private ssh
certificate.
```
^%(__prefix_line)sConnection closed by <HOST> \[preauth\]$
```

## Installing ruby:
Execute the following commands to install rvm and setup ruby, sinatra and thin.
```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
curl -sSL https://get.rvm.io | bash -s stable --ruby
rvm use 2.2.1
rvm gemset create ruby2thin
rvm use ruby-2.2.1@ruby2thin
ruby -v
rvm gemset list
gem install sinatra thin openssl rack
rvm wrapper ruby-2.2.1@ruby2thin github_thin


rvm alias create webserver_thin 2.3.1
```

### Configure the thin web project:
Create the necessary directories for the web project.
```
mkdir -p /www/projects/github-payload/
mkdir -p /www/projects/github-payload/configs
mkdir -p /www/projects/github-payload/log
```

Install the systemd service file included in the repo. It should look very
similar to what you see below.
```
[Unit]
Description=Ruby web server, listening for github webhooks

[Service]
Type=simple
EnvironmentFile=/etc/github-payload.env
RemainAfterExit=yes
PIDFile=/www/projects/github-payload/configs/thin.4567.pid
WorkingDirectory=/www/projects/github-payload
ExecStart=/usr/local/rvm/bin/github_thin -C /www/projects/github-payload/configs/config.yml -R /www/projects/github-payload/configs/config.ru start
ExecStop=/usr/local/rvm/bin/github_thin -C /www/projects/github-payload/configs/config.yml -R /www/projects/github-payload/configs/config.ru stop
TimeoutSec=300

[Install]
WantedBy=multi-user.target
```

Configure the `thin` server like in the samples below.
Sample `/www/projects/github-payload/configs/config.yml`
```
---
     environment: production
     chdir: "/www/projects/github-payload"
     address: 127.0.0.1
     user: root
     port: 4567
     pid: "/www/projects/github-payload/configs/thin.pid"
     rackup: "/www/projects/github-payload/configs/config.ru"
     log: "/www/projects/github-payload/log/thin.log"
     max_conns: 1024
     timeout: 30
     servers: 1
     max_persistent_conns: 512
     daemonize: false
```

Sample `/www/projects/github-payload/configs/config.ru`
```
require './app'
run Sinatra::Application
```

Setup a TOKEN in order to secure the thin server:
```
echo -n "SECRET_TOKEN=$(ruby -rsecurerandom -e 'puts SecureRandom.hex(20)')" > /etc/github-payload.env
```
Please note how the systemd service file sources the resulting TOKEN into the
service's environment.


## Setup ngrok:
ngrok is used in order to setup a secure public URL

### Install:
Follow ngrok's installation [instructions](https://ngrok.com/download), ensure
you copy the binary to `/usr/bin`

Setup a systemd service file to start ngrok on boot.
```
[Unit]
Description=Share local port(s) with ngrok
After=network.target, github-payload

[Service]
PrivateTmp=true
Type=simple
Restart=always
RestartSec=1min
ExecStart=/usr/bin/ngrok http -config /opt/ngrok/ngrok.yml -log stdout -log-format json 4567

[Install]
WantedBy=multi-user.target
```

Configure ngrok with the authoken provided when you signed up.
```
ngrok authtoken {TOKEN} -config /opt/ngrok/ngrok.yml
```

## Test thin server and your new api:
You can test the api using `curl` such as in the examples below.
```
curl -X POST -H "Accept: application/json" -d '{"body": "Payload test." }' http://localhost:4567/payload
curl -X POST -H "Accept: application/json" -d "@test.json" http://localhost:4567/payload
