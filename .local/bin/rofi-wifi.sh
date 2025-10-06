#!/usr/bin/env bash

# Rofi Script Mode Wi-Fi Menu

case "$1" in
    "") # --- Початковий виклик: показує список мереж ---
        nmcli --fields "SECURITY,SSID" device wifi list | sed 1d | sed 's/  */ /g' |
        sed -E "s/WPA*.?\S/ /g" | sed "s/^--/ /g" | sed "s/  //g" | sed "/--/d" |
        awk '!seen[$0]++' | awk '{print $0}'
        ;;

    *) # --- Обробка вибраної мережі ---
        chosen_id="${1:3}"
        [ -z "$chosen_id" ] && exit

        saved_connections=$(nmcli -g NAME connection)
        success_message="Connected to \"$chosen_id\"."

        if echo "$saved_connections" | grep -qw "$chosen_id"; then
            nmcli connection up id "$chosen_id" >/dev/null 2>&1 &&
            notify-send "Wi-Fi Connected" "$success_message"
        else
            if [[ "$1" =~ "" ]]; then
                password=$(rofi -dmenu -password -p "Password for $chosen_id:")
            fi
            nmcli device wifi connect "$chosen_id" password "$password" >/dev/null 2>&1 &&
            notify-send "Wi-Fi Connected" "$success_message"
        fi
        ;;
esac
