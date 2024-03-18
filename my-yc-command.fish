export YC_VPC_NAME="infra"
export YC_SUBNET_NAME="subnet1-a"
export YC_ZONE="ru-central1-a"

export YC_VM_NAME="reddit-app"
export YC_VM_CONFIG="vm-config.txt"
export YC_STATIC_IP_NAME="infra-static-ip1"

function yc_print_variables
    for var in (env | grep "^YC_")
        echo $var
    end
end


function yc_list_all
        yc vpc network list
        yc vpc subnet list
        yc vpc address list
        yc compute instance list
        yc compute image list
        yc resource-manager cloud list
        yc resource-manager folder list
end


#======= BEGIN CREATE FUNCTION ======================================================
function yc_vpc_network_create
    yc vpc network create \
        --name $YC_VPC_NAME \
        --description "infra network"
end

function yc_vpc_subnet_create
    yc vpc subnet create \
        --name $YC_SUBNET_NAME \
        --description "infra subnet" \
        --network-name infra \
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

function yc_cumpute_instance_create
    export YC_IMAGE_ID=$(yc compute image list --format json | jq -r '.[0].id')
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

    export YC_STATIC_IP_ADDRESS=$(yc vpc address list --format json | jq -r --arg name $YC_STATIC_IP_NAME  '.[] | select(.name == $name) | .external_ipv4_address.address')
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
    if test "$YC_CONFIRM_DELETE" = yes
        echo "Starting deletion process..."
        echo "You have 10 seconds to cancel the operation by pressing Ctrl+C"

        for i in (seq 10 -1 1)
            echo -n "Deletion will proceed in $i seconds... "
            sleep 1
            echo ""
        end

        yc compute instance delete \
            --name $YC_VM_NAME

        yc vpc subnet delete \
            --name $YC_SUBNET_NAME

        yc vpc network delete \
            --name $YC_VPC_NAME

        yc vpc address delete \
            --name $YC_STATIC_IP_NAME

        for id in (yc compute image list --format json | jq -r '.[].id')
            yc compute image delete --id=$id
        end

        echo "Deleted successfully."
    else
        echo "Deletion canceled."
    end
end

function yc_all_delete_confirm
    set -q YC_CONFIRM_DELETE || set -x YC_CONFIRM_DELETE (read -P "Are you sure you want to delete? (yes/no): ")
    if test "$YC_CONFIRM_DELETE" = yes
        yc_all_delete
    else
        echo "Deletion canceled."
    end
end
#======= END DELETE =====================================================
