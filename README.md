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
# 0. смотрим на ресурсы и создаем сеть если нету и получаем переменные
source my-yc-command.fish
yc_list_all  # смотреть что есть
source my-yc-command.fish; yc_vpc_network_create; yc_vpc_subnet_create # создать сети
# две сети прод и стедж
set -l D stage prod; for d in $D; yc_vpc_subnet_create "app-subnet-$d"; end
yc_get_variables  # получить переменные через yc
yc_print_variables  # вывести имеющиеся переменные YC_*

# 1. запекаем базовый образ
set -l packer_validate "packer validate -var-file=variables.json -var subnet_id=$YC_SUBNET_ID ubuntu16.json"
set -l packer_build "packer build -var-file=variables.json -var subnet_id=$YC_SUBNET_ID ubuntu16.json"
pushd packer; eval $packer_validate; and eval $packer_build; or exit 1
popd

# 2 подготоавливаем терраформ
cd terraform
# 2.1 создаем переменные для terraform
./make-tfvars.sh && mv terraform.tfvars.conf terraform.tfvars
# 2.2 воркараунд: применяем спрятанный от гитакшэн файл
cp yc_terraform.tf.txt yc_terraform.tf
# 2.3 для nlb применить настрйку количества нод
echo "instance_count = 2" >> terraform.tfvars

# 3 терраформируем
terraform validate
terraform init
terraform plan
terraform apply

# 4. проверяем
set -Ux IP (terraform output external_ip_address_app|tr -d '"')
ssh -i ~/.ssh/yc ubuntu@$IP id
curl -sivm3 $IP:9292 | head

# 5. удаляем всё
terraform destroy
yc_all_delete_confirm all
```

### Terraform-2
```fish
set -l D stage prod # среды окружения разделенные по одноименным папкам
# 0. подготовка сетей если их нет
source my-yc-command.fish; yc_vpc_network_create; yc_vpc_subnet_create  # создать vpc и subnet
for d in $D; yc_vpc_subnet_create "app-subnet-$d"; end  # две подсети для сред терраформа
yc_get_variables  # получить переменные yc, для пакер нужен subnet-id


# 1. запекаем пакером имиджи
pushd packer
set -l p "-var-file=variables.json -var subnet_id=$YC_SUBNET_ID"
for f in {app,db}.json; for c in validate build; eval packer $c $p $f; or exit 1; end; end
popd


# 2. начинаем терраформ
cd terraform
# 2.0 настройка источника поставки бинарей на зеркало
cp -av terraformrc.txt ~/.terraformrc
# 2.1.2 создаем символические ссылки на файл оприделения провайдера yc
set -l yc_tf yc_terraform.tf
# для модулей (vpc не используется)
for d in app db vpc; pushd modules/$d; ln -vsf ../../$yc_tf.txt $yc_tf; popd; end
# для окружений
for d in $D; pushd $d; ln -vsf ../$yc_tf.txt $yc_tf; popd; end
# 2.2 для окружений эти файлы одинаковые на данный момент, но так как vscode не видит ссылки и краснеет, поэтому дублируем иноды
for d in $D; pushd $d; for f in backend.tf variables.tf; ln -f ../$f .; end; popd; end
# 2.1 создаем переменные динамические variables.tf
# и тут же делаем скрипты инициализации terraform_init.sh для инициализации  ремоут бэкендов
./make-tfvars.sh

# 3. терраформим
# функция прогона терраформа
function do-terraform
  begin
  terraform validate
  terraform get
  ./terraform_init.sh
  terraform init -upgrade
  terraform refresh
  terraform show
  terraform plan && terraform apply -auto-approve
  end; and return 0; or return 1
end
# 3.1 создаём prod и stage
set -l do do-terraform
for d in . $D; pushd $d; echo "$do: $d"; eval $do ; popd; end
# 3.2 после изменений outputs.tf
terraform refresh
terraform output


# 4. удаляем
set -l do "terraform apply -auto-approve -destroy"
for d in . $D; pushd $d; echo "$do: $d"; eval $do ; popd; end
set -x YC_CONFIRM_DELETE yes; yc_all_delete_confirm all; set -e YC_CONFIRM_DELETE
```
