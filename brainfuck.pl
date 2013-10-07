#!/usr/bin/perl -w
use strict;
my $MEMSIZE = 30_000;
my @program;
while (<>) {
	my @line = split('', $_);
	push(@program, @line);
}
my $ptr = 0;
my @mem = ();
for (my $counter = 0; $counter < @program; $counter++) {
	if ($program[$counter] eq '+') {
		$mem[$ptr] = ++$mem[$ptr] % 256;
	} elsif ($program[$counter] eq '-') {
		$mem[$ptr] = --$mem[$ptr] % 256;
	} elsif ($program[$counter] eq '>') {
		$ptr = ++$ptr % $MEMSIZE;
	} elsif ($program[$counter] eq '<') {
		$ptr = --$ptr % $MEMSIZE;
	} elsif ($program[$counter] eq '.') {
		if ($mem[$ptr]) {
			print chr($mem[$ptr]), "\n";
		}
	} elsif ($program[$counter] eq ',') {
		$mem[$ptr] = ord(<STDIN>);
	} elsif ($program[$counter] eq '[') {
		unless ($mem[$ptr]) {
			my $nested = 1;
			until ($nested < 1) {
				$counter++;
				if ($program[$counter] eq '[') {
					$nested++;
				} elsif ($program[$counter] eq ']') {
					$nested--;
				}
			}
		}
	} elsif ($program[$counter] eq ']') {
		if ($mem[$ptr]) {
			my $nested = 1;
			until ($nested < 1) {
				$counter--;
				if ($program[$counter] eq ']') {
					$nested++;
				} elsif ($program[$counter] eq '[') {
					$nested--;
				}
			}
		}	
	}	
}