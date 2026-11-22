#!/usr/bin/env bash
# Delphi-only build break that FPC does not report: a unit with both Math and Apus.Core
# in its uses clauses gets ambiguous overloads for an unqualified Min/Max call.
# The condition is local to one file (Pascal does not re-export units), so a textual
# check is exact enough. Run from anywhere inside the repository; exit code 1 = found.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

git ls-files -z -- '*.pas' '*.dpr' '*.inc' |
  perl -0 -ne 'chomp; print "$_\n" unless m{^(legacy|Game|tmp)/|/legacy/|(^|/)Deprecated/}' |
  perl -e '
    my $found=0;
    while (my $file=<STDIN>) {
      chomp $file;
      open(my $fh,"<",$file) or die "$file: $!";
      local $/; my $text=<$fh>; close $fh;
      # drop strings and comments, keep line breaks so line numbers stay true
      $text=~s#(\x27(?:[^\x27\n]|\x27\x27)*\x27)|(//[^\n]*)|(\{[^\}]*\})|(\(\*.*?\*\))#
        defined $1 ? "\x27\x27" : ("\n" x ($& =~ tr/\n//))
      #gse;
      my ($math,$core)=(0,0);
      while ($text=~/\buses\b(.*?);/gis) {
        for my $unit (split /,/, $1) {
          $unit=~s/\bin\b.*//is; $unit=~s/^\s+|\s+$//g; $unit=lc $unit;
          $math=1 if $unit eq "math" or $unit eq "system.math";
          $core=1 if $unit eq "apus.core";
        }
      }
      next unless $math and $core;
      my $line=0;
      for (split /\n/, $text, -1) {
        $line++;
        if (/(?<![.\w])(min|max)\s*\(/i) {
          print "$file:$line: unqualified $1( with Math and Apus.Core in uses\n";
          $found=1;
        }
      }
    }
    if ($found) {
      print "\nDelphi reports these calls as ambiguous (FPC does not): Math and Apus.Core both declare Min/Max.\n";
      print "Fix: drop Math (Apus.Core has Clamp for EnsureRange) or qualify the call: Apus.Core.Max / Math.Max\n";
      exit 1;
    }
    print "Min/Max check: OK\n";
  '
