#!/usr/bin/env python3
import re
import sys

# Читаем данные из стандартного потока ввода (stdin)
terraform_output = sys.stdin.read()

# Создаем пустой словарь для группировки хостов по окружениям и типу
inventory = {'prod': {'app': [], 'db': []}, 'stage': {'app': [], 'db': []}}

# Регулярные выражения для извлечения IP-адресов
ip_address_pattern = re.compile(r'(\d+\.\d+\.\d+\.\d+)')

# Разбиваем вывод Terraform по окружениям
environments = terraform_output.strip().split('terraform output -> ')

# Проходимся по каждому окружению
for env in environments[1:]:
    lines = env.strip().split('\n')
    # Проверяем, в какое окружение попал текущий блок вывода
    current_env = lines[0].strip()
    # Проходимся по строкам блока вывода и извлекаем IP-адреса
    for line in lines[1:]:
        match = ip_address_pattern.search(line)
        if match:
            ip_address = match.group(1)
            # Определяем тип хоста (app или db) и добавляем в соответствующий список
            if 'external_ip_address_app' in line:
                inventory[current_env]['app'].append(ip_address)
            elif 'external_ip_address_db' in line:
                inventory[current_env]['db'].append(ip_address)

# Генерируем inventory файл для Ansible в формате INI
with open('inventory', 'w') as f:
    for env, groups in inventory.items():
        f.write(f'[{env}]\n')
        for group, hosts in groups.items():
            for i, host in enumerate(hosts, 1):
                f.write(f'{group}server-{env} ansible_host={host}\n')
        f.write('\n')

    f.write('[db]\n')
    for env, hosts in inventory.items():
        for host in hosts['db']:
            f.write(f'dbserver-{env} ansible_host={host}\n')
    f.write('\n')

    f.write('[app]\n')
    for env, hosts in inventory.items():
        for host in hosts['app']:
            f.write(f'appserver-{env} ansible_host={host}\n')
    f.write('\n')
