#!/bin/bash
set -uo pipefail

# 1. КОНФІГУРАЦІЯ
ID_VOL=3710
ID_MIC=3711
COLOR_CYAN="#7d7d7d"

get_vol() {
    amixer get Master | grep -oE "[0-9]+%" | head -1 | tr -d '%'
}

current_vol=$(get_vol)

# 2. ОБРОБКА ДІЙ
case "${1:-}" in
    up)
        [ "$current_vol" -lt 100 ] && amixer set Master 5%+ > /dev/null || amixer set Master 100% > /dev/null
        ;;
    down)
        amixer set Master 5%- > /dev/null
        ;;
    mute)
        amixer set Master toggle > /dev/null
        ;;
    micmute)
        amixer set Capture toggle > /dev/null
        # Перевірка статусу та вибір іконки
        if amixer get Capture | grep -m1 "\[" | grep -q "\[off\]"; then
            status_text="Мікрофон вимкнено"
            icon=$(printf "\uf131") # Перекреслений мікрофон
            urgency="low"
        else
            status_text="Мікрофон увімкнено"
            icon=$(printf "\uf130") # Активний мікрофон
            urgency="low"
        fi
        dunstify -a "System" -u "$urgency" -r "$ID_MIC" "$icon  $status_text"
        exit 0
        ;;
esac

# 3. ОНОВЛЕННЯ ДАНИХ ДЛЯ ЗВУКУ
new_vol=$(get_vol)
is_muted=$(amixer get Master | grep -m1 "\[" | grep -q "\[off\]" && echo "yes" || echo "no")

if [[ "$is_muted" == "yes" ]]; then
    # Іконка вимкненого звуку
    icon=$(printf "\uf026")
    dunstify -a "Volume" -r "$ID_VOL" -u low "$icon Звук вимкнено"
else
    # Вибір іконки залежно від гучності
    if [ "$new_vol" -le 30 ]; then icon=$(printf "\uf026");
    elif [ "$new_vol" -le 70 ]; then icon=$(printf "\uf027");
    else icon=$(printf "\uf028"); fi

    # Вивід: Іконка з відсотками в заголовку + графічний бар
    dunstify -a "Volume" \
             -u low \
             -r "$ID_VOL" \
             -h "int:value:$new_vol" \
             -h "string:hlcolor:$COLOR_CYAN" \
             "$icon $new_vol%"
fi

pkill -RTMIN+1 i3blocks
