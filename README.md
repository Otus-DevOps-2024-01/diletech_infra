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
