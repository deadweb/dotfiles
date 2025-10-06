#!/bin/bash
set -euo pipefail

# Поточна гучність
volume=$(amixer get Master | awk -F'[][]' '/%/ { print $2; exit }')
volume_int=${volume%\%}

# Вибір іконки Font Awesome
if [[ $volume_int -eq 0 ]]; then
    icon=""   # volume-off
elif [[ $volume_int -le 30 ]]; then
    icon=""   # volume-down
elif [[ $volume_int -le 70 ]]; then
    icon=""   # volume-up
else
    icon=""   # volume-up
fi

# Виводимо лише іконку у dunst
dunstify --timeout=3000 --replace=3710 -h "int:value:$volume_int" "$icon"

# Оновлення i3blocks
pkill -RTMIN+1 i3blocks

