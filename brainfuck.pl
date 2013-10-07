#!/usr/bin/perl -w
=begin comment

A brainfuck interpreter.

    USAGE:
$ brainfuck.pl brainfuck-program.b
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
Debug mode will keep and interpret #, {, and }.

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
my $PAUSE_DEFAULT = 0.25; # seconds
my $PAUSE_FAST = 0.05;    # seconds
my $MEMFILE_DEFAULT = 'memdump.dat';
my $VALID_CHARS_DEFAULT = '+\-<>.,\[\]';
my $OPTS = 'cdfhimsw';
$Getopt::Std::STANDARD_HELP_VERSION = 1;

my $valid_chars = $VALID_CHARS_DEFAULT;
my $memfile = $MEMFILE_DEFAULT;
my $has_args = @ARGV;

my %opt;
my $valid_opts = getopts($OPTS, \%opt);
my $help    = $opt{h} || 0;
my $debug   = $opt{d} || 0;
my $stdin   = $opt{i} || 0;
my $silent  = $opt{s} || 0;
my $watch   = $opt{w} || 0;
my $compact = $opt{c} || 0;
my $fast    = $opt{f} || 0;
my $memdump = $opt{m} || 0;
if ($debug) { $valid_chars .= '#{}' }
my $pause   = $fast ? $PAUSE_FAST : $PAUSE_DEFAULT;
# $watch is a permanent status, while $watch_now can toggle on each command
my $watch_now = $watch;

HELP_MESSAGE() if ($help || ! $valid_opts || ! $has_args);
sub HELP_MESSAGE {
  my $this = basename($0);
  print 'USAGE:
  $ '.$this.' source-file.b
or
  $ echo \'++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<++
+++++++++++++.>.+++.------.--------.>+.>.\' | '.$this.' -i
Options:
-i Read brainfuck code from standard input instead of the first argument file.
-s Silent: print nothing but the brainfuck output. Normally when -i is used,
   some prompts are printed to stderr.
-d Debug: on encountering a # instruction, print memory state and other
   execution state information. Also, { and } will toggle the -w flag.
-w Watch: Slowly step through the program, printing the memory contents after
   every instruction altering memory state.
-f Fast: Speed up the -w stepping by 5x (50 ms between prints instead of 250 ms)
-m Memdump: On exit (or Ctrl+C interrupt), print the contents of memory to a
   file named "scriptname-memdump.dat" (or just "memdump.dat" if reading from
   stdin). The file will be in binary format, one byte per cell.
-c Compact: When using -d or -w, print memory contents in a compact fashion.
   When the value of a cell is outside printable ASCII values, instead of
   printing the numeric value, delimited by "|" characters, print a "." or, if
   the value is below 16, print it in hexadecimal. This representation can be
   ambiguous, but it\'s more compact and faster to read.
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
  unless (@ARGV) {
    print STDERR "Error: no input brainfuck script file provided.\n";
    HELP_MESSAGE();
  }
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

  # create memdump filename based on brainfuck script name
  if ($memdump) {
    my @path_parts = split(/\./, $script_filename);
    pop(@path_parts);
    $memfile = join('.', @path_parts).'-'.$MEMFILE_DEFAULT;
  }
}
if ($memdump && -e $memfile) {
  print STDERR "Error: Memory dump file $memfile already exists.\n"
    . "Please rename the existing file.\n";
  exit(1);
}


########## MAIN LOOP ##########

my $ptr = 0;
my @mem = ();
my @bufferin = ();
my $last_print = 'none';
$SIG{INT} = \&memdump if ($memdump);  # Call memdump() on ctrl-c interrupt
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
      $last_print = 'normal';
    }
    
  } elsif ($program[$counter] eq ',') {
    unless(@bufferin) {       # fill input buffer
      my $in = <STDIN>;
      unless ($in) {
        memdump($memfile, \@mem) if ($memdump);
        exit(0);
      }   # end of file
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

  } elsif ($debug) {
    if ($program[$counter] eq '#') {
      print "\n" if ($last_print eq 'normal');
      print_state(\@mem, $ptr, \@program, $counter, $compact);
      $last_print = 'debug';
    } elsif ($program[$counter] eq '{') {
      $watch_now = 1;
    } elsif ($program[$counter] eq '}' && ! $watch) {
      $watch_now = 0;
    }
  }

  if ($watch_now) {
    # If memory value-altering instruction
    if ($program[$counter] eq '+' ||
        $program[$counter] eq '-' ||
        $program[$counter] eq ',') {
      print "\n" if ($last_print eq 'normal');
      print_mem(\@mem, $ptr, $compact);
      select(undef, undef, undef, $pause);
      $last_print = 'debug';

    # If pointer location-altering instruction
    # (I don't know how to do this simply and efficiently without duplication)
    } elsif ($program[$counter] eq '>' ||
             $program[$counter] eq '<') {
      print "\n" if ($last_print eq 'normal');
      print_mem(\@mem, $ptr, $compact, $program[$counter]);
      select(undef, undef, undef, $pause/4);
      $last_print = 'debug';
    }
  }
}

memdump($memfile, \@mem) if ($memdump);


########## SUBROUTINES ##########

# Prints current instruction offset and character, and contents of memory.
# It determines the subset of memory to print
sub print_state {
  my ($memref, $ptr, $progref, $counter, $compact) = @_;

  # Want to talk about the instruction before the '#' (unless it's at the start)
  $counter = $counter ? $counter - 1 : $counter;

  print STDERR "At instruction $counter ($$progref[$counter]), cell $ptr";
  unless (@$memref) {
    print STDERR "\nmemory not initialized\n";
    return;
  }
  print STDERR " (";
  my $byte = $$memref[$ptr] || 0;
  if ($byte >= 32 && $byte <= 126) {
    print STDERR chr($byte).")\n";
  } else {
    print STDERR "[$byte])\n";
  }

  my $large = print_mem($memref, $ptr, $compact);
  if ($large) {
    print STDERR "... Memory too large to show: ".scalar(@$memref)." cells\n";
  }
}

# Returns 1 if memory was too large to print all of it, 0 otherwise
sub print_mem {
  my ($memref, $ptr, $compact, $inst) = @_;

  my $large = 0;
  my $last_printable = 0;
  my $out_str = '';
  my $byte_str = '';
  for my $i (0..(scalar(@$memref)-1)) {
    my $byte = $$memref[$i] || 0;
    $byte_str = '';
    if ($inst && $i == $ptr) {
      $byte_str = $inst;
    } elsif ($byte >= 32 && $byte <= 126) {
      $byte_str = chr($byte);
      $last_printable = 1;
    } elsif ($compact) {
      if ($byte < 16) {
        $byte_str = sprintf("%x", $byte);
      } else {
        $byte_str = '.';
      }
    } else {
      if ($last_printable) {
        $byte_str = '|';
      }
      $byte_str .= "$byte|";
      $last_printable = 0;
    }
    if (length($out_str) + length($byte_str) > 80) {
      $large = 1;
      last;
    } else {
      $out_str .= $byte_str;
    }
  }
  if ($inst && $ptr >= @mem) {
    my $excess = $ptr - @mem;
    if (length($out_str) + $excess + 1 < 80) {
      $out_str .= ' ' x $excess . $inst;
    }
  }
  print STDERR "$out_str\n";

  return $large;
}

# Print entire memory to file
sub memdump {
  if (-e $memfile) {
    print STDERR "Error: Memory dump file $memfile already exists.\n"
      . "Please rename the existing file.\n";
    exit(1);
  } else {
    open(my $mem_fh, '>', $memfile) or
      die "Error: Could not open memory dump file $memfile: $!";
    for my $byte (@mem) {
      $byte = 0 unless ($byte);
      print $mem_fh pack('C', $byte);
    }
  }
  exit(0);
}
