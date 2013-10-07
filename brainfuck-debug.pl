#!/usr/bin/perl -w
#brainfuckdebug.pl
=begin comment

My attempt at a brainfuck interpreter. This is the debugging version.

It will print out every instruction and its results (on memory, the instruction
pointer, etc), unless there is a series of duplicate repeated instructions.
Then it will wait until the last instruction in the string to print.
Example:
If it encounters "->+++++" it will print three times: once for "-", once for
">", and once at the last "+".

Usage:
Specify the brainfuck program as a command line option or interactively.

Input buffer:
	Uses an input buffer so that you can entire an entire line of text at a time
and the program will read as much of it as it needs, when it needs.
CAUTION: "enter" characters (newlines) count.
You can turn off input buffering by adding "nobuffer" as a second command line
option. Then you will have to enter characters one per line, one at a time.

Comment removal:
	In the preparation phase, it removes all non-bf characters from the code,
meaning extra formatting and comments in the code have no impact on speed.
NOTE: Currently the bf characters are only the canonical eight: +-<>,.[]
semi-official ones like # and ! don't count.

Notes:
	This doesn't check the brainfuck code for validity. Meaning it assumes all
open brackets have matching closing brackets and are properly nested.

=cut comment

use strict;

my $DEBUG = 0;
my $LOOP_DETECT = 0;
my $MEMORY = 30_000;

# Get program filehandle
my $program_file;
if (@ARGV) {
	$program_file = shift(@ARGV);
} else {
	print "Enter the filename of the program:\n";
	chomp($program_file = <STDIN>);
}
open(my $program_fh, "<", $program_file) or
	die "Error: Cannot open program file $program_file: $!";


my $buffer = 1;
my $break_point = -1;
my $break_final = 0;
my $break_step = 0;
if (@ARGV) {
	my $arg2 = shift(@ARGV);
	# Don't use buffer?
	$buffer = lc $arg2 ne "nobuffer";
	# set breakpoint?
	if ($arg2 =~ m/break/i) {
		$break_point = shift(@ARGV);
		$break_final = lc $arg2 eq "breakfinal";
		$break_step = lc $arg2 eq "breakstep";
	}
}

# Read in program, remove comments, turn into array of characters
my @program;
while (<$program_fh>) {
	s/[^+\-<>.,\[\]]//g;
	my @line = split('', $_);
	push(@program, @line);
}


# Init debug stuff

my $temp_disable = 0;
my $old_ctr = 0;
my $ctr_time = 0;
my $tmp_ctr_time = 0;
my $time = time;
my $break = 0;
# $break_point = int( @program / 2 );
if ($DEBUG) {
	print "ptr: 0\n";
}

# MAIN PARSING LOOP

my $ptr = 0;
my @mem = ();
my $nested = 0;
my @bufferin = ();
for (my $counter = 0; $counter < @program; $counter++) {
	
	if ($counter == $break_point || $break) {
		print_state(\@mem, \@program, $counter, $ptr, $nested);
		exit if $break_final;
		if ($break_step) {
			$break_step = $break = step();
		}
	}
	
	# keep $counter from going out of bounds on first debug instruction
	if ($counter < 2) {
		if ($DEBUG && $counter == 0) {
				$DEBUG = 0;
				$temp_disable = "true";
		}
		if ($temp_disable) {
			$DEBUG = "true";
			$temp_disable = 0;
		}
	}
	
	
	# MAIN PARSER
	
	if ($program[$counter] eq '+') {
		$mem[$ptr]++;
		if ($mem[$ptr] > 255) {
			$mem[$ptr] = 0;
		}
		#debug
		if ($DEBUG && $program[$counter] ne $program[$counter + 1]) {
			print "$program[$counter] mem: $mem[$ptr]\n";
		}
		
	} elsif ($program[$counter] eq '-') {
		$mem[$ptr]--;
		if ($mem[$ptr] < 0) {
			$mem[$ptr] = 255;
		}
		#debug
		if ($DEBUG && $program[$counter] ne $program[$counter + 1]) {
			print "$program[$counter] mem: $mem[$ptr]\n";
		}
		
	} elsif ($program[$counter] eq '>') {
		$ptr++;
		if ($ptr >= $MEMORY) {
			$ptr = 0;
		}
		#debug
		if ($DEBUG && $program[$counter] ne $program[$counter + 1]) {
			unless (defined($mem[$ptr])) {
				$mem[$ptr] = 0;
			}
			print "$program[$counter] ptr: $ptr, mem: $mem[$ptr]\n";
		}
		
	} elsif ($program[$counter] eq '<') {
		$ptr--;
		if ($ptr < 0) {
			$ptr = $MEMORY - 1;
		}
		#debug
		if ($DEBUG && $program[$counter] ne $program[$counter + 1]) {
			unless (defined($mem[$ptr])) {
				$mem[$ptr] = 0;
			}
			print "$program[$counter] ptr: $ptr, mem: $mem[$ptr]\n";
		}
		
	} elsif ($program[$counter] eq '.') {
		if ($DEBUG) {
			print "$program[$counter]\t\t";
		}
		if ($mem[$ptr]) {
			print chr($mem[$ptr]);
		}
		#debug
		if ($DEBUG) {
			print "\n";
		}
		
	} elsif ($program[$counter] eq ',') {
		if ($buffer) {
			unless (@bufferin) {
				print "\n";
				my $in = <STDIN>;
				push(@bufferin, split('', $in));
			}
			$mem[$ptr] = ord(shift @bufferin);
		} else {						# old, one-character-at-a-time way
			print "\n";
			my $in = <STDIN>;
			$mem[$ptr] = ord($in);
		}
		#debug
		if ($DEBUG) {
			unless (defined($mem[$ptr])) {
				$mem[$ptr] = 0;
			}
			print "$program[$counter] mem: $mem[$ptr]\n";
		}
		
	} elsif ($program[$counter] eq '[') {
		if ($DEBUG) {
			$old_ctr = $counter;
		}
		unless ($mem[$ptr]) {
			until ($program[$counter] eq ']' && $nested < 1) {
				$counter++;
				if ($program[$counter] eq '[') {
					if ($DEBUG) {
						print "$program[$counter] counter: $counter, " .
							"nested: $nested\n";
					}
					$nested++;
				} elsif ($nested && $program[$counter - 1] eq ']') {
					if ($DEBUG) {
						print "$program[$counter - 1] counter: $counter, " .
							"nested: $nested\n";
					}
					$nested--;
				}
			}
		}
		#debug
		if ($DEBUG) {
			print "$program[$old_ctr] counter: $old_ctr -> $counter, " .
				"mem: $mem[$ptr]\n";
		}
		
	} elsif ($program[$counter] eq ']') {
		if ($DEBUG) {
			$old_ctr = $counter;
		}
		if ($mem[$ptr]) {
			until ($program[$counter] eq '[' && $nested < 1) {
				$counter--;
				if ($program[$counter] eq ']') {
					if ($DEBUG) {
						print "$program[$counter] counter: $counter, " .
							"nested: $nested\n";
					}
					$nested++;
				} elsif ($nested && $program[$counter + 1] eq '[') {
					if ($DEBUG) {
						print "$program[$counter + 1] counter: $counter, " .
							"nested: $nested\n";
					}
					$nested--;
				}
			}
		}
		#debug
		if ($DEBUG) {
			print "$program[$old_ctr] counter: $old_ctr -> $counter, " .
				"mem: $mem[$ptr]\n";
		}
		
	}
	
	# Try to weakly detect infinite loops
	# Current setup: Every 10 seconds, turn on DEBUG for 100 instructions.
	if ($LOOP_DETECT) {
		$ctr_time++;
		if ($ctr_time % 500_000 == 0) { #500_000 == 0) {
			print $ctr_time, "\n";
			if (time - $time > 5) {
				$time = time;
				unless ($mem[$ptr]) {
					$mem[$ptr] = 0;
				}
				print "\ncounter: $counter, ptr: $ptr, mem: $mem[$ptr]\n" .
					"instructions processed: $ctr_time\n";
				$DEBUG = "on";
				$tmp_ctr_time = 1;
			}
		}
		if ($tmp_ctr_time) {
			$tmp_ctr_time++;
			if ($tmp_ctr_time > 7500) {
				$DEBUG = 0;
				$tmp_ctr_time = 0;
			}
		}
	}
	
}

print_state(\@mem, \@program, $#program - 8, $ptr, $nested);




sub print_state {
	
	my ($memref, $progref, $counter, $ptr, $nested) = @_;
	
	print "\n\tcounter: $counter, inst: $$progref[$counter]\n";
	print_format($progref, $counter, "str");
	if (defined($$memref[$ptr])) {
		print "\n\tpointer: $ptr, value: $$memref[$ptr]\n";
	} else {
		print "\n\tpointer: $ptr, value: 0\n";
	}
	print_format($memref, $ptr, "num");
	print "\n";
	
}

sub print_format {
	my ($arrayref, $pointer, $type) = @_;
	
	my $format;
	my $format_std = "%3d ";
	my $format_ctr = "|%2d|";
	my $undef_val = "0";
	if (defined($type) && lc $type =~ /str/) {
		$type = "str";
		$format_std = " %2s ";
		$format_ctr = "|%2s |";
		$undef_val = " ";
		print " ";
	} else {
		$type = "num";
	}
	
	if (@$arrayref < 20) {							# simple case
		for my $location (0..$#{$arrayref}) {
			printf "%3d ", $location;
		}
		print "\n";
		for (my $ptr_walker = 0; $ptr_walker < 19; $ptr_walker++) {
			my $value = $$arrayref[$ptr_walker];
			unless (defined($value)) {
				if ($ptr_walker < @$arrayref) {
					$value = $undef_val;
				} else {
					$value = " ";
					$format_std = "%3s ";
					$format_ctr = "|%2s|";
				}
			}
			if ($ptr_walker == $pointer) {
				$format = $format_ctr;
			} elsif ($ptr_walker == $pointer + 1 && $type eq "str") {
				$format = "%2s ";
			} else {
				$format = $format_std;
			}
			printf $format, $value;
		}
		
	} else {										# non-simple case
		for my $location (($pointer - 9)..($pointer + 9)) {
			printf "%3d ", $location;
		}
		print "\n";
		for (my $ptr_walker = $pointer - 9; $ptr_walker - $pointer < 10; $ptr_walker++) {
			my $value = $$arrayref[$ptr_walker];
			if (defined($value)) {
				if ($type eq "str") {
					$value =~ s/[^+\-<>,.\[\]]/X/;
				}
			} elsif ($ptr_walker == @$arrayref && $type eq "str") {
				$value = "EOF";
			} else {
				$value = $undef_val;
			}
			if ($ptr_walker == $pointer) {
				$format = $format_ctr;
			} elsif ($ptr_walker == $pointer + 1 && $type eq "str") {
				$format = "%2s ";
			} else {
				$format = $format_std;
			}
			printf $format, $value;
		}
	}
}

sub step {
	print "([enter] to step, \"go\" to proceed) ";
	chomp(my $proceed = <STDIN>);
	return lc $proceed ne "go";
}