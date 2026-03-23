#!/bin/zsh

# --- БЕЗПЕЧНЕ ОТРИМАННЯ КЛЮЧІВ ---
TOKEN=$(grep -A 3 "machine dessmonitor.com" ~/.netrc | grep "login" | awk '{print $2}')
SIGN=$(grep -A 3 "machine dessmonitor.com" ~/.netrc | grep "password" | awk '{print $2}')
SALT=$(grep -A 3 "machine dessmonitor.com" ~/.netrc | grep "account" | awk '{print $2}')

URL="https://web.dessmonitor.com/public/?sign=$SIGN&salt=$SALT&token=$TOKEN&action=webQueryDeviceEnergyFlowEs&source=1&devcode=6514&pn=E50000253754058246&devaddr=1&sn=99532509100630"

# Кольори ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

while true; do
    data=$(curl -s -f -A 'Mozilla/5.0' -L "$URL")
    
    if [ $? -ne 0 ] || [ -z "$data" ]; then
        clear
        printf "${RED}ПОМИЛКА МЕРЕЖІ${NC}\n"
        sleep 10
        continue
    fi

    # Дані через jq
    LOAD_KW=$(echo "$data" | jq -r '.dat.bc_status[] | select(.par == "load_active_power") | .val // 0' | head -1)
    BAT_PERC=$(echo "$data" | jq -r '.dat.bt_status[] | select(.par == "bt_battery_capacity") | .val // 0' | head -1)
    BAT_PWR_KW=$(echo "$data" | jq -r '.dat.bt_status[] | select(.par == "battery_active_power") | .val // 0' | head -1)
    GRID_KW=$(echo "$data" | jq -r '.dat.gd_status[] | select(.par == "grid_active_power") | .val // 0' | head -1)

    # Математика через awk
    LOAD_W=$(awk "BEGIN { v = $LOAD_KW * 1000; printf \"%d\", (v < 0 ? -v : v) }")
    BAT_W=$(awk "BEGIN { printf \"%d\", $BAT_PWR_KW * 1000 }")
    GRID_W=$(awk "BEGIN { printf \"%d\", $GRID_KW * 1000 }")
    BAT_PERC_INT=$(awk "BEGIN { printf \"%d\", $BAT_PERC }")

    clear
    # Заголовок
    printf "${CYAN}================ [ СТАТУС ІНВЕРТОРА ] ================${NC}\n"
    printf "  Оновлено: %s\n" "$(date +'%H:%M:%S')"
    printf "------------------------------------------------------\n"
    
    # Дані
    printf "  СПОЖИВАННЯ:      ${WHITE}%s W${NC}\n" "$LOAD_W"
    
    # Колір батареї
    if [ "$BAT_PERC_INT" -lt 30 ]; then
        printf "  ЗАРЯД БАТАРЕЇ:   ${RED}%s %%${NC}\n" "$BAT_PERC_INT"
    elif [ "$BAT_PERC_INT" -lt 70 ]; then
        printf "  ЗАРЯД БАТАРЕЇ:   ${YELLOW}%s %%${NC}\n" "$BAT_PERC_INT"
    else
        printf "  ЗАРЯД БАТАРЕЇ:   ${GREEN}%s %%${NC}\n" "$BAT_PERC_INT"
    fi

    # Режим роботи
    printf "  РЕЖИМ РОБОТИ:    "
    if [ "$BAT_W" -lt -5 ]; then
        ABS_BAT=$(awk "BEGIN { v = $BAT_W; printf \"%d\", (v < 0 ? -v : v) }")
        printf "${RED}РОЗРЯДЖАННЯ (↓%sW)${NC}\n" "$ABS_BAT"
    elif [ "$BAT_W" -gt 5 ]; then
        printf "${YELLOW}ЗАРЯДЖАННЯ (↑%sW)${NC}\n" "$BAT_W"
    else
        printf "${CYAN}МЕРЕЖА${NC}\n"
    fi

    printf "  МЕРЕЖА:          ${CYAN}%s W${NC}\n" "$GRID_W"
    
    if [ "$BAT_PERC_INT" -lt 20 ]; then
        printf "------------------------------------------------------\n"
        printf "${RED}  [!] УВАГА: НИЗЬКИЙ ЗАРЯД${NC}\n"
    fi

    # Нижня лінія
    printf "${CYAN}======================================================${NC}\n"

    sleep 60
done
