#!/usr/bin/perl
use utf8; use strict; use warnings; no warnings 'portable'; use JSON::PP;
# Pure policy; never touches hardware. Requests contain integer eighth-watts.
my ($op,$baseline,$mode,@values)=@ARGV;
die "Invalid baseline\n" unless defined($baseline) && $baseline =~ /^[0-9a-f]{16}$/;
my $v=hex($baseline); my ($max1,$max2)=($v&0x7fff,($v>>32)&0x7fff);
die "Invalid original limits\n" unless $max1>=30 && $max2>=30;
if($op eq 'capabilities') {
 print encode_json({minWatts=>3.75,maxPL1=>$max1/8,maxPL2=>$max2/8,stepWatts=>0.125,recommendedPL1=>7,frequencySupported=>JSON::PP::false,gpuSupported=>JSON::PP::false,
 frequencyReason=>'本机睿频倍率写入未通过回读验证；现有驱动不能可靠设置所有核心的 HWP 上限。',gpuReason=>'HD Graphics 615 与 CPU 共享封装功耗，暂无本机验证有效的独立 GPU 控制接口。'}),"\n"; exit;
}
die "Invalid operation\n" unless $op eq 'target';
my ($p1,$p2,$turbo,$tau)=(40,48,1,0);
if($mode eq 'original') {printf "%016x\n",$v;exit;}
elsif($mode eq 'quiet') {$p2=40;$turbo=0;}
elsif($mode eq 'custom') {
 die "Expected four fields\n" unless @values==4;
 for(@values){die "Invalid integer\n" unless /^\d{1,3}$/;}
 ($p1,$p2,$turbo,$tau)=@values;
 die "Power out of range\n" unless $p1>=30 && $p1<=$max1 && $p2>=$p1 && $p2<=$max2;
 die "Invalid turbo\n" unless $turbo==0 || $turbo==1;
 die "Invalid window\n" unless grep {$_==$tau} (0,1,2,4,8,16,28);
} elsif($mode ne 'balance'){die "Unknown profile\n";}
$p1=$max1 if $p1>$max1; $p2=$max2 if $p2>$max2;
$v=($v&~0x7fff00007fff)|$p1|($p2<<32);
if($tau){
 my $code;
 for my $y(0..31){for my $z(0..3){$code=($z<<5)|$y if (1+$z/4)*2**$y/1024==$tau;}}
 die "Unencodable window\n" unless defined $code;
 $v=($v&~(0x7f<<17))|($code<<17);
}
printf "%016x\n",$v;
