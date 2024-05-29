#!/bin/bash
# mode_env=$1 # "stage" or "prod"
# if [ "$mode_env" != "stage" ] && [ "$mode_env" != "prod" ]; then
#     echo "Usage: $0 <stage|prod>"
#     exit 1
# fi

# Запуск для сред выполнения terraform
for mode_env in stage prod; do

    YC_CONFIG_FILE="$HOME/.config/yandex-cloud/config.yaml"
    YC_KEY_FILE_TF="$HOME/.yc/terraform-static_key.txt"

    yaml_grep() {
        who=$1
        where=$2
        result=$(grep $who "$where" | cut -d: -f2 | tr -d '[:space:]')
        echo "$result"
    }

    get_id_image_by_family() { # $1 - family образа
        echo "$image_list" | jq -r --arg name $1 'map(select(.family == $name)) | sort_by((.name | capture("-(?<number>[0-9]+)$").number | tonumber)) | .[-1].id'
    }

    export TF_CLOUD_ID=$(yaml_grep "cloud-id" $YC_CONFIG_FILE)
    export TF_FOLDER_ID=$(yaml_grep "folder-id" $YC_CONFIG_FILE)
    export TF_ZONE="ru-central1-a"
    export TF_PUBLIC_KEY_PATH="~/.ssh/yc.pub"
    export TF_PRIVATE_KEY_PATH="~/.ssh/yc"
    export TF_SERVICE_ACCOUNT_KEY_FILE="$HOME/.yc/terraform-key.json" # путь к ключу сервисного аккаунта

    name_subnet="app-subnet-${mode_env}" # название подсети для скрабинга
    export TF_SUBNET_ID=$(yc vpc subnet list --format json | jq -r --arg name $name_subnet '.[] | select(.name == $name) | .id')

    # получем json список образов и из него вытаскиваем свежие id образов по их family
    image_list=$(yc compute image list --format json)
    export TF_APP_DISK_IMAGE=$(get_id_image_by_family "reddit-app-base")
    export TF_DB_DISK_IMAGE=$(get_id_image_by_family "reddit-db-base")

    export TF_VM_NAME_DB="reddit-db-${mode_env}"
    export TF_VM_NAME_APP="reddit-app-${mode_env}"

    export TF_BUCKET_NAME="diletech-terraform-state"
    export TF_BUCKET_SECRET=$(yaml_grep "secret" $YC_KEY_FILE_TF)
    export TF_BUCKET_KEY_ID=$(yaml_grep "key_id" $YC_KEY_FILE_TF)
    export TF_BUCKET_KEY_NAME="${mode_env}-terraform.tfstate"

    path_tpl="terraform.tfvars.tpl"
    path_conf="${mode_env}/terraform.tfvars"
    envsubst <$path_tpl >$path_conf

    # готовим скрипт для инициализации с бэкендом
    cat <<EOF >$mode_env/terraform_init.sh
#!/bin/bash
terraform init \\
    -backend-config="bucket=${TF_BUCKET_NAME}" \\
    -backend-config="key=${TF_BUCKET_KEY_NAME}" \\
    -backend-config="access_key=${TF_BUCKET_KEY_ID}" \\
    -backend-config="secret_key=${TF_BUCKET_SECRET}"
# удаляем себя
rm \$0
EOF
    chmod +x $mode_env/terraform_init.sh

    # запускаем скрипт для инициализации
    #cd $mode_env &&./terraform_init.sh && cd -
done

# Запуск для создания бэкенда
path_tpl="terraform.tfvars.tpl"
path_conf="terraform.tfvars"
envsubst <$path_tpl >$path_conf
sed -i '/prod\|stage/d' $path_conf
cat <<EOF >terraform_init.sh
#!/bin/bash
terraform init \\
    -backend-config="bucket=${TF_BUCKET_NAME}" \\
    -backend-config="access_key=${TF_BUCKET_KEY_ID}" \\
    -backend-config="secret_key=${TF_BUCKET_SECRET}"
# удаляем себя
rm \$0
EOF
chmod +x terraform_init.sh
