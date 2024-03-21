export YC_VPC_NAME="app-network"
export YC_SUBNET_NAME="app-subnet"
export YC_ZONE="ru-central1-a"

export YC_VM_NAME="reddit-app"
export YC_VM_CONFIG="vm-config.txt"
export YC_STATIC_IP_NAME="infra-static-ip1"

export YC_SUBNET_ID=""
export YC_IMAGE_ID=""
export YC_STATIC_IP_ADDRESS=""


set objects 'compute instance
compute image
load-balancer network-load-balancer
load-balancer target-group
vpc subnet
vpc network
vpc address'

function yc_get_variables
    export YC_SUBNET_ID="$(yc vpc subnet list --format json | jq -r --arg name $YC_SUBNET_NAME '.[] | select(.name == $name) | .id')"
    export YC_IMAGE_ID="$(yc compute image list --format json | jq -r '.[0].id')"
    export YC_STATIC_IP_ADDRESS="$(yc vpc address list --format json | jq -r --arg name $YC_STATIC_IP_NAME '.[] | select(.name == $name) | .external_ipv4_address.address')"
end

function yc_print_variables
    for var in (env | grep "^YC_")
        echo $var
    end
end

function yc_list_object
    yc $argv list
end

function yc_delete_enum
    set obj $argv
    for id in (yc $obj list --format json | jq -r '.[].id')
        yc $obj delete --id=$id
    end
end


function yc_list_all
    for object in (echo $objects)
        echo LIST: $object
        eval yc_list_object $object
    end
end


#======= BEGIN CREATE FUNCTION NETWORK ======================================================
function yc_vpc_network_create
    yc vpc network create \
        --name $YC_VPC_NAME \
        --description "app network"
end

function yc_vpc_subnet_create
    yc vpc subnet create \
        --name $YC_SUBNET_NAME \
        --description "app subnet" \
        --network-name $YC_VPC_NAME \
        --zone $YC_ZONE \
        --range 10.16.8.0/24
end

function yc_vpc_address_create
    yc vpc address create \
        --name $YC_STATIC_IP_NAME \
        --external-ipv4 zone=$YC_ZONE
end

function yc_vpc_prepare
    yc_vpc_network_create
    yc_vpc_subnet_create
    yc_vpc_address_create
end

#======= BEGIN CREATE FUNCTION INSTANCE ======================================================
function yc_cumpute_instance_create_with_image-id_and_static-ip
    if test -n $YC_IMAGE_ID
        yc compute instance create \
            --name $YC_VM_NAME \
            --hostname $YC_VM_NAME \
            --memory=4 \
            --cores=2 \
            --zone=$YC_ZONE \
            --create-boot-disk size=10GB,image-id=$YC_IMAGE_ID \
            --network-interface subnet-name=$YC_SUBNET_NAME \
            --metadata serial-port-enable=1 \
            --metadata-from-file user-data=$YC_VM_CONFIG
    else
        echo not exist YC_IMAGE_ID
    end

    if test -n $YC_STATIC_IP_ADDRESS
        yc compute instance add-one-to-one-nat \
            --name $YC_VM_NAME \
            --nat-address=$YC_STATIC_IP_ADDRESS \
            --network-interface-index=0
    else
        echo not exist YC_STATIC_IP_ADDRESS
    end
end
#======= END CREATE ==========================================================


#======= BEGIN DELETE FUNCTION ===============================================
function yc_all_delete
    # Первый аргумент - режим удаления:
    # - 'all' (удалить все)
    # - 'skip' (удалить с проверкой)
    set mode $argv[1]

    if test "$YC_CONFIRM_DELETE" = yes
        echo "Starting deletion process..."
        echo "You have 10 seconds to cancel the operation by pressing Ctrl+C"

        for i in (seq 10 -1 1)
            echo -n "Deletion will proceed in $i seconds... "
            sleep 1
            echo ""
        end

        # Исключаемые объекты из обработки удаления в зависимости от mode
        set skip_objects 'vpc subnet
vpc network
compute image'

        # В зависимости от ключа удаляем всё или с исключением
        if test "$mode" = all
            for object in (echo $objects)
                echo DELETE: $object
                eval yc_delete_enum $object
            end
        else if test "$mode" = skip
            set check_array (string split \n "$skip_objects")

            for object in (echo $objects)
                # if string match -qr "$object" $check_array
                if contains -- "$object" $check_array
                    echo "Skipping: $object"
                    continue
                end
                echo DELETE: $object
                eval yc_delete_enum $object
            end
        else
            echo "Invalid mode specified. Please specify 'all' or 'skip'."
            return 1
        end

        echo "Deleted successfully."
    else
        echo "Deletion canceled."
    end
end

function yc_all_delete_confirm
    # Проверка наличия ключа
    if test (count $argv) -ne 1
        echo "Usage: yc_all_delete_confirm [all|skip]"
        return
    end

    # Проверка получаемого значения ключа
    set -l mode $argv[1]
    if test "$mode" != "all" -a "$mode" != "skip"
        echo "Usage: yc_all_delete_confirm [all|skip]"
        return
    end

    set -q YC_CONFIRM_DELETE || set -x YC_CONFIRM_DELETE (read -P "Are you sure you want to delete? (yes/no): ")
    if test "$YC_CONFIRM_DELETE" = yes
        # Передаем аргумент в функцию yc_all_delete для выбора режима удаления
        yc_all_delete $mode
    else
        echo "Deletion canceled."
    end
end
#======= END DELETE =====================================================
