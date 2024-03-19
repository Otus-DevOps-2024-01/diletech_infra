#!/usr/bin/env bash

# Проверяем доступность killall и pkill
if command -v killall &>/dev/null; then
    KILL_COMMAND="killall"
elif command -v pkill &>/dev/null; then
    KILL_COMMAND="pkill"
else
    echo "Не удалось найти ни killall, ни pkill. Выход."
fi

# Проверяем наличие процессов apt, apt-get и aptitude
for process in apt apt-get aptitude; do
    if pgrep -x "$process" >/dev/null; then
        echo "Процесс $process обнаружен. Завершение..."
        sudo "$KILL_COMMAND" "$process"
        sleep 2 # Даем немного времени на завершение процесса
    else
        echo "Процесс $process не обнаружен."
    fi
done

echo 'Проверяем и удаляем файлы apt lock'
files=("/var/lib/apt/lists/lock" "/var/cache/apt/archives/lock")

#Не срабатывает этот трюк: shopt -s nullglob  # Включаем nullglob для раскрытия пути с шаблоном
# Добавляем файлы /var/lib/dpkg/lock* в массив files, если они существуют
for file in /var/lib/dpkg/lock*; do
    if [ -e "$file" ]; then
        echo "Файл $file существует и будет добавлен в список."
        files+=("$file")
    else
        echo "Файл $file не существует."
    fi
done

# Удаляем файлы из массива files, если они существуют
for file in "${files[@]}"; do
    if [ -e "$file" ]; then
        # Проверяем доступность команды lsof
        if command -v lsof &>/dev/null; then
            # Проверяем, открыт ли файл процессами
            if output=$(lsof "$file" 2>/dev/null); then
                echo "Файл $file открыт следующими процессами:"
                echo "$output"
            else
                echo "Файл $file не открыт ни одним процессом."
            fi
        else
            echo "Команда lsof не найдена. Установите ее перед выполнением скрипта."
        fi

        # Удаляем файл в любом случае
        echo "Файл $file существует, будет удален."
        sudo rm -rf "$file"
        if [ $? -eq 0 ]; then
            echo "Файл $file успешно удален."
        else
            echo "Ошибка при удалении файла $file."
        fi
    else
        echo "Файл $file не существует."
    fi
done


# Проверяем наличие установленного пакета apt-transport-https
if ! dpkg -s apt-transport-https &>/dev/null; then
    echo "Пакет apt-transport-https не установлен. Установка..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https
fi
apt-get update && apt-get install -y apt-transport-https
apt-get clean -y
exit 0
