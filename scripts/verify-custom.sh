#!/bin/bash
# Hardware integration check for this Mac only; leaves balance mode selected.
set -euo pipefail
export LC_ALL=C
BASE='/Library/Application Support/FYQMac'
REQ='/Users/skyfu/Library/Application Support/FYQMacControl/request'
readreg() { "$BASE/voltageshift" read "$1" | /usr/bin/perl -ne 'if(/\(([01 ]+)\)/){$b=$1;$b=~s/ //g;print unpack("H16",pack("B64",$b)),"\n" if length($b)==64}'; }
submit() {
 id=$(/usr/bin/uuidgen)
 printf '%s\n%s\n' "$1" "$id" > "${REQ}.tmp"; mv "${REQ}.tmp" "$REQ"
 for n in {1..20}; do [ "$(cat "$BASE/request-id.txt" 2>/dev/null)" != "$id" ] || return 0; sleep 1; done
 echo 'No backend acknowledgement'; return 1
}
original=$(perl -ne 'if(/\(([01 ]+)\)/){$b=$1;$b=~s/ //g;print unpack("H16",pack("B64",$b)),"\n"}' "$BASE/original-msr610.txt")
origTurbo=$(perl -ne 'if(/\(([01 ]+)\)/){$b=$1;$b=~s/ //g;print unpack("H16",pack("B64",$b)),"\n"}' "$BASE/original-msr1a0.txt")
for spec in '30 40 0 1' '50 64 1 4'; do
 submit "custom $spec"
 grep -q '已回读验证' "$BASE/status.txt"
 read -r -a fields <<< "$spec"
 actual=$(readreg 610); turbo=$(readreg 1a0)
 target=$(perl "$BASE/power-policy.pl" target "$original" custom "${fields[@]}")
 [ "$actual" = "$target" ]
 [ "$(perl -e 'print((hex($ARGV[0])&(1<<38))?0:1)' "$turbo")" = "${fields[2]}" ]
 printf 'custom %s: PASS\n' "$spec"
 submit reapply; [ "$(readreg 610)" = "$target" ]; echo 'persist/reapply: PASS'
done
previous=$(readreg 610); previousTurbo=$(readreg 1a0)
submit 'custom 393 393 1 0'
grep -q '超出范围' "$BASE/status.txt"
[ "$(readreg 610)" = "$previous" ]; [ "$(readreg 1a0)" = "$previousTurbo" ]; echo 'invalid request unchanged: PASS'
submit refresh; [ "$(readreg 610)" = "$previous" ]; echo 'read-only refresh: PASS'
submit original; [ "$(readreg 610)" = "$original" ]; [ "$(readreg 1a0)" = "$origTurbo" ]; echo 'exact original restore: PASS'
submit 'custom 40 48 1 0'
grep -q '已回读验证' "$BASE/status.txt"
submit balance
grep -q '已回读验证' "$BASE/status.txt"
[ "$(readreg 610)" = "$(perl "$BASE/power-policy.pl" target "$original" balance)" ]
echo 'final balance 5/6W: PASS'
