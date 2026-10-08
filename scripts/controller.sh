#!/bin/bash
set -euo pipefail
export LC_ALL=C
BASE='/Library/Application Support/FYQMac'
REQUEST='/Users/skyfu/Library/Application Support/FYQMacControl/request'
cd "$BASE"
exec >> "$BASE/controller.log" 2>&1
requestID=''
status() {
 printf '%s\n' "$1" > status.tmp; chmod 644 status.tmp; mv status.tmp status.txt
 printf '%s\n' "$requestID" > request-id.tmp; chmod 644 request-id.tmp; mv request-id.tmp request-id.txt
}
trap 'status "应用失败，已保留上次成功配置；请查看日志"' ERR
readreg() { "$BASE/voltageshift" read "$1" | /usr/bin/perl -ne 'if(/\(([01 ]+)\)/){$b=$1;$b=~s/ //g;print unpack("H16",pack("B64",$b)),"\n" if length($b)==64}'; }
[ "$(/usr/sbin/sysctl -n hw.model)" = MacBook10,1 ] || { status '机型不符，未修改设置'; exit 0; }
if ! /usr/sbin/ioreg -r -c VoltageShiftAnVMSR | /usr/bin/grep -q VoltageShiftAnVMSR; then
 /usr/bin/kextutil -q "$BASE/VoltageShift.kext" || { status 'VoltageShift 驱动未就绪'; exit 0; }
fi
units=$(readreg 606)
[[ "$units" =~ ^[a-f0-9]{16}$ ]] && [ "$(/usr/bin/perl -e 'printf "%d %d",hex($ARGV[0])&15,(hex($ARGV[0])>>16)&15' "$units")" = '3 10' ] || { status '功耗或时间单位不符，未修改设置'; exit 0; }
[ -f baseline.plist ] || { status '缺少安装前备份，未修改设置'; exit 0; }
original=$(/usr/bin/defaults read "$BASE/baseline" power)
originalTurbo=$(/usr/bin/defaults read "$BASE/baseline" turbo)
/usr/bin/perl "$BASE/power-policy.pl" capabilities "$original" > capabilities.tmp
chmod 644 capabilities.tmp; mv capabilities.tmp capabilities.json
profile=$(cat selected.txt 2>/dev/null || printf balance)
custom=$(cat custom.txt 2>/dev/null || printf '40 48 1 0')
action=$profile
pendingPreset=''
if [ -f "$REQUEST" ] && [ ! -L "$REQUEST" ] && [ "$(/usr/bin/stat -f %u "$REQUEST")" = 501 ]; then
 mv "$REQUEST" incoming.request
 size=$(/usr/bin/stat -f %z incoming.request)
 if [ "$size" -le 256 ]; then
  requested=$(/usr/bin/head -n 1 incoming.request)
  requestID=$(/usr/bin/sed -n '2p' incoming.request)
  [[ "$requestID" =~ ^[A-Za-z0-9-]{1,64}$ ]] || requestID=''
 else requested='invalid'; fi
 rm -f incoming.request
 case "$requested" in
  balance|quiet|original) profile=$requested; action=$requested;;
  refresh) action=refresh;;
  reapply) action=$profile;;
  custom\ *) profile=custom; action=custom; custom=${requested#custom };;
  save\ *|preset\ *)
   if [[ "$requested" =~ ^(save|preset)\ (balance|quiet)\ ([0-9]{1,3})\ ([0-9]{1,3})\ ([01])\ ([0-9]{1,2})$ ]]; then
    read -r operation slot p1 p2 t w <<< "$requested"
    definition="$p1 $p2 $t $w"
    if ! /usr/bin/perl "$BASE/power-policy.pl" target "$original" custom "$p1" "$p2" "$t" "$w" >/dev/null; then status '档位参数超出范围，未保存或修改硬件'; exit 0; fi
    if [ "$operation" = save ]; then
     printf '%s\n' "$definition" > "preset-$slot.tmp"; chmod 644 "preset-$slot.tmp"; mv "preset-$slot.tmp" "preset-$slot.txt"
     case "$slot" in balance) title='平衡';; quiet) title='节能';; esac
     status "${title}档位已保存，当前硬件设置未改变"; exit 0
    fi
    profile=$slot; action=$slot; pendingPreset=$slot; custom=$definition
   else status '档位请求格式无效，未修改设置'; exit 0; fi;;
  *) status '请求格式无效，未修改设置'; exit 0;;
 esac
fi
sample() { "$BASE/voltageshift" info > current-info.tmp; chmod 644 current-info.tmp; mv current-info.tmp current-info.txt; }
writeactual() {
 /usr/bin/perl -MJSON::PP -e '$v=hex($ARGV[0]);print encode_json({pl1=>($v&0x7fff)/8,pl2=>(($v>>32)&0x7fff)/8,turbo=>(hex($ARGV[1])&(1<<38))?JSON::PP::false:JSON::PP::true}),"\n"' "$1" "$2" > actual.tmp
 chmod 644 actual.tmp; mv actual.tmp actual.json
}
if [ "$action" = refresh ]; then
 sample; actual=$(readreg 610); actualTurbo=$(readreg 1a0); writeactual "$actual" "$actualTurbo"
 status '读数已刷新（采样时刻），配置未改动'; exit 0
fi
case "$profile" in balance|quiet|original|custom) ;; *) status '保存配置无效，未修改设置'; exit 0;; esac
args=()
policyMode=$profile
if [ "$profile" = balance ] || [ "$profile" = quiet ]; then
 if [ -z "$pendingPreset" ]; then
  if [ -f "preset-$profile.txt" ]; then custom=$(cat "preset-$profile.txt");
  elif [ "$profile" = balance ]; then custom='40 48 1 0'; else custom='40 40 0 0'; fi
 fi
 policyMode=custom
fi
if [ "$policyMode" = custom ]; then
 [[ "$custom" =~ ^[0-9]{1,3}\ [0-9]{1,3}\ [01]\ [0-9]{1,2}$ ]] || { status '自定义格式无效，未修改设置'; exit 0; }
 read -r -a args <<< "$custom"
fi
if ! target=$(/usr/bin/perl "$BASE/power-policy.pl" target "$original" "$policyMode" ${args[@]+"${args[@]}"}); then
 status '参数超出范围，未修改设置'; exit 0
fi
turbo=1
[ "$profile" != quiet ] || turbo=0
[ "$policyMode" != custom ] || turbo=${args[2]}
if [ "$profile" = original ]; then turbo=$(/usr/bin/perl -e 'print((hex($ARGV[0])&(1<<38))?0:1)' "$originalTurbo"); fi
previous=$(readreg 610); previousTurbo=$(readreg 1a0)
[[ "$previous" =~ ^[a-f0-9]{16}$ && "$previousTurbo" =~ ^[a-f0-9]{16}$ ]] || { status '读取失败，未修改设置'; exit 0; }
rollback() {
 "$BASE/voltageshift" write 610 "$previous" || true
 enabled=$(/usr/bin/perl -e 'print((hex($ARGV[0])&(1<<38))?0:1)' "$previousTurbo")
 "$BASE/voltageshift" turbo "$enabled" || true
 restored=$(readreg 610); restoredTurbo=$(readreg 1a0)
 if [ "$restored" = "$previous" ] && [ "$restoredTurbo" = "$previousTurbo" ]; then status '应用失败，已回退并验证上次硬件设置';
 else status '回退未通过验证，请恢复原始设置并查看日志'; fi
}
trap rollback ERR
"$BASE/voltageshift" write 610 "$target"
"$BASE/voltageshift" turbo "$turbo"
actual=$(readreg 610); actualTurbo=$(readreg 1a0)
actualEnabled=$(/usr/bin/perl -e 'print((hex($ARGV[0])&(1<<38))?0:1)' "$actualTurbo")
if [ "$actual" != "$target" ] || [ "$actualEnabled" != "$turbo" ]; then rollback; exit 0; fi
trap 'status "设置已生效，状态保存失败，请查看日志"' ERR
if [ -n "$pendingPreset" ]; then printf '%s\n' "$custom" > "preset-$pendingPreset.tmp"; chmod 644 "preset-$pendingPreset.tmp"; mv "preset-$pendingPreset.tmp" "preset-$pendingPreset.txt"; fi
printf '%s\n' "$profile" > selected.tmp; chmod 644 selected.tmp; mv selected.tmp selected.txt
if [ "$profile" = custom ]; then printf '%s\n' "$custom" > custom.tmp; chmod 644 custom.tmp; mv custom.tmp custom.txt; fi
/usr/bin/perl -MJSON::PP -e '$v=hex($ARGV[0]);print encode_json({backendVersion=>"1.2.0",profile=>$ARGV[2],pl1=>($v&0x7fff)/8,pl2=>(($v>>32)&0x7fff)/8,turbo=>$ARGV[1]?JSON::PP::true:JSON::PP::false,tau=>0+$ARGV[3]}),"\n"' "$actual" "$turbo" "$profile" "${args[3]:-0}" > settings.tmp
chmod 644 settings.tmp; mv settings.tmp settings.json
writeactual "$actual" "$actualTurbo"
sample
limits=$(/usr/bin/perl -e 'printf "持续 %.3fW / 短时 %.3fW",(hex($ARGV[0])&0x7fff)/8,((hex($ARGV[0])>>32)&0x7fff)/8' "$actual")
case "$profile" in balance) title='平衡';; quiet) title='节能';; custom) title='自定义';; original) title='原始设置';; esac
status "$title · $limits · 睿频 $turbo（已回读验证）"
