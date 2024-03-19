#/bin/bash
YC_CONFIG_FILE="$HOME/.config/yandex-cloud/config.yaml"

yaml_grep() {
    arg=$1
    result=$(grep $arg "$YC_CONFIG_FILE" | cut -d: -f2 | tr -d '[:space:]')
    echo "$result"
}

export TF_CLOUD_ID=$(yaml_grep "cloud-id")
export TF_FOLDER_ID=$(yaml_grep "folder-id")
export TF_ZONE="ru-central1-a"
export TF_IMAGE_ID=$(yc compute image list --format json | jq -r '.[].id')
export TF_PUBLIC_KEY_PATH="~/.ssh/yc.pub"
export TF_PRIVATE_KEY_PATH="~/.ssh/yc"
export TF_SUBNET_ID=$(yc vpc subnet list --format json | jq -r '.[0].id')
export TF_SERVICE_ACCOUNT_KEY_FILE="../../.yc/key.json"

envsubst < terraform.tfvars.tpl > terraform.tfvars.conf
