#!/usr/bin/env bash
echo 'stop and clear and repair APT'
ps auxw | grep 'apt' | awk '{print $2}' | xargs kill -9
sudo rm /var/lib/apt/lists/lock
sudo rm /var/cache/apt/archives/lock
sudo rm /var/lib/dpkg/lock*
exit 0
