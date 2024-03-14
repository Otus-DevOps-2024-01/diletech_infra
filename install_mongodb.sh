#!/usr/bin/env bash
sudo apt-get update && sudo apt-get install apt-transport-https
wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
sudo apt-get update
sudo apt-get install -y mongodb-org
sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf # для прохождения теста
sudo service mongod start || sudo systemctl start mongod
sudo service mongod enable || sudo systemctl enable mongod
