#!/usr/bin/env bash

raw_json=$(makoctl history -j)

if [[ -z "$raw_json" ]] || [[ $(echo "$raw_json" | jq '. | length') -eq 0 ]]; then
    echo " Notification history is empty!" | rofi -dmenu -i -p " History" -l 3 -markup-rows
    exit 0
fi

selected_input=$( (echo "<span foreground='#c90000' weight='black'> 󰃢  [ Clear All History ] 󰃢 </span>"; echo "$raw_json" | jq -r '
.[] |
"\(.summary // ""): \(.body // "" | gsub("\n"; " "))"
') | rofi -dmenu -i -p " History" -l 10 -format i -markup-rows)

if [[ -z "$selected_input" ]]; then
    exit 0
fi

if [[ "$selected_input" -eq 0 ]]; then
    rm -f ~/.local/share/mako/history 2>/dev/null
    systemctl --user reload mako 2>/dev/null || pkill -HUP mako
    exec "$0"
fi

index=$((selected_input - 1))

# Dùng \x01 (SOH) làm separator - an toàn tuyệt đối với mọi nội dung text
notification_data=$(echo "$raw_json" | jq -r --argjson idx "$index" '
    .[$idx] | 
    "\(.id)\u0001\(.["app-name"] // "System")\u0001\(.urgency // "normal")\u0001\(.summary // "")\u0001\(.body // "")"
')

IFS=$'\x01' read -r id app urgency summary body <<< "$notification_data"

detail_text=" <span foreground='#89b4fa'><b>App:</b></span> <span foreground='#ffffff'><b>$app</b></span> |  <span foreground='#f9e2af'><b>Urgency:</b></span> <span foreground='#ffffff'><b>$urgency</b></span>
----------------------------------------
 <span foreground='#a6e3a1'><b>Summary:</b></span>
<span foreground='#ffffff'>$summary</span>
󰚢 <span foreground='#89dceb'><b>Body:</b></span>
<span foreground='#cdd6f4'>$body</span>"

rofi -e "$detail_text" -markup

action=$(echo -e "󱐋   Invoke\n   Remove\n   Back" | rofi -dmenu -i -p "Action" -l 3)

case "$action" in
    "󱐋   Invoke")
        makoctl invoke -n "$id" 2>/dev/null || makoctl restore -n "$id"
        ;;
    "   Remove")
        makoctl dismiss -n "$id" 2>/dev/null
        ;;
    "    Back")
        ;;
esac

exec "$0"
