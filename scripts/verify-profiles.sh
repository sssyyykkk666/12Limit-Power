#!/bin/bash
set -euo pipefail
export LC_ALL=C
BASE='/Library/Application Support/FYQMac'
REQ='/Users/skyfu/Library/Application Support/FYQMacControl/request'
readreg() { "$BASE/voltageshift" read "$1" | /usr/bin/perl -ne 'if(/\(([01 ]+)\)/){$b=$1;$b=~s/ //g;print unpack("H16",pack("B64",$b)),"\n" if length($b)==64}'; }
original=$(/usr/bin/perl -ne 'if(/\(([01 ]+)\)/){$b=$1;$b=~s/ //g;print unpack("H16",pack("B64",$b)),"\n"}' "$BASE/original-msr610.txt")
for mode in quiet original balance; do
  printf '%s\n%s\n' "$mode" "$(date +%s)" > "${REQ}.tmp"
  mv "${REQ}.tmp" "$REQ"
  for attempt in {1..30}; do
    [ "$(cat "$BASE/selected.txt" 2>/dev/null)" != "$mode" ] || [ -f "$REQ" ] || break
    /bin/sleep 1
  done
  power=$(readreg 610); turbo=$(readreg 1a0)
  /usr/bin/perl -e '
  ($p,$t,$orig,$mode)=@ARGV; $v=hex($p); $o=hex($orig);
  die "Non-power bits changed\n" if ($v & ~0x7fff00007fff)!=($o & ~0x7fff00007fff);
  if($mode eq "original") {die "Restore mismatch\n" if $p ne $orig;}
  else {
    die "PL1 mismatch\n" unless ($v & 0x7fff)==40;
    die "PL2 mismatch\n" unless (($v>>32)&0x7fff)==($mode eq "quiet" ? 40 : 48);
    $off= (hex($t)&(1<<38)) ? 1:0;
    die "Turbo mismatch\n" unless $off==($mode eq "quiet" ? 1:0);
  }
  print "$mode: PASS\n";
  ' "$power" "$turbo" "$original" "$mode"
  cat "$BASE/status.txt"
done
