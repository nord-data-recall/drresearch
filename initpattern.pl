#!/usr/bin/perl -w

if(!scalar(@ARGV))
{
  print "Usage: $0 <device>\n";
  print "Usage: $0 <dumpfile> <size in MB> <data area size>\n";
  exit;
}

my $mydev=($ARGV[0] || "/dev/sdx");
my $xmlfn=$mydev.".xml"; $xmlfn=~s/\//_/g;

open OUT,">:raw",$mydev; # XXXXXXX YOU HAVE TO CHANGE THIS PARAMETER, be careful that you do use your harddisk!
open XML,">$xmlfn";


my $DATAsize=$ARGV[2] || 1024;
my $eccreal=($DATAsize/512)+1;
my $majority=7;

my $border0=512*1024*2; # 512MB pattern
my $border7=1024*1024*2; # 512MB 00
my $borderf=1280*1024*2; # 256 MB 77
my $borderphi=1536*1024*2; # 256 MB FF
my $borderecc=$borderphi+$eccreal*$eccreal*$majority*$DATAsize*8+1; # lots of ECC (for 512B DA we dont need much, for 4KB we need 11 GB)
# And at the end we have the pattern again

my $overwritten=1;

if($ARGV[1])
{
  $size=$ARGV[1]*1024*1024;
  if($size<$borderecc*512)
  {
    print "WARNING: Not all of the pattern will be in the dump! Enlarge the dump size to at least ".int($borderecc/2/1024)." or change the dump configuration\n";
  }
  $overwritten=0;
}
else
{
  seek(OUT,0,2); 
  my $size=tell(OUT);
  seek(OUT,0,0);
  $overwritten=1;
}

print XML "<root overwritten='$overwritten'>\n<device>$ARGV[0]</device>\n<pattern type='sectornumber' begin='0' end='".($border0-1)."' size='".($border0)."'/>\n<pattern type='XOR-00' begin='$border0' end='".($border7-1)."' size='".($border7-$border0)."'/>\n<pattern type='XOR-77' begin='$border7' end='".($borderf-1)."' size='".($borderf-$border7)."'/>\n<pattern type='XOR-FF' begin='$borderf' end='".($borderphi-1)."' size='".($borderphi-$borderf)."'/>\n<pattern type='ECC' begin='$borderphi' end='".($borderecc-1)."' size='".($borderecc-$borderphi)."' coverage='$DATAsize' majority='$majority'/>\n<pattern type='sectornumber' begin='$borderecc' end='".(int($size/512)-1)."' size='".(int($size/512)-$borderecc)."'/>\n</root>\n";

print "Size: $size Bytes ".($size/1000/1000/1000)." GB\n";
my $nblocks=$size/512;

if($overwritten)
{
  foreach my $block (0 .. $size/512)
  {
    my $data=sprintf("|Block#%012d (0x%08X) Byte: %020d Pos: %10d MB\n***OVERWRITTEN",$block,$block,$block*512,$block>>11);
    $data.= "x"x(510-length($data))."\n\x00";
    if(length($data)!=512)
    {
      print STDERR "WARNING: sector size is wrong in overwritten\n";
    }
    print OUT $data;
    my $percent=int(100*$block/$nblocks);
    print STDERR "$block $percent\%\n" if(!($block %100000));
  }
}

seek(OUT,0,0);

foreach my $block (0 .. $size/512)
{
  my $data=sprintf("|Block#%012d (0x%08X) Byte: %020d Pos: %10d MB\n***",$block,$block,$block*512,$block>>11);
  $data.= "x"x(510-length($data))."\n\x00";
  $data="\x00" x 512 if($block>=$border0 && $block<$border7);
  $data="\x77" x 512 if($block>=$border7 && $block<$borderf);
  $data="\xFF" x 512 if($block>=$borderf && $block<$borderphi);
  if($block>=$borderphi && $block <$borderecc)
  {
    my $patternsize=$eccreal*$eccreal*$majority;
    my $offset=$block-$borderphi;
    my $pattern=int($offset/$patternsize); # 0 .. DATAsize*8
    my $patternpos=$offset % $eccreal;
    my $patternmod=int(($offset % ($eccreal*$eccreal))/$eccreal);
    my $bittargetsector=($pattern>>3) >>9;
    #print "\npatternsize: $patternsize\noffset: $offset\npattern: $pattern\npatternpos: $patternpos\nbittargetsector: $bittargetsector\n";
    if($patternpos>0)
    {
      $data="\x00" x 512; #"0123456789abcdef"x(512/16);
      if($bittargetsector==($patternpos-1) && $patternmod)
      {
        my $bittargetbyte=($pattern>>3) & 0x1FF;
        my $bittargetbit=$pattern&7;
	#print "bittargetbyte: $bittargetbyte\nbittargetbit: $bittargetbit\n";
        substr($data,$bittargetbyte,1)=substr($data,$bittargetbyte,1)^pack("C",(1<<$bittargetbit));
      }
    }
  }
  if(length($data)!=512)
  {
    print STDERR "WARNING: sector size is wrong in new pattern\n";
  }
  print OUT $data;
  my $percent=int(100*$block/$nblocks);
  print STDERR "$block $percent\%\n" if(!($block %100000));
}

close OUT;
close XML;
print STDERR "Pattern has been written to device/file $mydev\n";
print STDERR "Pattern configuration has been written to the file $xmlfn in XML format.\n";
print STDERR "Done.\n";
