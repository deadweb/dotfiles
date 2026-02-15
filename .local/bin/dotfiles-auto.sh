#!/bin/bash
# ~/dotfiles-auto.sh

GIT_DIR="$HOME/.dotfiles.git"
WORK_TREE="$HOME"

# Функція для запуску git
dotfiles() {
    git --git-dir="$GIT_DIR" --work-tree="$WORK_TREE" "$@"
}

# Функція для нотифікацій
send_notification() {
    # Використовуємо повний шлях до бінарника
    /usr/bin/notify-send -u normal "Dotfiles Backup" "$1"
    # -i: іконка, -t: час відображення (3000 мс)
    # notify-send -i "emblem-shared" "Dotfiles Backup" "$1" -t 3000
}

# Перевіряємо зміни
if ! dotfiles diff-index --quiet HEAD --; then
    notify-send -u low "Dotfiles" " Знайдено зміни конфігурації, починаю оновлення..."
    
    dotfiles add -u
    
    if dotfiles commit -m "Auto-update $(date '+%Y-%m-%d %H:%M:%S')"; then
        if dotfiles push origin main; then
            notify-send "Конфігурації успішно оновлено на GitHub"
        else
            notify-send "Помилка при відправці на GitHub!"
        fi
    fi
else
    # Можна закоментувати цей рядок, якщо не хочете щоденних пустих повідомлень
    #echo "Змін немає"
    notify-send -u low " Dotfiles" "Змін немає"
fi
