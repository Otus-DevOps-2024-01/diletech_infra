#!/bin/bash
# mode_env=$1 # "stage" or "prod"
# if [ "$mode_env" != "stage" ] && [ "$mode_env" != "prod" ]; then
#     echo "Usage: $0 <stage|prod>"
#     exit 1
# fi

# Запуск для сред выполнения terraform
for mode_env in stage prod; do
    echo "For $mode_env"
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
    export TF_PUBLIC_KEY_PATH="~/.ssh/appuser.pub"
    export TF_PRIVATE_KEY_PATH="~/.ssh/appuser"
    export TF_SERVICE_ACCOUNT_KEY_FILE="$HOME/.yc/terraform-key.json" # путь к ключу сервисного аккаунта

    echo TF_CLOUD=$TF_CLOUD_ID
    echo TF_FOLDER=$TF_FOLDER_ID
    echo TF_ZONE=$TF_ZONE
    echo TF_PUBLIC_KEY_PATH=$TF_PUBLIC_KEY_PATH
    echo TF_PRIVATE_KEY_PATH=$TF_PRIVATE_KEY_PATH
    echo TF_SERVICE_ACCOUNT_KEY_FILE=$TF_SERVICE_ACCOUNT_KEY_FILE

    name_subnet="app-subnet-${mode_env}" # название подсети для скрабинга
    export TF_SUBNET_ID=$(yc vpc subnet list --format json | jq -r --arg name $name_subnet '.[] | select(.name == $name) | .id')
    echo TF_SUBNET_ID=$TF_SUBNET_ID

    # получем json список образов и из него вытаскиваем свежие id образов по их family
    image_list=$(yc compute image list --format json)
    export TF_APP_DISK_IMAGE=$(get_id_image_by_family "reddit-app-base")
    export TF_DB_DISK_IMAGE=$(get_id_image_by_family "reddit-db-base")
    echo TF_APPP_DISK_IMAGE=$TF_APP_DISK_IMAGE
    echo TF_DB_DISK_IMAGE=$TF_DB_DISK_IMAGE

    export TF_VM_NAME_DB="reddit-db-${mode_env}"
    export TF_VM_NAME_APP="reddit-app-${mode_env}"
    echo TF_VM_NAME_DB=$TF_VM_NAME_DB
    echo TF_VM_NAME_APP=$TF_VM_NAME_APP

    export TF_BUCKET_NAME="diletech-terraform-state"
    export TF_BUCKET_SECRET=$(yaml_grep "secret" $YC_KEY_FILE_TF)
    export TF_BUCKET_KEY_ID=$(yaml_grep "key_id" $YC_KEY_FILE_TF)
    export TF_BUCKET_KEY_NAME="${mode_env}-terraform.tfstate"
    echo TF_BUCKET_NAME=$TF_BUCKET_NAME
    echo TF_BUCKET_SECRET=$TF_BUCKET_SECRET
    echo TF_BUCKET_KEY_ID=$TF_BUCKET_KEY_ID
    echo TF_BUCKET_KEY_NAME=$TF_BUCKET_KEY_NAME

    # Список переменных для проверки
    variables=("TF_CLOUD_ID" "TF_FOLDER_ID" "TF_SUBNET_ID" "TF_APP_DISK_IMAGE" "TF_DB_DISK_IMAGE" "TF_BUCKET_SECRET" "TF_BUCKET_KEY_ID")
    # Флаг для отслеживания пустых переменных
    empty_found=false

    # Проверка каждой переменной
    for var in "${variables[@]}"; do
        if [ -z "${!var}" ]; then
            echo "Переменная $var пустая или не существует"
            empty_found=true
        fi
    done

    # Вывод предупреждения, если найдена хотя бы одна пустая переменная
    if [ "$empty_found" = true ]; then
        echo "Внимание: Найдены пустые переменные!"
        continue
    fi

    path_tpl="terraform.tfvars.tpl"
    path_conf="${mode_env}/terraform.tfvars"
    echo -e "to file $path_conf\n\n"
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
export TF_BUCKET_KEY_NAME="terraform.tfstate"
envsubst <$path_tpl >$path_conf
sed -i '/prod\|stage/d' $path_conf
cat <<EOF >terraform_init.sh
#!/bin/bash
terraform init \\
    -backend-config="bucket=${TF_BUCKET_NAME}" \\
    -backend-config="key=${TF_BUCKET_KEY_NAME}" \\
    -backend-config="access_key=${TF_BUCKET_KEY_ID}" \\
    -backend-config="secret_key=${TF_BUCKET_SECRET}"
# удаляем себя
rm \$0
EOF
chmod +x terraform_init.sh
