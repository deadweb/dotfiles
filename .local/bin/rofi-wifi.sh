#!/usr/bin/env bash
# Rofi Script Mode Wi-Fi Menu (cached + power control)

CACHE_FILE="/tmp/wifi_list.txt"
NMCLI_FIELDS="SECURITY,SSID"
THEME="~/.config/rofi/themes/default.rasi"

update_cache() {
    notify-send "Wi-Fi" "Оновлення списку мереж..."
    nmcli --fields "$NMCLI_FIELDS" device wifi list | sed 1d | sed 's/  */ /g' \
        | sed -E "s/WPA*.?\S/ /g" | sed "s/^--/ /g" \
        | sed "s/  //g" | sed "/--/d" | awk '!seen[$0]++' > "$CACHE_FILE"
    notify-send "Wi-Fi" "Список оновлено"
}

wifi_status() {
    nmcli radio wifi
}

toggle_wifi() {
    if [ "$(wifi_status)" = "enabled" ]; then
        nmcli radio wifi off && notify-send "Wi-Fi" "Wi-Fi вимкнено"
    else
        nmcli radio wifi on && notify-send "Wi-Fi" "Wi-Fi увімкнено"
        update_cache
    fi
}

# --- Відображення списку ---
if [ -z "$1" ]; then
    [ ! -f "$CACHE_FILE" ] && update_cache

    status="$(wifi_status)"
    if [ "$status" = "enabled" ]; then
        echo " Вимкнути Wi-Fi"
        echo " Оновити список мереж"
        cat "$CACHE_FILE"
    else
        echo " Увімкнути Wi-Fi"
    fi
    exit
fi

# --- Обробка вибору ---
case "$1" in
    " Вимкнути Wi-Fi") toggle_wifi; exit ;;
    " Увімкнути Wi-Fi") toggle_wifi; exit ;;
    " Оновити список") update_cache; exit ;;
esac

chosen_id="${1:3}"
[ -z "$chosen_id" ] && exit

saved_connections=$(nmcli -g NAME connection)
success_message="Connected to \"$chosen_id\"."

if echo "$saved_connections" | grep -qw "$chosen_id"; then
    nmcli connection up id "$chosen_id" >/dev/null 2>&1 &&
    notify-send "Wi-Fi Connected" "$success_message"
else
    if [[ "$1" =~ "" ]]; then
        password=$(rofi -dmenu -password -p "Password for $chosen_id:" -theme "$THEME")
    fi
    nmcli device wifi connect "$chosen_id" password "$password" >/dev/null 2>&1 &&
    notify-send "Wi-Fi Connected" "$success_message"
fi
