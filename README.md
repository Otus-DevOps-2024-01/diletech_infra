# diletech_infra

cпособ подключения к someinternalhost в одну команду, но с учетом того что ключ уже добавлен в ssh-agent
```
ssh -J appuser@84.201.130.117 appuser@10.128.0.3
```

чтобы подключение выполнялось по алиасу `ssh someinternalhost` ножно добавить в ~/ssh/config
```
host bastion
        hostname 84.201.130.117
        port 22
        user appuser
        IdentityFile ~/.ssh/appuser

host someinternalhost
        hostname 10.128.0.3
        port 22
        user appuser
        IdentityFile ~/.ssh/appuser
        ProxyJump bastion
```

bastion_IP = 84.201.130.117
someinternalhost_IP = 10.128.0.3

testapp_IP =
testapp_port = 9292

___

testapp_IP = 51.250.85.60
testapp_port = 9292

```
yc compute instance create \
  --name reddit-app \
  --hostname reddit-app \
  --memory=4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1604-lts,size=10GB \
  --network-interface subnet-name=subnet1-a,nat-ip-version=ipv4 \
  --metadata serial-port-enable=1 \
  --metadata-from-file user-data=metadata.yaml
yc compute instance add-one-to-one-nat \
  --name reddit-app \
  --nat-address=51.250.85.60 \
  --network-interface-index=0
```
