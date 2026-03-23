#!/bin/zsh

# --- НАЛАШТУВАННЯ ---
LOG_FILE="$HOME/.local/bin/inverter_data.log"
MAX_TIME=1440  # 24 години

# Кольори
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; 
CYAN='\033[0;36m'; WHITE='\033[1;37m'; GREY='\033[0;90m'; NC='\033[0m'

get_line_dot() {
    local y1=$1 y2=$2
    local code=10240
    [[ $y1 -eq 1 ]] && ((code += 1))
    [[ $y1 -eq 2 ]] && ((code += 2))
    [[ $y1 -eq 3 ]] && ((code += 4))
    [[ $y1 -eq 4 ]] && ((code += 64))
    [[ $y2 -eq 1 ]] && ((code += 8))
    [[ $y2 -eq 2 ]] && ((code += 16))
    [[ $y2 -eq 3 ]] && ((code += 32))
    [[ $y2 -eq 4 ]] && ((code += 128))
    printf "\\u$(printf '%x' $code)"
}

draw_line() {
    local char=$1; local title=$2; local width=$(tput cols)
    if [[ -n "$title" ]]; then
        local title_len=${#title}
        local side_len=$(( (width - title_len - 2) / 2 ))
        printf "${CYAN}"
        printf '%.0s'$char {1..$side_len}
        printf "${NC} %s ${CYAN}" "$title"
        printf '%.0s'$char {1..$side_len}
        printf "${NC}\n"
    else
        printf "${CYAN}"
        printf '%.0s'$char {1..$width}
        printf "${NC}\n"
    fi
}

trap "tput cnorm; exit" INT TERM; tput civis

while true; do
    TERM_WIDTH=$(tput cols)
    
    TOTAL_IN_LOG=$(wc -l < "$LOG_FILE")
    [[ $TOTAL_IN_LOG -gt $MAX_TIME ]] && DATA_LIMIT=$MAX_TIME || DATA_LIMIT=$TOTAL_IN_LOG
    
    SCREEN_CAPACITY=$(( (TERM_WIDTH - 12) * 2 ))
    STEP=$(( DATA_LIMIT / SCREEN_CAPACITY ))
    [[ $STEP -lt 1 ]] && STEP=1

    raw_data=$(tail -n $DATA_LIMIT "$LOG_FILE")
    [[ -z "$raw_data" ]] && { clear; printf "Очікування даних...\n"; sleep 60; continue }

    pwr_history=($(echo "$raw_data" | awk -v step=$STEP '{sum+=$2; count++} count==step {printf "%d ", sum/count; sum=0; count=0}'))
    time_history=($(echo "$raw_data" | awk -v step=$STEP 'NR%step==0 {print $1}'))
    
    last_row=$(echo "$raw_data" | tail -n 1)
    last_time=$(echo "$last_row" | awk '{print $1}')
    last_pwr=$(echo "$last_row" | awk '{print $2}')
    last_soc=$(echo "$last_row" | awk '{print $3}')
    last_bat_p=$(echo "$last_row" | awk '{print $4}')
    
    ACTUAL_POINTS=${#pwr_history[@]}

    MAX_VAL=0; MIN_VAL=99999
    for i in $pwr_history; do [[ $i -gt $MAX_VAL ]] && MAX_VAL=$i; [[ $i -lt $MIN_VAL ]] && MIN_VAL=$i; done
    
    RANGE=$((MAX_VAL - MIN_VAL))
    if [[ $RANGE -lt 4 ]]; then
        MAX_VAL=$((MAX_VAL + (4 - RANGE)))
        RANGE=4
    fi
    while [[ $((RANGE % 4)) -ne 0 ]]; do ((MAX_VAL++)); RANGE=$((MAX_VAL - MIN_VAL)); done

    [[ $last_bat_p -lt -5 ]] && BS="${RED}РОЗРЯД (↓${last_bat_p#-}W)${NC}" || { [[ $last_bat_p -gt 5 ]] && BS="${YELLOW}ЗАРЯД (↑${last_bat_p}W)${NC}" || BS="${CYAN}МЕРЕЖА${NC}" }

    clear
    draw_line "=" "МОНІТОР ІНВЕРТОРА"
    printf " %s | АКБ: ${GREEN}%s %%${NC} | %b | Споживання: ${WHITE}%s W${NC}\n" "$last_time" "$last_soc" "$BS" "$last_pwr"
    draw_line "-" ""

    PLOT_ROWS=4
    for ((h=PLOT_ROWS; h>=1; h--)); do
        LABEL=$(( MIN_VAL + (RANGE * h / PLOT_ROWS) ))
        printf "%5sW │ " "$LABEL"
        
        for ((i=1; i<=$ACTUAL_POINTS; i+=2)); do
            v1=${pwr_history[$i]}; v2=${pwr_history[$((i+1))]}; [[ -z "$v2" ]] && v2=$v1
            ty1=$(( (v1 - MIN_VAL) * (PLOT_ROWS * 4) / RANGE ))
            ty2=$(( (v2 - MIN_VAL) * (PLOT_ROWS * 4) / RANGE ))
            r_start=$(( (h - 1) * 4 )); r_end=$(( h * 4 ))

            p1=0; p2=0
            [[ $ty1 -gt $r_start && $ty1 -le $r_end ]] && p1=$(( ty1 - r_start ))
            [[ $ty2 -gt $r_start && $ty2 -le $r_end ]] && p2=$(( ty2 - r_start ))

            if [[ $p1 -eq 0 && $p2 -eq 0 ]]; then
                [[ ($ty1 -gt $r_end && $ty2 -le $r_start) || ($ty1 -le $r_start && $ty2 -gt $r_end) ]] && printf "${GREEN}┃${NC}" || printf " "
            else
                echo -ne "${GREEN}$(get_line_dot $p1 $p2)${NC}"
            fi
        done
        printf "\n"
    done

    printf "%5sW └" "$MIN_VAL"
    printf '─%.0s' {1..$((ACTUAL_POINTS / 2))}
    printf "\n       "
    
    for ((i=1; i<=$ACTUAL_POINTS; i+=2)); do
        if [[ $(( (i-1) % 40 )) -eq 0 ]]; then
            T_LABEL=${time_history[$i]}
            if [[ -n "$T_LABEL" ]]; then
                printf "${GREY}▲${NC}${T_LABEL:0:5}"
                i=$(( i + 10 ))
            fi
        else
            printf " "
        fi
    done
    printf "\n"
    draw_line "=" ""
    sleep 60
done
