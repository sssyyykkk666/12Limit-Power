#!/bin/bash
# Fixed profiles only. No user-controlled commands, paths, voltage or raw registers.
set -euo pipefail
export LC_ALL=C
BASE='/Library/Application Support/FYQMac'
REQUEST='/Users/skyfu/Library/Application Support/FYQMacControl/request'
cd "$BASE"
exec >> "$BASE/controller.log" 2>&1
status() { printf '%s\n' "$1" > "$BASE/status.tmp"; chmod 644 "$BASE/status.tmp"; mv "$BASE/status.tmp" "$BASE/status.txt"; }
trap 'status "应用失败，请查看诊断日志"' ERR
if ! /usr/sbin/ioreg -r -c VoltageShiftAnVMSR | /usr/bin/grep -q VoltageShiftAnVMSR; then
  if ! /usr/bin/kextutil -q "$BASE/VoltageShift.kext"; then
    status '驱动待批准：请在隐私与安全性允许 VoltageShift，然后重启'
    exit 0
  fi
fi
readreg() {
  "$BASE/voltageshift" read "$1" | /usr/bin/perl -ne 'if (/\(([01 ]+)\)/) { $b=$1; $b=~s/ //g; if(length($b)==64) { print unpack("H16",pack("B64",$b)),"\n"; }}'
}
if [ ! -f "$BASE/baseline.plist" ]; then
  model=$(/usr/sbin/sysctl -n hw.model)
  [ "$model" = MacBook10,1 ] || { status '机型不符，停止应用'; exit 0; }
  power=$(readreg 610); turbo=$(readreg 1a0); units=$(readreg 606)
  [[ "$power" =~ ^[a-f0-9]{16}$ && "$turbo" =~ ^[a-f0-9]{16}$ && "$units" =~ ^[a-f0-9]{16}$ ]] || { status '寄存器读取失败，未修改设置'; exit 0; }
  unit=$(/usr/bin/perl -e 'print hex($ARGV[0]) & 15' "$units")
  [ "$unit" = 3 ] || { status '功耗单位不符，未修改设置'; exit 0; }
  "$BASE/voltageshift" info > "$BASE/original-info.txt"
  /usr/bin/defaults write "$BASE/baseline" power -string "$power"
  /usr/bin/defaults write "$BASE/baseline" turbo -string "$turbo"
  chmod 600 "$BASE/baseline.plist"
fi
profile=balance
[ ! -f "$BASE/selected.txt" ] || profile=$(cat "$BASE/selected.txt")
if [ -f "$REQUEST" ] && [ ! -L "$REQUEST" ] && [ "$(/usr/bin/stat -f %u "$REQUEST")" = 501 ]; then
  mv "$REQUEST" "$BASE/incoming.request"
  requested=$(/usr/bin/head -n 1 "$BASE/incoming.request")
  rm -f "$BASE/incoming.request"
  case "$requested" in balance|quiet|original) profile=$requested;; esac
fi
case "$profile" in balance|quiet|original) ;; *) profile=original;; esac
original=$(/usr/bin/defaults read "$BASE/baseline" power)
originalTurbo=$(/usr/bin/defaults read "$BASE/baseline" turbo)
# RAPL on this verified machine uses 1/8 W. Preserve every non-power-limit bit.
# Never raise a limit above the saved baseline.
target=$(/usr/bin/perl -e '
  $v=hex($ARGV[0]); $mode=$ARGV[1];
  if($mode ne "original") {
    $a=$v & 0x7fff; $b=($v>>32)&0x7fff;
    $a=40 if $a>40; $cap=$mode eq "quiet" ? 40 : 48; $b=$cap if $b>$cap;
    $v=($v & ~0x7fff00007fff) | $a | ($b<<32);
  }
  printf "%016x",$v;
' "$original" "$profile")
turbo=1
[ "$profile" != quiet ] || turbo=0
if [ "$profile" = original ]; then turbo=$(/usr/bin/perl -e 'print((hex($ARGV[0]) & (1<<38)) ? 0 : 1)' "$originalTurbo"); fi
"$BASE/voltageshift" write 610 "$target"
"$BASE/voltageshift" turbo "$turbo"
actual=$(readreg 610); actualTurbo=$(readreg 1a0)
actualEnabled=$(/usr/bin/perl -e 'print((hex($ARGV[0]) & (1<<38)) ? 0 : 1)' "$actualTurbo")
if [ "$actual" != "$target" ] || [ "$actualEnabled" != "$turbo" ]; then
  status '设置未通过回读验证，未保存为成功状态'
  exit 0
fi
printf '%s\n' "$profile" > "$BASE/selected.txt"
chmod 644 "$BASE/selected.txt"
limits=$(/usr/bin/perl -e 'printf "PL1 %.3gW / PL2 %.3gW",(hex($ARGV[0])&0x7fff)/8,((hex($ARGV[0])>>32)&0x7fff)/8' "$actual")
case "$profile" in balance) title='平衡';; quiet) title='节能';; original) title='原始设置';; esac
status "$title · $limits · 睿频 $turbo（已回读验证）"
"$BASE/voltageshift" info > "$BASE/current-info.txt"
chmod 644 "$BASE/current-info.txt"
