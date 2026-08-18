#!/usr/bin/env bash

HISTORY_FILE="$HOME/.local/share/mako/history"
IGNORED_FILE="$HOME/.local/share/mako/rofi-ignored-history"

mkdir -p "$(dirname "$IGNORED_FILE")"
touch "$IGNORED_FILE"

# ============================================================
# Load Mako history
# ============================================================

raw_json=$(makoctl history -j 2>/dev/null)

if [[ -z "$raw_json" ]] || [[ $(echo "$raw_json" | jq '. | length') -eq 0 ]]; then
    echo "   Notification history is empty!" |
        rofi -dmenu -i -p " History" -l 3 -markup-rows
    exit 0
fi

# ============================================================
# Filter notifications that were manually removed
# ============================================================

ignored_json=$(jq -Rsc '
    split("\n")
    | map(select(length > 0))
' "$IGNORED_FILE")

filtered_json=$(echo "$raw_json" |
    jq --argjson ignored "$ignored_json" '
        map(
            select(
                (.id | tostring) as $id
                | ($ignored | index($id))
                | not
            )
        )
    ')

# ============================================================
# Check if everything was removed
# ============================================================

if [[ $(echo "$filtered_json" | jq 'length') -eq 0 ]]; then
    echo " Notification history is empty!" |
        rofi -dmenu \
            -i \
            -p " History" \
            -l 3 \
            -markup-rows

    exit 0
fi
# ============================================================
# Build Rofi list
# ============================================================

selected_input=$(
    (
        echo "<span foreground='#c90000' weight='black'> 󰃢  [ Clear All History ] 󰃢 </span>"

        echo "$filtered_json" |
            jq -r '
                .[] |
                "\(.summary // ""): \(.body // "" | gsub("\n"; " "))"
            '
    ) |
    rofi -dmenu \
        -i \
        -p " History" \
        -l 10 \
        -format i \
        -markup-rows
)

# User pressed ESC
if [[ -z "$selected_input" ]]; then
    exit 0
fi

# ============================================================
# Clear ALL
# ============================================================

if [[ "$selected_input" -eq 0 ]]; then

    # Forget all manually removed IDs
    : > "$IGNORED_FILE"

    # Delete Mako's persistent history
    rm -f "$HISTORY_FILE" 2>/dev/null

    # Clear currently displayed notifications too
    makoctl dismiss -a 2>/dev/null

    # Reload Mako
    systemctl --user reload mako 2>/dev/null ||
        pkill -HUP mako 2>/dev/null

    exec "$0"
fi

# ============================================================
# Convert Rofi index to filtered JSON index
# ============================================================

index=$((selected_input - 1))

# ============================================================
# Extract selected notification
# ============================================================

notification_data=$(
    echo "$filtered_json" |
        jq -r --argjson idx "$index" '
            .[$idx] |
            "\(.id)\u0001\(.["app-name"] // "System")\u0001\(.urgency // "normal")\u0001\(.summary // "")\u0001\(.body // "")"
        '
)

IFS=$'\x01' read -r id app urgency summary body <<< "$notification_data"

# ============================================================
# Detail view
# ============================================================

detail_text=" <span foreground='#89b4fa'><b>App:</b></span> <span foreground='#ffffff'><b>$app</b></span> |  <span foreground='#f9e2af'><b>Urgency:</b></span> <span foreground='#ffffff'><b>$urgency</b></span>
----------------------------------------
 <span foreground='#a6e3a1'><b>Summary:</b></span>
<span foreground='#ffffff'>$summary</span>
󰚢 <span foreground='#89dceb'><b>Body:</b></span>
<span foreground='#cdd6f4'>$body</span>"

rofi -e "$detail_text" -markup

# ============================================================
# Actions
# ============================================================

action=$(
    echo -e "󱐋   Invoke\n   Remove\n   Back" |
        rofi -dmenu \
            -i \
            -p "Action" \
            -l 3
)

case "$action" in

    "󱐋   Invoke")
        makoctl invoke -n "$id" 2>/dev/null ||
            makoctl restore -n "$id" 2>/dev/null
        ;;

    "   Remove")
        makoctl dismiss -n "$id" 2>/dev/null
        if ! grep -Fxq "$id" "$IGNORED_FILE"; then
            echo "$id" >> "$IGNORED_FILE"
        fi

        ;;

    "   Back")
        ;;

esac

exec "$0"
