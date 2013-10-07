#!/usr/bin/perl -w
=begin comment

A brainfuck interpreter.

    USAGE:
$ brainfuck.pl brainfuck-program.bf
or
$ echo '++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<++++
+++++++++++.>.+++.------.--------.>+.>.' | brainfuck.pl -i
  See below for full usage string

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
Unless running in debug mode, semi-official ones like # and ! will be removed.
Debug mode will keep and interpret #.

Language implementation details:
  Cell values are 0 to 255 with wrapping.
  It uses 30000 memory cells with wrapping, as in the original implementation.

=end comment
=cut
use strict;
use Getopt::Std;
use File::Basename;

# Constants
my $MEMSIZE = 30_000; # Number of memory cells
my $OPTS = 'dis';
my $VALID_CHARS_DEFAULT = '+\-<>.,\[\]';
my $valid_chars = $VALID_CHARS_DEFAULT;

my $has_args = @ARGV;
my %opt;
getopts($OPTS, \%opt);
my $debug  = $opt{d} || 0;
my $stdin  = $opt{i} || 0;
my $silent = $opt{s} || 0;
if ($debug) { $valid_chars .= '#' }

unless ($has_args) {
  my $this = basename($0);
  print 'USAGE:
  $ '.$this.' source-file.bf
or
  $ echo \'++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<++
+++++++++++++.>.+++.------.--------.>+.>.\' | '.$this.' -i
Options:
-i Read brainfuck code from standard input instead of the first argument file.
-s Silent: print nothing but the brainfuck output. Normally when -i is used,
   some prompts are printed to stderr.
-d Debug: on encountering a # instruction, print memory state and other
   execution state information.
';
  exit(0);
}

# Read in program, remove comments, turn into array of characters
my @program;
my $input;
if ($stdin) {
  unless ($silent) {
    print STDERR "Enter brainfuck code, then an EOF character to signal the end.\n"
      . "Usually this is Ctrl+D.\n";
  }
  my $line = 0;
  while (<>) {
    $line++;
    next if ($line == 1 && m|^#!.*/|); # skip any hashbang line @ start
    s/[^$valid_chars]//g;
    my @line = split('', $_);
    push(@program, @line);
  }
  unless ($silent) {
    print STDERR "\n========Program Output====";
    print STDERR "(it is listening to stdin now)========\n";
  }

} else {
  # get script filename from first option
  my $script_filename = $ARGV[0];
  open(my $script_fh, '<', $script_filename) or
    die "Error: Cannot open brainfuck source file provided ($script_filename): $!";
  my $line = 0;
  while (<$script_fh>) {
    $line++;
    next if ($line == 1 && m|^#!.*/|); # skip any hashbang line @ start
    s/[^$valid_chars]//g;
    my @line = split('', $_);
    push(@program, @line);
  }
}

# MAIN PARSING AND EXECUTION LOOP

# my $line = <STDIN>;
# print $line;
# exit(0);

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
    unless(@bufferin) {       # fill input buffer
      my $in = <STDIN>;
      exit(0) unless ($in);   # end of file
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
  } elsif ($debug && $program[$counter] eq '#') {
    print_mem(\@mem, $ptr, \@program, $counter);
  }
}


# Prints current instruction offset and character, and contents of memory.
# It determines the subset of memory to print
sub print_mem {
  my ($memref, $ptr, $progref, $counter) = @_;
  my @mem = @$memref;
  my @program = @$progref;

  # Want to talk about the instruction before the '#' (unless it's at the start)
  $counter = $counter ? $counter - 1 : $counter;

  print "At instruction $counter ($program[$counter]), cell $ptr";
  unless (@mem) {
    print "\nmemory not initialized\n";
    return;
  }
  print " (";
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