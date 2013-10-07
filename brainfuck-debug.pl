#!/usr/bin/perl -w
=begin comment

A brainfuck interpreter.
This is the debug version. When it encounters a '#' character in the brainfuck
code, it will print the contents of memory.

    USAGE:
Interactive:     Run script, paste code at prompt, enter EOF (Ctrl+D usually).
Non-Interactive: Run script with brainfuck program file as command line option.

Input buffer:
  Uses an input buffer so that you can enter an entire line of text at a time
and the program will read as much of it as it needs, when it needs.
NOTE: Since you use "enter" to submit a line, there's no way to enter newlines.

Use valid code:
  This doesn't check the brainfuck code for validity. It assumes all open
brackets have matching closing brackets and are properly nested.

Comment removal:
  In the preparation phase, it removes all non-bf characters from the code, so
extra formatting and comments have no impact on speed.
NOTE: Valid bf characters are only the canonical eight: +-<>[],.
Semi-official ones like # and ! will be removed.

Language implementation details:
  Cell values are 0 to 255 with wrapping.
  It uses 30000 memory cells with wrapping, as in the original implementation.

=end comment
=cut
use strict;

# Number of memory cells
my $MEMSIZE = 30_000;

# Read in program, remove comments, turn into array of characters
print STDERR "Enter brainfuck code, then an EOF character to signal the end.\n"
  . "Usually this is Ctrl+D.\n";
my @program;
while (<>) {
  s/[^+\-<>.,#\[\]]//g;
  my @line = split('', $_);
  push(@program, @line);
}
print STDERR "\n=====Program Output=====\n";

# MAIN PARSING AND EXECUTION LOOP

my $ptr = 0;
my @mem = ();
my @bufferin = ();
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
      print chr($mem[$ptr]);
    }
    
  } elsif ($program[$counter] eq ',') {
    unless(@bufferin) {          # fill input buffer
      print "\n";
      chomp(my $in = <STDIN>);
      push(@bufferin, split('', $in));
    }
    $mem[$ptr] = ord(shift @bufferin);
    
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
  } elsif ($program[$counter] eq '#') {
    print_mem(\@mem, $ptr, \@program, $counter);
  }
}

# Prints current instruction offset and character, and contents of memory.
# It determines the subset of memory to print
sub print_mem {
  my ($memref, $ptr, $progref, $counter) = @_;
  my @mem = @$memref;
  my @program = @$progref;

  # Want to talk about the instruction before the '#'
  $counter--;
  print "At instruction $counter ($program[$counter]), cell $ptr (";
  if ($mem[$ptr] >= 32 && $mem[$ptr] <= 126) {
    print chr($mem[$ptr]).")\n";
  } else {
    print "[$mem[$ptr]])\n";
  }
  my $large = '';
  for my $i (0..(scalar(@mem)-1)) {
    if ($i >= 80) {
      $large = 1;
      last;
    }
    my $byte = $mem[$i] || 0;
    if ($byte >= 32 && $byte <= 126) {
      print chr($byte);
    } else {
      print "[$byte]"
    }
  }
  print "\n";
  if ($large) {
    print "... Memory too large to show: ".scalar(@mem)." cells\n";
  }
}