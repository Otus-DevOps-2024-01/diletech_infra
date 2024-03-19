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
___
### Packer
- передача параметров в packer
`packer build -var 'source_image_id=fd85t6ulvuvp8q3trhbe' -var 'skip_create_image=true'  --var-file=variables.json .\ubuntu16.json`
- собственные команды автоматизации `yc` для fish
`source my-yc-command.fish`
- `vm-make-config.sh` готовит vm-config.txt из vm-init.tpl, используется в `yc compute instance create` для передачи параметров как `--metadata-from-file user-data=$YC_VM_CONFIG`


###### запуск для packer
1. инициализируем команды для автоматизации в fish-shell `source my-yc-command.fish`
    - `yc_print_variables` вывод переменных
    - `yc_list_all` запрос и вывод имеющихся ресурсов
    - `yc_vpc_network_create` создание сети
    - `yc_vpc_subnet_create` создание подсети
    - `yc_vpc_address_create` создание ip-адреса
    - `yc_vpc_prepare` подготовка сети: создание vpc subnet ext-ip
    - `yc_cumpute_instance_create` создание инстанса (получение имиджа и ext-ip по условию внутри функции)
    - `yc_all_delete` функция удаление всего
    - `yc_all_delete_confirm` интерактивный вызов функции удаления всего

2. из папки packer (используя пустой source_image_id в variables.json и передавая его в ключе -var):
    - получаем имидж с установкой окружения
      `packer build --var-file=variables.json .\ubuntu16.json`
    - из полученного имиджа по его id делаем деплой в новый имидж
      `packer build -var "source_image_id=$source_image_id" --var-file=variables.json .\immutable.json`
    - для прогона без создания имиджа `skip_create_image`

3. готовим сеть через свою автоматизацию:
    `yc_vpc_prepare`

4. создаем интсанс из готового имиджа запуском скрипта:
    `./config-scripts/create-reddit-vm.sh`

5. проверяем: получаем IP и открываем в браузере
    `set -U IP (yc compute instance list --format json | jq -r '.[].network_interfaces[].primary_v4_address.one_to_one_nat.address');and open http://$IP:9292; or echo Ooopss..`

6. всё удаляем
    `yc_all_delete_confirm`

### Terraform-1
``` shell
# 1. запекаем базовый образ
pushd packer && packer build -var-file=variables.json ubuntu16.js && popd

# 2. готовим сеть
source my-yc-command.fish; yc_vpc_network_create; yc_vpc_subnet_create

# 3.1 создаем переменные
cd terraform
./make-tfvars.sh && mv terraform.tfvars.conf terraform.tfvars
# 3.2 терраформируем
terraform init
terraform plan
terraform apply

# 4. проверяем
set -Ux IP (terraform output external_ip_address_app|tr -d \")
ssh -i ~/.ssh/yc ubuntu@$IP id
curl -sivm3 $IP:9292 | head

# 5. удаляем всё
terraform destroy
yc_all_delete_confirm
```
