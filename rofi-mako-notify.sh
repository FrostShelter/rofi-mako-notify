#!/usr/bin/env bash

raw_json=$(makoctl history -j)

# 1. Xử lý khi không có thông báo (Làm size cửa sổ to & dễ nhìn hơn)
if [[ -z "$raw_json" ]] || [[ $(echo "$raw_json" | jq '. | length') -eq 0 ]]; then
    echo "🔔 Notification history is empty!" | rofi -dmenu -i -p "🔔 History" -l 3 -markup-rows
    exit 0
fi

# 2. Thêm Pango Markup màu đỏ cho "Clear All History" và bật -markup-rows
selected_input=$( (echo "<span foreground='#f38ba8'><b>🧹 [Clear All History]</b></span>"; echo "$raw_json" | jq -r '
    .[] | 
    "\(.summary // ""): \(.body // "" | gsub("\n"; " "))"
') | rofi -dmenu -i -p "🔔 History" -l 10 -format i -markup-rows)

if [[ -z "$selected_input" ]]; then
    exit 0
fi

if [[ "$selected_input" -eq 0 ]]; then
    total=$(echo "$raw_json" | jq '. | length')
    for ((i=0; i<total; i++)); do
        makoctl restore 2>/dev/null
        makoctl dismiss -h 2>/dev/null
    done
    makoctl dismiss -a -h 2>/dev/null
    exec "$0"
fi

index=$((selected_input - 1))

id=$(echo "$raw_json" | jq -r ".[$index].id")
app=$(echo "$raw_json" | jq -r ".[$index][\"app-name\"] // \"System\"")
summary=$(echo "$raw_json" | jq -r ".[$index].summary // \"\"")
body=$(echo "$raw_json" | jq -r ".[$index].body // \"\"")
urgency=$(echo "$raw_json" | jq -r ".[$index].urgency // \"normal\"")

detail_text="📱 <span foreground='#89b4fa'><b>App:</b></span> <span foreground='#ffffff'><b>$app</b></span> | 📌 <span foreground='#f9e2af'><b>Urgency:</b></span> <span foreground='#ffffff'><b>$urgency</b></span>
----------------------------------------
📝 <span foreground='#a6e3a1'><b>Summary:</b></span>
<span foreground='#ffffff'>$summary</span>

💬 <span foreground='#89dceb'><b>Body:</b></span>
<span foreground='#cdd6f4'>$body</span>"

rofi -e "$detail_text" -markup

action=$(echo -e "⚡ Invoke\n🗑️ Dismiss\n↩️ Back" | \
    rofi -dmenu -i -p "Action" -l 3)

case "$action" in
    "⚡ Invoke")
        makoctl invoke -n "$id" 2>/dev/null || makoctl restore -n "$id"
        exec "$0"
        ;;
    "🗑️ Dismiss")
        makoctl restore -n "$id" 2>/dev/null && makoctl dismiss -n "$id" -h 2>/dev/null
        exec "$0"
        ;;
    "↩️ Back")
        exec "$0"
        ;;
esac