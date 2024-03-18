#!/usr/bin/env bash
export YC_SUBNET_NAME="subnet1-a"
export YC_ZONE="ru-central1-a"
export YC_VM_NAME="reddit-app"
export YC_VM_CONFIG="vm-config.txt"
export YC_VM_IMAGE_FAMILY="reddit-full"

yc compute instance create \
            --name $YC_VM_NAME \
            --hostname $YC_VM_NAME \
            --memory=4 \
            --cores=2 \
            --zone=$YC_ZONE \
            --create-boot-disk size=10GB,image-family=$YC_VM_IMAGE_FAMILY \
            --network-interface subnet-name=$YC_SUBNET_NAME,nat-ip-version=ipv4 \
            --metadata serial-port-enable=1 \
            --metadata-from-file user-data=$YC_VM_CONFIG
