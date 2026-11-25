#!/usr/bin/env bash

# Переходимо на робочий простір 1 (використовуйте точну назву із вашого конфігу)
i3-msg "workspace 1: "

# Завантажуємо макет
i3-msg "append_layout ~/.config/i3/workspace-1.json"

# Запускаємо програми відповідно до заголовків (titles)
kitty --title kitty_main &
sleep 0.1
kitty --title htop -e htop &
sleep 0.1
kitty --title ranger -e ranger &
