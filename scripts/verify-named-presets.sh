#!/bin/bash
# Integration test on this installation; preserve saved definitions and selected profile.
set -euo pipefail
BASE='/Library/Application Support/FYQMac'
REQ='/Users/skyfu/Library/Application Support/FYQMacControl/request'
readreg() { "$BASE/voltageshift" read "$1" | /usr/bin/perl -ne 'if(/\(([01 ]+)\)/){$b=$1;$b=~s/ //g;print unpack("H16",pack("B64",$b)),"\n" if length($b)==64}'; }
submit() {
 local id=$(/usr/bin/uuidgen)
 printf '%s\n%s\n' "$1" "$id" > "${REQ}.tmp"; mv "${REQ}.tmp" "$REQ"
 for n in {1..20}; do [ "$(cat "$BASE/request-id.txt" 2>/dev/null)" != "$id" ] || return 0; sleep 1; done
 echo 'No backend acknowledgement'; return 1
}
savedBalance=$(cat "$BASE/preset-balance.txt" 2>/dev/null || printf '40 48 1 0')
savedQuiet=$(cat "$BASE/preset-quiet.txt" 2>/dev/null || printf '40 40 0 0')
savedProfile=$(cat "$BASE/selected.txt")
savedCustom=$(cat "$BASE/custom.txt" 2>/dev/null || printf '40 48 1 0')
restore() {
 submit "save balance $savedBalance"; submit "save quiet $savedQuiet"
 if [ "$savedProfile" = custom ]; then submit "custom $savedCustom"; else submit "$savedProfile"; fi
}
trap restore EXIT
original=$(/usr/bin/perl -ne 'if(/\(([01 ]+)\)/){$b=$1;$b=~s/ //g;print unpack("H16",pack("B64",$b)),"\n"}' "$BASE/original-msr610.txt")
before=$(readreg 610); beforeTurbo=$(readreg 1a0)
submit 'save quiet 32 40 0 1'; /usr/bin/grep -q '当前硬件设置未改变' "$BASE/status.txt"
submit 'save balance 40 48 1 8'; /usr/bin/grep -q '当前硬件设置未改变' "$BASE/status.txt"
[ "$(readreg 610)" = "$before" ]; [ "$(readreg 1a0)" = "$beforeTurbo" ]
echo 'save separate definitions without changing hardware: PASS'
for slot in quiet balance; do
 submit "$slot"; /usr/bin/grep -q '已回读验证' "$BASE/status.txt"
 read -r -a fields <<< "$(cat "$BASE/preset-$slot.txt")"
 target=$(perl "$BASE/power-policy.pl" target "$original" custom "${fields[@]}")
 [ "$(readreg 610)" = "$target" ]
 [ "$(perl -e 'print((hex($ARGV[0])&(1<<38))?0:1)' "$(readreg 1a0)")" = "${fields[2]}" ]
 submit reapply; [ "$(readreg 610)" = "$target" ]
 echo "$slot power/turbo/averaging time and reapply: PASS"
done
submit 'preset quiet 36 40 1 4'; /usr/bin/grep -q '已回读验证' "$BASE/status.txt"
[ "$(cat "$BASE/preset-quiet.txt")" = '36 40 1 4' ]
echo 'apply and persist edited named profile: PASS'
before=$(readreg 610)
submit 'save balance 29 40 0 1'; /usr/bin/grep -q '超出范围' "$BASE/status.txt"
[ "$(readreg 610)" = "$before" ]; [ "$(cat "$BASE/preset-balance.txt")" = '40 48 1 8' ]
echo 'invalid definition rejected without changes: PASS'
restore; trap - EXIT
/usr/bin/grep -q '已回读验证' "$BASE/status.txt"
echo 'original saved profiles and selection restored: PASS'
