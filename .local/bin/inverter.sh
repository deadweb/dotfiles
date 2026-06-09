#!/bin/zsh

# --- НАЛАШТУВАННЯ ---
LOG_FILE="$HOME/.local/bin/inverter_data.log"
MAX_TIME=1440 

# Кольори
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; 
CYAN='\033[0;36m'; WHITE='\033[1;37m'; GREY='\033[0;90m'; NC='\033[0m'

# Словник символів Брайля
typeset -A b
b[00]=" " b[01]="⢀" b[02]="⠠" b[03]="⠰" b[04]="⠇"
b[10]="⡀" b[11]="⣀" b[12]="⡠" b[13]="⡰" b[14]="⡇"
b[20]="⠄" b[21]="⢄" b[22]="⠤" b[23]="⠴" b[24]="⠧"
b[30]="⠆" b[31]="⢆" b[32]="⠦" b[33]="⠿" b[34]="⠷"
b[40]="⡆" b[41]="⣄" b[42]="⣦" b[43]="⣶" b[44]="⣿"

draw_line() {
    local char=$1; local title=$2; local width=$(tput cols)
    if [[ -n "$title" ]]; then
        local title_len=${#title}
        local side_len=$(( (width - title_len - 2) / 2 ))
        local side_str=$(printf "%${side_len}s" | tr ' ' "$char")
        printf "${CYAN}%s${NC} %s ${CYAN}%s${NC}" "$side_str" "$title" "$side_str"
        [[ $(( (side_len * 2) + title_len + 2 )) -lt $width ]] && printf "${CYAN}%s${NC}" "$char"
        printf "\n"
    else
        printf "${CYAN}%${width}s${NC}\n" | tr ' ' "$char"
    fi
}

trap "tput cnorm; exit" INT TERM; tput civis

while true; do
    TERM_WIDTH=$(tput cols)
    GRAPH_WIDTH=$(( TERM_WIDTH - 10 ))
    POINTS_NEEDED=$(( GRAPH_WIDTH * 2 ))

    raw_data=$(tail -n $MAX_TIME "$LOG_FILE" 2>/dev/null)
    [[ -z "$raw_data" ]] && { clear; printf "Очікування даних...\n"; sleep 60; continue }

    TOTAL_LOG_LINES=$(echo "$raw_data" | wc -l)
    STEP=$(awk -v total=$TOTAL_LOG_LINES -v need=$POINTS_NEEDED 'BEGIN {print total/need}')
    
    pwr_history=($(echo "$raw_data" | awk -v s=$STEP -v n=$POINTS_NEEDED 'BEGIN {for(i=0;i<n;i++) idx[i]=int(i*s+1)} {for(j=0;j<n;j++) if(NR==idx[j]) val[j]=$2} END {for(k=0;k<n;k++) printf "%d ", val[k]}'))
    bat_history=($(echo "$raw_data" | awk -v s=$STEP -v n=$POINTS_NEEDED 'BEGIN {for(i=0;i<n;i++) idx[i]=int(i*s+1)} {for(j=0;j<n;j++) if(NR==idx[j]) val[j]=$4} END {for(k=0;k<n;k++) printf "%d ", val[k]}'))
    time_history=($(echo "$raw_data" | awk -v s=$STEP -v n=$POINTS_NEEDED 'BEGIN {for(i=0;i<n;i++) idx[i]=int(i*s+1)} {for(j=0;j<n;j++) if(NR==idx[j]) val[j]=$1} END {for(k=0;k<n;k++) printf "%s ", val[k]}'))

    last_row=$(echo "$raw_data" | tail -n 1)
    read last_time last_pwr last_soc last_bat_p <<< $(echo "$last_row" | awk '{print $1, $2, $3, $4}')
    
    MAX_PWR=1; for i in $pwr_history; do [[ ${i#-} -gt $MAX_PWR ]] && MAX_PWR=${i#-}; done
    MAX_BAT=1; for i in $bat_history; do val=${i#-}; [[ $val -gt $MAX_BAT ]] && MAX_BAT=$val; done
    [[ $MAX_PWR -lt 4 ]] && MAX_PWR=4; [[ $MAX_BAT -lt 4 ]] && MAX_BAT=4

    if [[ $last_bat_p -lt -5 ]]; then BS="${RED}РОЗРЯД (↓${last_bat_p#-}W)${NC}"
    elif [[ $last_bat_p -gt 5 ]]; then BS="${YELLOW}ЗАРЯД (↑${last_bat_p}W)${NC}"
    else BS="${CYAN}МЕРЕЖА${NC}"; fi

    clear
    draw_line "=" "МОНІТОР ІНВЕРТОРА"
    printf " %s | АКБ: ${GREEN}%s %%${NC} | %b | Навантаження: ${WHITE}%s W${NC}\n" "${last_time:0:5}" "$last_soc" "$BS" "$last_pwr"
    draw_line "-" ""

    for ((h=2; h>=1; h--)); do
        LABEL=$(( MAX_PWR * h / 2 ))
        printf "%5sW │ " "$LABEL"
        row_str=""
        for ((i=1; i<=POINTS_NEEDED; i+=2)); do
            v1=${pwr_history[$i]}; v2=${pwr_history[$((i+1))]}
            ty1=$(( v1 * 8 / MAX_PWR )); ty2=$(( v2 * 8 / MAX_PWR ))
            r_start=$(( (h-1) * 4 ))
            p1=$(( ty1 - r_start )); [[ $p1 -lt 0 ]] && p1=0; [[ $p1 -gt 4 ]] && p1=4
            p2=$(( ty2 - r_start )); [[ $p2 -lt 0 ]] && p2=0; [[ $p2 -gt 4 ]] && p2=4
            row_str+="${b[$p1$p2]}"
        done
        echo -e "${GREEN}${row_str}${NC}"
    done

    printf "    0W ├"
    printf "─%.0s" {1..$GRAPH_WIDTH}
    printf "\n"

    for ((h=1; h<=2; h++)); do
        LABEL=$(( MAX_BAT * h / 2 ))
        printf "%5sW │ " "-$LABEL"
        printf " "
        for ((i=1; i<=POINTS_NEEDED; i+=2)); do
            v1=${bat_history[$i]}; v2=${bat_history[$((i+1))]}
            if [[ $v1 -eq 0 && $v2 -eq 0 ]]; then printf " "; continue; fi
            if [[ $v1 -lt 0 || $v2 -lt 0 ]]; then color=$RED; else color=$YELLOW; fi
            
            ty1=$(( v1 * 8 / MAX_BAT )); ty2=$(( v2 * 8 / MAX_BAT ))
            r_start=$(( (2-h) * 4 ))
            p1=$(( ty1 + r_start )); p2=$(( ty2 + r_start ))
            
            p1_abs=$(( p1 < 0 ? -p1 : p1 )); [[ $p1_abs -gt 4 ]] && p1_abs=4
            p2_abs=$(( p2 < 0 ? -p2 : p2 )); [[ $p2_abs -gt 4 ]] && p2_abs=4
            
            printf "${color}${b[$p1_abs$p2_abs]}${NC}"
        done
        printf "\n"
    done
    
    printf "       "
    for ((i=0; i<GRAPH_WIDTH; i+=20)); do 
        idx=$(( i * 2 + 1 ))
        printf "%-20s" "${time_history[$idx]:0:5}" 
    done
    printf "\n"
    draw_line "=" ""
    sleep 60
done
