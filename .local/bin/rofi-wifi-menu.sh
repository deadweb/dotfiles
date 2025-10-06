#!/usr/bin/env bash

notify-send "Getting list of available Wi-Fi networks..."
# Get a list of available wifi connections and morph it into a nice-looking list
wifi_list=$(nmcli --fields "SECURITY,SSID" device wifi list | sed 1d | sed 's/  */ /g' | sed -E "s/WPA*.?\S/ /g" | sed "s/^--/ /g" | sed "s/  //g" | sed "/--/d")

# Use rofi to select wifi network
chosen_network=$(echo "$wifi_list" | uniq -u | rofi -dmenu -theme ~/.config/rofi/themes/default.rasi -i -selected-row 1 -p "Wi-Fi SSID: " )

# Get name of connection
read -r chosen_id <<< "${chosen_network:3}"

if [ -z "$chosen_network" ]; then
    exit
else
    # Message to show when connection is activated successfully
    success_message="You are now connected to the Wi-Fi network \"$chosen_id\"."
    # Get saved connections
    saved_connections=$(nmcli -g NAME connection)
    if [[ $(echo "$saved_connections" | grep -w "$chosen_id") = "$chosen_id" ]]; then
        nmcli connection up id "$chosen_id" | grep "successfully" && notify-send "Connection Established" "$success_message"
    else
        if [[ "$chosen_network" =~ "" ]]; then
            wifi_password=$(rofi -dmenu -theme ~/.config/rofi/themes/default.rasi -p "Password: " )
        fi
        nmcli device wifi connect "$chosen_id" password "$wifi_password" | grep "successfully" && notify-send "Connection Established" "$success_message"
    fi
fi
