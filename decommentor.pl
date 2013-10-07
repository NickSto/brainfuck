#!/usr/bin/perl -w
#decommentor.pl
=begin comment

Removes "comments" from brainfuck code.

"Comments" are any characters that aren't "+-><,.[]", including newlines
(so the resulting programs will be all on one line).

Specify the input file as the first command line option or leave it blank to
specify it interactively.

Decommented output files are appended with "_short" before the file extension,
so that "helloworld.bf" becomes "helloworld_short.bf". If a file with that name
already exists, the program will print an error and exit.

=cut comment

use strict;

my $MODIFIER = "_short";

# Get input program filehandle
my $program_file;
if (@ARGV) {
	$program_file = shift @ARGV;
} else {
	print "Enter the filename of the program:\n";
	chomp($program_file = <STDIN>);
}
open(my $program_fh, "<", $program_file) or
	die "Error: Cannot open program file $program_file: $!";

# Get output filehandle
my $new_file = $program_file;
unless ($new_file =~ s/(.*)\.(.*?)/$1$MODIFIER.$2/) {
	$new_file = $new_file . $MODIFIER;
}
if (-e $new_file) {
	die "Error: Output file $new_file already exists\n";
}
open(my $out_fh, ">", $new_file) or
	die "Error: Cannot open output file $new_file: $!";

# Actual decommenting
while (<$program_fh>) {
	s/[^+\-<>.,\[\]]//g;
	print $out_fh $_;
}

# Close filehandles, just to be paranoid
close $program_fh;
close $out_fh;