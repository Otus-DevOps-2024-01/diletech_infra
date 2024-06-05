#!/usr/bin/env python3
import re
import sys

# Читаем данные из стандартного потока ввода (stdin)
terraform_output = sys.stdin.read()

# Создаем пустой словарь для группировки хостов по окружениям и типу
inventory = {'prod': {'app': [], 'db': []}, 'stage': {'app': [], 'db': []}}

# Регулярные выражения для извлечения IP-адресов
ip_address_pattern = re.compile(r'(\d+\.\d+\.\d+\.\d+)')
internal_ip_address_pattern = re.compile(r'internal_ip_address_(\w+)')

# Разбиваем вывод Terraform по окружениям
environments = terraform_output.strip().split('terraform output -> ')

# Проходимся по каждому окружению
for env in environments[1:]:
    lines = env.strip().split('\n')
    # Проверяем, в какое окружение попал текущий блок вывода
    current_env = lines[0].strip()
    # Проходимся по строкам блока вывода и извлекаем IP-адреса
    for line in lines[1:]:
        match_ip = ip_address_pattern.search(line)
        match_internal_ip = internal_ip_address_pattern.search(line)
        if match_ip:
            ip_address = match_ip.group(1)
            # Определяем тип хоста (app или db) и добавляем в соответствующий список
            if 'external_ip_address_app' in line:
                inventory[current_env]['app'].append({'external_ip': ip_address})
            elif 'external_ip_address_db' in line:
                inventory[current_env]['db'].append({'external_ip': ip_address})
        if match_internal_ip:
            internal_ip_address = match_internal_ip.group(1)
            if internal_ip_address == 'app':
                inventory[current_env]['app'][-1]['internal_ip'] = line.split('=')[1].strip().strip('"')
            elif internal_ip_address == 'db':
                inventory[current_env]['db'][-1]['internal_ip'] = line.split('=')[1].strip().strip('"')

# Генерируем inventory файл для Ansible в формате INI
with open('inventory', 'w') as f:
    for env, groups in inventory.items():
        f.write(f'[{env}]\n')
        for group, hosts in groups.items():
            for i, host in enumerate(hosts, 1):
                external_ip = host.get("external_ip", "unknown")
                internal_ip = host.get("internal_ip", "unknown")
                f.write(f'{group}server-{env} ansible_host={external_ip} internal_ip={internal_ip}\n')
        f.write('\n')

    f.write('[db]\n')
    for env, hosts in inventory.items():
        for host in hosts['db']:
            f.write(f'dbserver-{env} ansible_host={host["external_ip"]} internal_ip={host["internal_ip"]}\n')
    f.write('\n')

    f.write('[app]\n')
    for env, hosts in inventory.items():
        for host in hosts['app']:
            external_ip = host.get("external_ip", "unknown")
            internal_ip = host.get("internal_ip", "unknown")
            f.write(f'appserver-{env} ansible_host={external_ip} internal_ip={internal_ip}\n')
    f.write('\n')
