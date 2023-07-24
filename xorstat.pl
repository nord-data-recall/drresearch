#!/usr/bin/perl -w
use Getopt::Long;

my $help=0;
my $pagesizeoverride=undef;
my $xorsize=16; # size of XOR key in pages

GetOptions('help|?' =>\$help,
	   'pagesize=i' =>\$pagesizeoverride,
	   'xorsize=i' =>\$xorsize
          );

if($help)
{
  print "How to use xorstat:\nYou can call xorstat without any arguments, then it will analyze all the .decoded files in the current directory.\nYou can specify single files to be displayed on the commandline.\nParameters:\n  dmpview --max_y=100  -> display only the first 100 pages/records\n  dmpview --max_x=100  -> display only the first 100 bytes/bits of a page\n  dmpview --bw=0  -> display the image as grayscale\n  dmpview --bw=1 -> display the image as black\&white\n";
  exit;
}

sub mymax($$)
{
  return $_[1] unless defined($_[0]);
  return $_[0] unless defined($_[1]);
  return $_[0]>$_[1]?$_[0]:$_[1];
}
sub mymin($$)
{
  return $_[1] unless defined($_[0]);
  return $_[0] unless defined($_[1]);
  return $_[0]<$_[1]?$_[0]:$_[1];
}
sub sec2gb($)
{
  return "<div style='display:inline' title='".sprintf("0x%X",$_[0])."'>$_[0]</div>(".sprintf("%.2f",$_[0]/2/1024/1024)."GB)";
}
sub byt2gb($)
{
  return "<div style='display:inline' title='".sprintf("0x%X",$_[0])."'>$_[0]</div>(".sprintf("%.2f",$_[0]/1024/1024/1024)."GB)";
}



sub numalpha
{
  my ( $anum ) = $a =~ /^(\d+)$/;
  my ( $bnum ) = $b =~ /^(\d+)$/;
  return ($anum && $bnum) ? ($a <=> $b) : ($a cmp $b);
}

my @fns=@ARGV;
@fns= <*.decoded> if(!scalar(@ARGV));

foreach my $fn(@fns)
{

  my $pagesize=512;
  my $blocksize=256;
  $pagesize=$1 if($fn=~m/\((\d+)[bp].*?\)/);
  $pagesize=$1*1024 if($fn=~m/\((\d+)[kK].*?\)/);
  $pagesize=$pagesizeoverride if(defined($pagesizeoverride));

  my $fs=-s $fn;
  my $bs=int($fs/$pagesize);
  my $rest=$fs % $pagesize;

  print "Filename: $fn\nfile size: $fs\npage size: $pagesize\nblock size: $bs pages (".($bs*$pagesize)." Bytes)\n";
  print "Warning: There is a rest at the end of the file: $rest Bytes (please check the pagesize!)\n" if($rest);


  open IN,"<$fn";
  binmode IN;


  my $char = '|Block#';
  my $pagen = 0;
  my $pageoffset=0;
  my $ende=0;

  our %pageoffsets=(); # in which offset inside a page were blocks found? (where are the data areas inside a page?)
  our %fulloffsets=(); # what are the absolute positions inside the dumpfile where blocks were found?
  our %xorpages=(); # In which page inside the XOR key were blocks found?
  our %blockpages=(); # In which pages of a block were blocks found?
  our %pages=(); # In which page number were blocks found?
  our %lbas=(); # Which LBA#s were found?
  our %stat=(); # global stats

  while(!$ende)
  {
    my $ret=read IN,$sector,$pagesize;
    $ende=1 if(!defined($ret) || $ret==0);

    my $offset=0;

    my $result = index($sector, $char, $offset); # Search for the first sector inside this page

    while ($result != -1) {

      my $fulladdress=$pageoffset+$result;
      my $xorpage=$pagen % $xorsize;
      my $blockpage=$pagen % $blocksize;
      my $lbad=substr($sector,$result+7,12);
      my $lbah=substr($sector,$result+23,8);
      my $lbab=substr($sector,$result+39,20);
      my $lba=undef;
      #print "Found $char at $result (fulladdress:$fulladdress xorpage:$xorpage blockpage:$blockpage)";
      $lbaD=int($lbad) if($lbad=~m/^(\d+)$/);
      $lbaH=hex("0x".$lbah) if($lbah=~m/^([0-9a-fA-F]+)$/);
      $lbaB=int($lbab/512) if($lbab=~m/^(\d+)$/);
      # Majority-Voting on the LBA address
      $lba=$lbaD if(defined($lbaD) && defined($lbaH) && $lbaD == $lbaH);
      $lba=$lbaD if(defined($lbaD) && defined($lbaB) && $lbaD == $lbaB);
      $lba=$lbaH if(defined($lbaH) && defined($lbaB) && $lbaH == $lbaB);

      #print " LBA:$lba" if(defined($lba));
      #print " LBAd:$lbad($lbaD) LBAh:$lbah($lbaH) LBAb:$lbab($lbaB)" if(defined($lba));
      #print "\n";

      $lbas{$lba}++ if(defined($lba));
      $pageoffsets{$result}++;
      $fulloffsets{$fulladdress}++;
      $pages{$pagen}++;
      $xorpages{$xorpage}++;
      $blockpages{$blockpage}++;
      $stat{'found'}++;
      $stat{'lbafound'}++ if(defined($lba));
      $stat{'maxlba'}=mymax($lba,$stat{'maxlba'}) if(defined($lba));

      $offset = $result + 1; # Where to search for the next sector inside this page?
      $result = index($sector, $char, $offset);
    }

    $pagen++;
    $pageoffset+=$pagesize;
  }

  $stat{"uniqueLBA"}=scalar(keys %lbas);

  sub menu()
  {
    print OUT "<br/><b>Table of Contents:</b> ";
    print OUT "<a href='#PageOffsets'>Page Offsets</a> ";
    print OUT "<a href='#FullOffsets'>Full Offsets</a> ";
    print OUT "<a href='#XORPages'>XOR Pages</a> ";
    print OUT "<a href='#BlockPages'>Block Pages</a> ";
    print OUT "<a href='#Pages'>Pages</a> ";
    print OUT "<a href='#Statistic'>Statistic</a> ";
    print OUT "<a href='#LBAtable'>LBA Table</a> ";
    print OUT "<a href='#FinalStatistic'>Final Statstic</a><br/>\n";
    print OUT "<br/>\n";
  }

  open OUT,">$fn.html";
  print OUT "<html><head><title>$fn</title></head><body>";
  menu();
  print OUT "Filename: $fn<br/>file size: $fs<br/>page size: $pagesize<br/>block size: $bs pages (".($bs*$pagesize)." Bytes)<br/>";

  sub statdump($$$%)
  {
    menu();
    print "Dumping $_[0]\n";
    my $id=$_[0]; $id=~s/://; $id=~s/ //g;
    print OUT "<h2 id='$id'>$_[0]</h2>";
    print OUT $_[2]."<br/>\n";
    print OUT "<table border='1'><tr><th>$_[1]</th><th>delta</th><th>count</th></tr>";
    my $prev=0;
    foreach(sort numalpha keys %{$_[3]})
    {
      #print "$_: $_[1]{$_}\n";
      $diff=""; $diff="+".($_-$prev) if($_=~m/^\d+$/);
print OUT "<tr><td>$_</td><td>$diff</td><td>$_[3]{$_}</td></tr>\n";
$prev=$_;
    }
    print OUT "</table>\n";
  }


  statdump("Page Offsets:","offset inside page","The Page Offsets table shows the offset of all the found DA/sectors inside a page. Are there any gaps above (>+1000)? There should be no such gaps, those indicate problems with the XOR key.",\%pageoffsets);
  statdump("Full Offsets:","Byte#","The Full Offsets table above shows the addresses inside the dump file where the sectors were found. Bigger gaps are expected and OK here.",\%fulloffsets);
  statdump("XOR Pages:","page# inside XOR key","The XOR Pages table above shows in which page inside the XOR key were sectors found? This should be a nice and gap-less list from 0 to the size of the XOR key in pages minus 1. Any gaps here clearly indicate which parts of the XOR key are no good.",\%xorpages);
  statdump("Block Pages:","page# inside block2","",\%blockpages);
  statdump("Pages:","page#","",\%pages);
  statdump("Statistic:","info","",\%stat);

  my $lbasperline=128;
  if(defined($stat{'maxlba'}))
  {
    my $maxlba=mymin(mymax($stat{'maxlba'}/100,1000),$stat{'maxlba'});
    print OUT "<h2 id='LBAtable'>LBA Table from LBA#0 to LBA#".sec2gb($maxlba)."</h2>\n";
    print OUT "(we only visualize approximately the first 1% to avoid crashing the browser)<br/>\n";
    print OUT "<table border='1'>";

    foreach(0 .. $maxlba)
    {
      print OUT "<td bgcolor='".(defined($lbas{$_})?"#00ff00":"#ff0000")."' width='4' height='4'></td>";
      print OUT "</tr><tr>" if(($_ % $lbasperline)==($lbasperline-1));
    }
    print OUT "</tr>";
  }
  print OUT "</table>";

  print OUT "<h2 id='FinalStatistic'>Final statistics</h2>\n";
  print OUT "Filename: $fn<br/>file size: ".byt2gb($fs)."<br/>page size: $pagesize<br/>block size: $bs pages (".($bs*$pagesize)." Bytes)<br/>";
  print OUT "Number of unique LBA's found: ".sec2gb($stat{"uniqueLBA"})."<br/>\n";
  print OUT "Biggest LBA found: ".sec2gb($stat{'maxlba'})."<br/>\n" if(defined($stat{'maxlba'}));
  print OUT "Percentage of LBA's found: ".sprintf("%.4f",100*$stat{'uniqueLBA'}/($stat{'maxlba'}||1))."%<br/>\n";
  print OUT "<br/>\n";
  menu();

  print OUT "</body></html>";
  close OUT;

}
