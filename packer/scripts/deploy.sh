#!/usr/bin/env bash
apt-get update && apt-get install -y git
useradd -m -s /usr/sbin/nologin reddit_user

mkdir /opt/reddit
git clone -b monolith https://github.com/express42/reddit.git /opt/reddit
cd /opt/reddit && bundle install
chown -R reddit_user:reddit_user /opt/reddit

cat <<EOF >/etc/systemd/system/puma.service
[Unit]
Description=Puma HTTP Server
After=network.target

[Service]
Type=simple
User=reddit_user
WorkingDirectory=/opt/reddit
ExecStart=/usr/local/bin/puma
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable puma
