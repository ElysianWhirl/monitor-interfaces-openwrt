#!/bin/sh

# Konfigurasi
TELEGRAM_BOT_TOKEN="your_telegram_bot_token"
CHAT_ID="yout_chat_id"
PING_TARGET="your_host"
PING_COUNT=3
PING_INTERVAL=1
CHECK_INTERVAL=10

# Daftar interface
INTERFACES="macvlan usb0"

# Fungsi untuk mengirim pesan ke bot Telegram
send_telegram_message() {
    message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${message}" >/dev/null
}

# Fungsi utama untuk memantau interface
monitor_interface() {
    interface="$1"
    fail_count=0
    is_connected=true
    start_time=$(date +%s)

    while true; do
        # Ping menggunakan interface spesifik
        if ping -I "$interface" -c "$PING_COUNT" -i "$PING_INTERVAL" "$PING_TARGET" > /dev/null 2>&1; then
            # Ping berhasil, reset penghitung gagal
            fail_count=0

            # Jika sebelumnya tidak terkoneksi, kirim laporan koneksi pulih
            if [ "$is_connected" = false ]; then
                send_telegram_message "Interface ${interface} telah tersambung kembali ke ${PING_TARGET}."
                start_time=$(date +%s) # Reset waktu mulai setelah tersambung
                is_connected=true
            fi
        else
            # Ping gagal, tingkatkan penghitung gagal
            fail_count=$((fail_count + 1))
        fi

        # Jika 3 kali gagal berturut-turut, kirim laporan dan ubah status
        if [ "$fail_count" -ge 3 ] && [ "$is_connected" = true ]; then
            current_time=$(date +%s)
            uptime=$((current_time - start_time))
            hours=$((uptime / 3600))
            minutes=$(( (uptime % 3600) / 60 ))
            seconds=$((uptime % 60))

            # Kirim pesan ke Telegram
            send_telegram_message "Interface ${interface} terputus dari ${PING_TARGET}.
Durasi terkoneksi sebelum terputus: ${hours} jam, ${minutes} menit, ${seconds} detik."

            is_connected=false
        fi

        # Tunggu sebelum iterasi berikutnya
        sleep "$CHECK_INTERVAL"
    done
}

# Memulai pemantauan untuk setiap interface
for interface in $INTERFACES; do
    monitor_interface "$interface" &
done

# Tunggu semua proses selesai (meskipun tidak akan selesai kecuali dihentikan)
wait
