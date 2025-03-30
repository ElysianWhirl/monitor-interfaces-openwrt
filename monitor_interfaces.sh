#!/bin/sh

# Konfigurasi
TELEGRAM_BOT_TOKEN="your_tokenid"
CHAT_ID="your_chatid"
PING_COUNT=3
PING_INTERVAL=1
CHECK_INTERVAL=1
LOG_FILE="/tmp/interface_disconnect_log.txt"

# Daftar interface dan target
INTERFACES="macvlan eth2"
PING_TARGETS="host1 host2"

# Fungsi untuk mengirim pesan ke bot Telegram
send_telegram_message() {
    message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${message}" >/dev/null
}

# Fungsi untuk menulis ke log dengan timestamp
log_to_file() {
    message="$1"
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" >> "$LOG_FILE"
}

# Fungsi utama untuk memantau interface terhadap setiap target
monitor_interface() {
    interface="$1"
    ping_target="$2"
    fail_count=0
    is_connected=true
    start_time=$(date +%s)

    while true; do
        if ping -I "$interface" -c "$PING_COUNT" -i "$PING_INTERVAL" "$ping_target" > /dev/null 2>&1; then
            fail_count=0
            if [ "$is_connected" = false ]; then
                if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
                    while IFS= read -r log_message; do
                        send_telegram_message "$log_message"
                    done < "$LOG_FILE"
                    > "$LOG_FILE"
                fi
                send_telegram_message "Interface ${interface} telah tersambung kembali ke ${ping_target}."
                start_time=$(date +%s)
                is_connected=true
            fi
        else
            fail_count=$((fail_count + 1))
            if [ "$fail_count" -ge 3 ] && [ "$is_connected" = true ]; then
                current_time=$(date +%s)
                uptime=$((current_time - start_time))
                hours=$((uptime / 3600))
                minutes=$(( (uptime % 3600) / 60 ))
                seconds=$((uptime % 60))

                log_message="Interface ${interface} terputus dari ${ping_target}.
Durasi terkoneksi sebelum terputus: ${hours} jam, ${minutes} menit, ${seconds} detik."
                log_to_file "$log_message"
                is_connected=false
            fi
        fi
        sleep "$CHECK_INTERVAL"
    done
}

# Memulai pemantauan untuk setiap kombinasi interface dan target
for interface in $INTERFACES; do
    for ping_target in $PING_TARGETS; do
        monitor_interface "$interface" "$ping_target" &
    done
done

# Tunggu semua proses selesai
wait
