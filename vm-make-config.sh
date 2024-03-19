#/bin/bash
export USER_SSH_KEY=$(cat ~/.ssh/appuser.pub)
export USER_NAME=yc-user

envsubst < vm-init.tpl > vm-config.txt
