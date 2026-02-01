#!/bin/bash

API="https://radio.datamosh.ru/api/nowplaying/datamosh_radio"
STREAM="https://radio.datamosh.ru/listen/datamosh_radio/radio.mp3"

G='\033[1;32m'; Y='\033[1;33m'; B='\033[1;34m'; M='\033[1;35m'; W='\033[1;37m'; NC='\033[0m'

playing=true
vlc_pid=""

draw_box() {
    local w=$1 h=$2 x=$3 y=$4
    tput cup $y $x; printf "┌$(printf '─%.0s' $(seq 1 $((w-2))))┐"
    for ((i=1; i<h-1; i++)); do
        tput cup $((y+i)) $x; printf "│% $((w-2))s│" ""
    done
    tput cup $((y+h-1)) $x; printf "└$(printf '─%.0s' $(seq 1 $((w-2))))┘"
}

fmt_time() {
    printf "%02d:%02d" $(( $1 / 60 )) $(( $1 % 60 ))
}

render() {
    local data="$1"

    local listeners=$(echo "$data" | jq -r '.listeners.current // 0')
    local artist=$(echo "$data" | jq -r '.now_playing.song.artist // "???"')
    local title=$(echo "$data" | jq -r '.now_playing.song.title // "???"')
    local elapsed=$(echo "$data" | jq -r '.now_playing.elapsed // 0')
    local duration=$(echo "$data" | jq -r '.now_playing.duration // 0')

    local tw=$(tput cols) th=$(tput lines)
    local w=29 h=10
    local x=$(( (tw - w) / 2 )) y=$(( (th - h) / 2 ))

    [ $tw -lt $w ] && clear && echo "Окно маловато!" && return

    tput clear
    draw_box $w $h $x $y

    tput cup $((y+1)) $((x+2)); printf "${B}datamosh://radio${NC}"
    tput cup $((y+2)) $((x+2)); printf "%.0s─" $(seq 1 $((w-4)))
    
    tput cup $((y+3)) $((x+4)); printf "💿︎  ${Y}${title:0:$((w-10))}${NC}"
    tput cup $((y+4)) $((x+4)); printf "👤︎  ${G}${artist:0:$((w-10))}${NC}"
    
    tput cup $((y+5)) $((x+4))
    $playing && printf "⏸  ${W}Пауза [P]${NC}" || printf "▶  ${W}Старт [P]${NC}"

    tput cup $((y+6)) $((x+4))
    printf "⧗  %s / %s" "$(fmt_time $elapsed)" "$(fmt_time $duration)"
    
    tput cup $((y+7)) $((x+4))
    printf "🎧︎  Слушают: ${M}%d${NC}" $listeners
}

cleanup() {
    tput cnorm; [ -n "$vlc_pid" ] && kill $vlc_pid 2>/dev/null
    clear; echo "Bye!"; exit 0
}

trap cleanup INT TERM

tput civis
cvlc "$STREAM" --quiet >/dev/null 2>&1 &
vlc_pid=$!

while true; do
    json=$(curl -s --max-time 2 "$API")
    render "$json"
    
    read -t 1 -n 1 key
    if [[ $key == "p" || $key == "P" ]]; then
        if $playing; then
            kill -STOP $vlc_pid && playing=false
        else
            kill -CONT $vlc_pid && playing=true
        fi
    fi
done
