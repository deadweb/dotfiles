#!/bin/bash

# Змінна середовища для нотифікацій у cron/systemd (про всяк випадок)
export DISPLAY=:0

send_notification() {
    /usr/bin/notify-send -u normal "Cleanup System" "$1"
}

# Початкова ініціалізація змінної
DELETED_ANY=false

# Список папок та днів для очищення
declare -A TARGETS=(
    ["$HOME/Pictures/Screenshots"]=30
    ["$HOME/Downloads"]=30
    ["$HOME/.local/share/Trash/files"]=30
    ["$HOME/.local/share/TelegramDesktop/tdata/user_data/media_cache"]=14
)

for dir in "${!TARGETS[@]}"; do
    days="${TARGETS[$dir]}"
    if [ -d "$dir" ]; then
        if [ -n "$(find "$dir" -type f -mtime +"$days" -print -quit)" ]; then
            find "$dir" -type f -mtime +"$days" -delete
            DELETED_ANY=true
        fi
    fi
done

if [ "$DELETED_ANY" = true ]; then
    send_notification "Старі файли видалено"
fi
