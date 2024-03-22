#!/bin/bash
mode_env=$1 # "stage" or "prod"

if [ "$mode_env" != "stage" ] && [ "$mode_env" != "prod" ]; then
    echo "Usage: $0 <stage|prod>"
    exit 1
fi

YC_CONFIG_FILE="$HOME/.config/yandex-cloud/config.yaml"

yaml_grep() {
    arg=$1
    result=$(grep $arg "$YC_CONFIG_FILE" | cut -d: -f2 | tr -d '[:space:]')
    echo "$result"
}

get_id_image_by_family() { # $1 - family образа
    echo "$image_list" | jq -r --arg name $1 'map(select(.family == $name)) | sort_by((.name | capture("-(?<number>[0-9]+)$").number | tonumber)) | .[-1].id'
}

export TF_CLOUD_ID=$(yaml_grep "cloud-id")
export TF_FOLDER_ID=$(yaml_grep "folder-id")
export TF_ZONE="ru-central1-a"
export TF_PUBLIC_KEY_PATH="~/.ssh/yc.pub"
export TF_PRIVATE_KEY_PATH="~/.ssh/yc"
export TF_SERVICE_ACCOUNT_KEY_FILE="../../../.yc/key.json" # относительный путь к ключу сервисного аккаунта

name_subnet="app-subnet-${mode_env}" # название подсети для скрабинга
export TF_SUBNET_ID=$(yc vpc subnet list --format json | jq -r --arg name $name_subnet '.[] | select(.name == $name) | .id')

# получем json список образов и из него вытаскиваем свежие id образов по их family
image_list=$(yc compute image list --format json)
export TF_APP_DISK_IMAGE=$(get_id_image_by_family "reddit-app-base")
export TF_DB_DISK_IMAGE=$(get_id_image_by_family "reddit-db-base")

export TF_VM_NAME_DB="reddit-db-${mode_env}"
export TF_VM_NAME_APP="reddit-app-${mode_env}"

path_tpl="terraform.tfvars.tpl"
path_conf="${mode_env}/terraform.tfvars"
envsubst <$path_tpl >$path_conf
