#!/usr/local/bin/perl

use Config;
use File::Basename qw(&basename &dirname);

# List explicitly here the variables you want Configure to
# generate.  Metaconfig only looks for shell variables, so you
# have to mention them as if they were shell variables, not
# %Config entries.  Thus you write
#  $startperl
# to ensure Configure will look for $Config{startperl}.

# This forces PL files to create target in same directory as PL file.
# This is so that make depend always knows where to find PL derivatives.
chdir(dirname($0));
($file = basename($0)) =~ s/\.PL$//;
$file =~ s/\.pl$//
	if ($^O eq 'VMS' or $^O eq 'os2');  # "case-forgiving"

open OUT,">$file" or die "Can't create $file: $!";

print "Extracting $file (with variable substitutions)\n";

# path at extraction time. Must contain 'gs' for checking present
# devices.  Also default options are stripped for all programs which
# could not be located. This only applies to 'pnmtops' currently

@PATH = qw(/bin /usr/bin /usr/local/bin /usr/ucb
           /usr/local/ls6/unsupported/bin
           /usr/local/ls6/latex2html/bin
           /usr/local/ghostscript-3.51/bin
           /usr/local/ls6/texinfo-3.7/bin
           /usr/openwin/bin /usr/local/X11R6/bin /usr/local/X11R5/bin 
           /opt/local/image-tools-95a/bin /usr/local/image-tools/bin);
push @PATH, split /:/, $ENV{'PATH'};
push @PATH, "/usr/local/ls6/unsupported/bin/$Cnfig{'archname'}";

# remove duplicate entries
@PATH = grep !$SEEN{$_}, @PATH; %SEEN=();

# locate filter program. Cureently only used for stripping of default
# options.
sub find_bin {
  my $prog     = shift;
  
  return $PROG{$prog} if defined $PROG{$prog};
  for $path (@PATH) {
    if (-x "$path/$prog") {
      $PROG{$prog} = "$path/$prog";
      return $PROG{$prog};
    }
  }
  $PROG{$prog} = 0;
}

# run 'gs' and ask for devices
sub gs_devices {
  my $gs = shift;
  my @devices;
  
  open(GS, "echo 'devicenames ==' | $gs -q -dNODISPLAY|")
    or die "Could notrun $gs: $!";
  while (<GS>) {
    if (/\[(.*)\]/) {
      push @devices, grep s/^\///, split ' ', $1
    }
  }
  @devices;
}

# We are only interested in these devices. 
%DEVICE  = (
            PBM   => 'pbmraw',
            PGM   => 'pgmraw',
            PPM   => 'ppmraw',
            'G3'  => 'faxg3',
            'G4'  => 'faxg4',
            'G32' => 'faxg32d',
            PCL   => 'ljet4',
           );

print STDERR "

Checking which devices your 'gs' supports and if your cpio can write
tar files ...

";

for $path (@PATH) {
  next if $SEEN{$path}++;
  unless ($CPIO) {
    for $cpio (qw(cpio gcpio)) {
      if (-x "$path/$cpio") {
        system("$path/$cpio < /dev/null -o -H tar > /dev/null 2>&1");
        unless ($? >> 8) {
          print STDERR "$path/$cpio handles '-H tar'\n";
          $CPIO = "$path/$cpio";
          last;
        }
      }
    }
  }
  for $gs (qw(gs gs_nox)) {
    if (-x "$path/$gs") {
      $OPTION{$gs} = '-sPAPERSIZE=a4';
      my @devices = gs_devices("$path/$gs");
      my %devices;
      @devices{@devices} = @devices;
      #print STDERR "$path/$gs: @devices\n";
      for $type (sort {$DEVICE{$b} cmp $DEVICE{$a}} keys  %DEVICE) {
        $device = $DEVICE{$type};
        if ($devices{$device} and !$HAVE{$type}++) {
          printf STDERR "Adding rule PS => %-6s  '$path/$gs ...'\n", $type.',';
          $GSRULES .= "     [PS              => $type,  '$path/$gs -q -sDEVICE=$device -sOutputFile=- -'],\n";
        }
      }
    }
  }
}
#print STDERR "Adding rules:\n$GSRULES";
print OUT <<"!GROK!THIS!";
$Config{'startperl'}
!GROK!THIS!
print OUT <<'!NO!SUBS!';
eval 'exec perl -S $0 "$@"'
    if 0;
#                              -*- Mode: Perl -*- 
# pconvert -- 
# ITIID           : $ITI$ $Header $__Header$
# Author          : Ulrich Pfeifer
# Created On      : Wed Apr 10 08:37:21 1996
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Mon Apr 29 12:00:25 1996
# Language        : Perl
# Update Count    : 265
# Status          : Unknown, Use with caution!
# 
# (C) Copyright 1996, Universität Dortmund, all rights reserved.
# 
# $Locker: pfeifer $
# $Log: pconvert.PL,v $
# Revision 1.04  1996/06/13 13:44:42  pfeifer
# Added badnes() to avoid quality loss when possible. Added check for
# GNU cpio.
#
# Revision 1.03  1996/05/23 14:39:08  pfeifer
# Fixed bug with unknown extensions.
#
# Revision 1.2  1996/04/29 09:52:05  pfeifer
# Sicherung vor gs device test.
#
# Revision 1.1  1996/04/11 06:17:57  pfeifer
# Initial revision
#
# 
use Getopt::Long;
use Cwd;
use File::Basename;
use File::Path;
use Config;

$VERSION = substr(q$Revision: 1.04 $, 10);

# File-Type => [extension-regexp, head-regexp]
%TYPE = (
         GIF  => ['\.gif',	'^GIF8[79]a'],
         PS   => ['\.e?ps', '^\%!(PS-Adobe)*|TeXDict begin|\/showpage|\/\w+.*\sdef'],
         PPM  => ['\.ppm', '^(P[36])\s+'],
         PBM  => ['\.pbm', '^(P[14])\s+'],
         PGM  => ['\.pgm', '^(P[15])\s+'],
         JPG  => ['\.jpe?g', '^......JFIF'],
         TIFF => ['\.tiff?', '^((\115\115)|(\111\111))'],
         TAR  => ['\.tar'],
         POD  => ['\.(pod|pm)', '\n=head1 NAME'],
         MAN  => ['\.[0-9ln]', '\n\.TH '],
         EL   => ['\.el'],
         'G3'  => ['', '\x00014d9a8000'],
         INFO => ['\.info'],
         TEXI => ['\.texi(nfo)?$'], # '],
         HTML => ['\.html', '<HTML>|<html>'],
        );

$PS = [PS, EPS];

@RULE = 
    expand_rule 
    (
     ['G3'            => PBM,  'g3topbm'],
     [DVI             => PS,   'dvips'],
     [EL              => ELC,  '(cat > %O.$$; emacs -q -batch -f batch-byte-compile %O.$$; cat %O.$$c; rm %O.$$;)'],
     [GIF             => PPM,  'giftopnm'],
     [HTML            => LINK, '(cat > %O$$.html; GET -o links file:%O$$.html; rm %O$$.html;)'],
     [HTML            => PS,   '(cat > %O$$.html; GET -o ps file:%O$$.html; rm %O$$.html;)'],
     [JPG             => GIF,  'djpeg -gif'],
     [JPG             => PPM,  'djpeg -pnm'],
     [MAN             => DVI,  'groff -mandoc -Tdvi'],
     [MAN             => PS,   'groff -mandoc'],
     [MANIFEST        => LIST, q[awk '{printf "%O/%s\n", $1}']],
     [PBM             => 'G3', 'pbmtog3'],
     [PBM             => PGM,  'pbmtopgm'],
     [PBM             => PGM,  'pbmtopgm'],
     [PGM             => PBM,  'pgmtopbm'],
     [POD             => MAN,  '(cat > %O.$$; pod2man %O.$$; rm %O.$$;)'],
     [PPM             => TIFF, 'pnmtotiff'],
     [TAR             => DIR,  'tar xf -'],
     [TAR             => LIST, 'tar tf -'],
     [TEXI            => INFO, 'makeinfo --output -'],
     [TIFF            => PPM,  '(cat > %O.$$; tifftopnm %O.$$; rm %O.$$;)'],
     [[PPM, PGM, GIF] => JPG,  'cjpeg'],
     [[PPM, PGM, PBM] => $PS,  'pnmtops'], 
     [[PPM, PGM, PBM] => GIF,  ['ppmquant 256', 'ppmtogif']],
     [[PPM, PGM, PBM] => TIFF, 'pnmtotiff'], 
     [PPM             => PGM,  'ppmtopgm'],
     [PGM             => PPM,  'pgmtoppm'],
#    [PPM             => PBM,  ['ppmtopgm','pgmtopbm']],
!NO!SUBS!

if ($CPIO) {
  print OUT "     [DIR             => TAR,  '$CPIO -Htar -o'],\n";
  print OUT "     [LIST            => TAR,  '$CPIO -Htar -o'],\n" ;
}


print OUT $GSRULES, "\n);\n";
print OUT "\@PATH = qw(\n";
     for (@PATH) {
       print OUT "\t$_\n";
     }     
print OUT "\n\t);\n";
print OUT <<'!NO!SUBS!';
@PATH = grep !$SEEN{$_}, (@PATH, split $ENV{'PATH'}); %SEEN=();
%PROGRAM = ();
for (@RULE) {
    if (ref $_->[2]) {
        for (@{$_->[2]}) {
            my ($prg) = split;
            $PROGRAM{$prg} = 1;
        }
    } elsif ($_->[2] =~ /^\((.*)\)/) {
        my @parts = split /;/, $1;
        for (@parts) {
            my ($prg) = split;
            $PROGRAM{$prg} = 1;
        }
    } else {
        my ($prg) = split ' ', $_->[2];
        $PROGRAM{$prg}= 1;
    }
}

!NO!SUBS!
print OUT '
# default options
@opt_option = (
'
;
$OPTION{'pnmtops'} = '-rle' if find_bin('pnmtops');
for (keys %OPTION) {
  printf OUT "\t'%s=%s',\n", $_, $OPTION{$_};
}
print OUT "\t);\n";
print OUT <<'!NO!SUBS!';
&GetOptions('nono!',
            'verbose!',
            'debug!',
            'check!',           # do not trust extensions
            'isa=s',
            'option=s@',
            'remove!',
            'out=s',
            'overwrite!',       # overwrite existing output file
            'multipage!',
            'newer!',
            'gzip!',
            'to=s',
            ) || usage();

usage() unless @ARGV;

$opt_isa = uc($opt_isa);

if (defined $opt_to) {
  $opt_to  = uc($opt_to);
  unless ($VTYPE{$opt_to}) {
    # VTYPE is computed in expand_rule()
    die "Illegal output type $opt_to\n";
  }
}
                          
unless (!$opt_isa or $ITYPE{$opt_isa}) {  # ITYPE is computed in expand_rule()
    die "Illegal input type $opt_isa\n";
}
                          
for (@opt_option) {
    my ($prog, $opt) = split /=/, $_, 2;
    my $found;
    
    for (keys %PROGRAM) {
      if (m:$prog$:) {
         $OPTIONS{$_} .= $opt . ' ';
         $found++;
       }
    }
    die "$prog is not a known converter\n" unless $found;
}

my $DIR  = getcwd;
my $CDIR = $DIR;

for (@ARGV) {
    my ($name,$path) = fileparse($_);
    my ($ipipe, $nfname);
    my ($type, $bname);
    my @plan;
    my $pipe;
    local($opt_to) = $opt_to;
    maybe_chdir($DIR);
    if ($name eq MANIFEST) {
        my $top;
        my $cwd = "$DIR/$path";

        $cwd =~ s!/./!/!g; $cwd =~ s!/$!!;
        #print STDERR "($name,$path) $cwd\n";
        ($top, $path) = fileparse($cwd);
        $name = "$top/$name";
        #print STDERR "($name,$path)\n";
    }
    maybe_chdir($path);

    die "$name does not exist: $!\n" unless $opt_debug or -e $name;

    ($ipipe, $nfname) = initial_pipe($name);
    ($type, $bname)   = get_type($nfname, $ipipe);

    $type = $opt_isa || $type;
    $bname ||= $nfname;
    print STDERR "type = $type\n" if $opt_debug;
    die "Could not determine type of $_\n" unless ($type);

    unless (defined $opt_to) {
      if ($type eq TAR) {
        $opt_to = DIR;
      } elsif ($type =~ /^(DIR|MANIFEST)$/) {
        $opt_to = TAR;
      } else {
        $opt_to = PS;
      }
    }
    @plan = plan($type, $opt_to);

    die "I see no way to convert $type to $opt_to.\n" unless @plan;

    $pipe = $ipipe . '|' . join('|', @plan);

    $pipe =~ s!\%O!$bname!g;
    unless ($opt_out eq '-' or $opt_to eq DIR) {
      my $outfile = $opt_out || ($bname . '.' . lc($opt_to));

      if ($opt_multipage and $pipe =~ s/-sOutputFile=- -$//) {
        $pipe .= sprintf("-sOutputFile=%s%%03d%s -",
                         $opt_out || $bname, ($opt_out)?'':'.'.lc($opt_to));
      } else {
        if ($opt_gzip) {
          $pipe .= '|' . find_program('gzip -c', 1);
          $outfile .= '.gz' unless $outfile =~ /\.gz$/;
        }
        
        if (!$opt_overwrite and -e $outfile) {
          if ($opt_newer) {
            if ((stat($name))[9] > (stat($outfile))[9]) {
              warn "Overwriting $outfile" if $opt_verbose;
            } else {
              warn "$outfile is up to date\n" if $opt_verbose;
              next;
            }
          } else {
            die "$outfile exists\n";
          }
        }
        $pipe .= ">$outfile";
      }
    }
    if (run_cmd($pipe) and $opt_remove) {
        run_unlink($name);
    }
}

sub run_unlink {
    my $name = shift;

    if ($opt_nono || $opt_verbose) {
        if (-d $name) {
            print STDERR "  rmtree $name;\n";
        } else {
            print STDERR "  unlink $name;\n";
        }
    } 
    unless ($opt_nono) {
        if (-d $name) {
            rmtree($name) or warn "Could not unlink $name: $!\n";
        } else {
            unlink($name) or warn "Could not unlink $name: $!\n";
        }
    }
}

sub run_cmd {
    my $cmd = shift;
    
    if ($opt_nono || $opt_verbose) {
        my $pcmd = $cmd;
        $pcmd =~ s!\|!|\n    !g;
        print STDERR "  $pcmd\n";
    } 
    unless ($opt_nono) {
        my $status = system $cmd;
        if ($status >> 8) {
            die "$cmd failed: $?\n";
        }
    }
    1;
}

sub badnes {
  my @plan = @_;
  my $plan = join '|', @plan;

  if ($plan =~ /\b(gs|djpeg)\b/) {
    return @plan + 5;           # avoid using gs/djpeg even if plan gets longer
  } else {
    return @plan
  }
}
          
sub plan {
    my $type   = uc shift;
    my $target = uc shift;
    my %ignore = @_;
    my $rule;
    my @best_plan = ();

    $ignore{$type}=1;
    
    for $rule (@RULE) {
        my $from = uc $rule->[0];
        my $to   = uc $rule->[1];
        my $prg  =    $rule->[2];

        next unless $from eq $type;     # not applicable
        next unless find_program($prg); # program NAV

        if ($to eq $target) {
            return find_program($prg);
        } else {
            next if $ignore{$to};       # had that already
            my @plan = plan($to, $target, %ignore);
            if (@plan) {
                if (!@best_plan or badnes(@plan) < badnes(@best_plan) - 1) {
                    #print STDERR "plan: $from $target @best_plan => ";
                    @best_plan = (find_program($prg), @plan);
                    #print STDERR "@best_plan\n";
                }
            }
        }
    }
    if (@best_plan) {
        return (@best_plan);
    } else {
        return ();
    }
}

sub initial_pipe {
    my $file  = shift;
    my $cat;
    my $ofile = $file;

    if ($file =~ s/\.gz//) {
        $cat = find_program('gzip -cd %s', 1);
    } elsif ($file =~ s/\.Z//) {
        $cat = find_program('compress -cd %s', 1);
    } elsif (-d $file) {
        $cat = find_program('find %s -depth  -xdev -type f -print', 1);
    } else {
        $cat = find_program('cat %s', 1);
    }
    return (sprintf($cat, $ofile), $file);
}

sub get_type {
    my($name, $pipe) = @_;
    my $type;

    if ($name =~ m!([^/]+)/MANIFEST$!) {
        return (MANIFEST, $1);
    }
    unless ($opt_check) {
        # check extension
        for $type (keys %TYPE) {
            my ($ext) = $TYPE{$type}->[0];
            if ($ext and $name =~ s/$ext$//) {
                return ($type , $name);
            }
        }
        # check extension case ignored
        for $type (keys %TYPE) {
            my ($ext) = lc $TYPE{$type}->[0];
            if ($ext and $name =~ s/$ext$//i) {
                return ($type , $name);
            }
        }
    }
    if (-d $name) {
        return (DIR , $name);
    } else {
        # check the file type
        open(IN, "$pipe|") or die "Could not open $pipe|: $!\n";
        my $head;
        read(IN,$head,512);
        close IN;
        for $type (keys %TYPE) {
            my($ext, $headr) = @{$TYPE{$type}};
            next unless $headr;
            return ($type, $name) if $head =~ /$headr/;
        }
    }
    return undef;
}

sub find_program {
    my $prog     = shift;
    my $required = shift;
    my $path;

    if (ref $prog) {
        my @prgs;
        for (@{$prog}) {
            my $found = find_program($_, $required);
            return undef unless $found;
            push @prgs, $found;
        }
        return join '|', @prgs;
    }
    if ($prog =~ /^\((.*)\)/) {
        my @parts = split /;/, $1;
        my @prgs;
        for (@parts) {
            my $found = find_program($_, $required);
            return undef unless $found;
            push @prgs, $found;
        }
        return '(' . join(';', @prgs) . ')';
    }
    my ($progn, $args) = split ' ', $prog, 2;
    if (defined $PROGRAM{$progn} and $PROGRAM{$progn} != 1) {
        if ($args) {
            return($PROGRAM{$progn} . " $args");
        } else {
            return($PROGRAM{$progn});
        }
      } elsif ($progn =~ m:^/:) {
        if (-x $progn) {
          $PROGRAM{$progn}  = $progn;
          $PROGRAM{$progn} .= " $OPTIONS{$progn}"
            if $OPTIONS{$progn};
          print STDERR "PROGRAM{$progn} = $PROGRAM{$progn}\n" 
            if $opt_debug;
          if ($args) {
            return($PROGRAM{$progn} . " $args");
          } else {
            return($PROGRAM{$progn});
          }
        }
    } else {
        for $path (@PATH) {
            if (-x "$path/$progn") {
                $PROGRAM{$progn}  = "$path/$progn";
                $PROGRAM{$progn} .= " $OPTIONS{$progn}"
                    if $OPTIONS{$progn};
                print STDERR "PROGRAM{$progn} = $PROGRAM{$progn}\n" 
                    if $opt_debug;
                if ($args) {
                    return($PROGRAM{$progn} . " $args");
                } else {
                    return($PROGRAM{$progn});
                }
            }
        }
    }
    if ($required) {
        die "Could not find $progn\n";
    }
    return undef;
}
    
sub expand_rule {
    my @RULE;
    my ($rule, $from, $to);

    for $rule (@_) {
        $ITYPE{$rule->[0]}++;
        my @from = ref($rule->[0])?@{$rule->[0]}:($rule->[0]);
        my @to   = ref($rule->[1])?@{$rule->[1]}:($rule->[1]);
        my $prg  = $rule->[2];
        for $from (@from) {
            for $to (@to) {
                $VTYPE{$to}++;
                push @RULE, [$from, $to, $prg];
            }
        }
    }
    @RULE;
}


sub maybe_chdir {
    my $newdir = shift;
    return if $newdir eq './';
    return if $newdir eq $CDIR;
    if ($opt_verbose || $opt_nono) {
        print STDERR "  chdir $newdir\n";
    }
    chdir $newdir or die "Could not chdir to $newdir: $!\n";
    $CDIR = $newdir;
}

sub usage {
    my $prgs = join ' ', sort keys %PROGRAM;
    my $vtps = join ' ', sort map lc($_), keys %TYPE;
    print <<"EOU"
$0 
    [-check]                    do not trust extension
    [-debug]
    [-gzip]
    [-isa type]                 overwrite input type
    [-option program=options]   pass options to program
    [-nono]                     do not do it
    [-out filename]             output to filename
    [-newer]                    overwrite existing file if source is newer
    [-multpage]                 write a file for each page if possible
    [-overwrite]                overwrite existing file
    [-remove]                   remove original
    [-to type]                  desired output type
    [-verbose]
       [name ...]

Recognized types: directory manifest $vtps
Known filters:    $prgs
EOU
    ;
    die "\n";
}

__END__

=head1 NAME

pconvert - convert file formats

=head1 SYNOPSIS

B<pconvert>
[B<-check>]
[B<-debug>]
[B<-gzip>]
[B<-isa> I<type>]
[B<-option> I<program>=I<options>]
[B<-nono>]
[B<-out> I<filename>]
[B<-overwrite>]
[B<-newer>]
[B<-multipage>]
[B<-remove>]
[B<-to> I<type>]
[B<-verbose>]
[I<name> ...]

=head1 DESCRIPTION

B<Pconvert> determines the type of the files named on the command line
and tries to convert them to a specified type (defaults to
PostScript). It uses internal rules to find a set of commands which
can do the task.

The file type is determined by file extensions. If the extension in
not known or the B<-check> option is given, the first bytes of the
file are examined to infer a type. Files with extensions F<.gz> or F<.Z> 
are assumed to be compressed by B<gzip>(1) or B<compress>(1)
respectively and handled transparently.

=head1 OPTIONS

All options may be abbreviated.Boolean options (all options without
arguments) may be negated by prefixing them with B<no>. For example
use B<-nocheck> to enable file extension checking if your sysadmin had
set the default to B<-check>. See L<Getopts::Long> for details.

=over 10

=item B<-check>

Do not trust file extensions when determining the input file type.

=item B<-debug>

Enables some debug output. Not very useful.

=item B<-gzip>

Compress output with gzip.

=item B<-isa> I<type>

Overwrite recognized input type if any.

=item B<-option> I<program>=I<options>

Pass I<options> to the filter program I<program> if used. This option
may be repeated any number of times. The option parsing checks if
I<program> is a known filter. To learn about the valid filters, run
B<pconvert> without arguments.

=item B<-nono>

Do nothing. Just print what would have been done without B<-nono>.

=item B<-out> I<filename>

B<Pconvert> normally writes the output to a new file with the same
base name as the input file and the type appended as extension. This
can be overwritten with the B<-out> option. If I<filename> is 'C<->',
B<pconvert> writes to B<STDOUT>.

=item B<-overwrite>, B<-newer>

B<Pconvert> does not overwrite existing files unless B<-overwrite> or
B<-newer> is given. B<-overwrite> forces overwriting. B<-newer> will
overwrite only if source is newer.

=item B<-multipage>

Write one file for each input page if B<gs> is the last converter in
the pipe. B<-multipage> disables B<-gzip>, and the overwrite check. So
B<-overwrite> and B<-newer> do not have any effect.

=item B<-remove>

If B<-remove> is set, the original file is removed.

=item B<-to> I<type>

Use I<type> as desired output type. You can get a list of valid output
types when running B<pconvert> without any arguments.

=item B<-verbose>

Print commands before running them.

=back 

=head1 EXAMPLES

Here are some examples. Do not be worried about the absolute paths in
the produced commands. B<Pconvert> will search for the filters on your
system. It may find another pipe, if some of the filters are missing
on your system.

=item Converting image formats

  % pconvert -nono -to tiff ~www/pages/icons/LS6.gif
  chdir /home/robots/www/pages/icons/
  /bin/cat LS6.gif|
    /usr/local/image-tools/bin/giftopnm|
    /usr/local/image-tools/bin/pnmtotiff>LS6.tiff

If B<giftopnm> is missing, the following plan is generated:

  % pconvert -nono -to tiff ~www/pages/icons/LS6.gif
  chdir /home/robots/www/pages/icons/
  /bin/cat LS6.gif|
    /usr/local/image-tools/bin/cjpeg|
    /usr/local/image-tools/bin/djpeg -pnm|
    /usr/local/image-tools/bin/pnmtotiff>LS6.tiff

=item Generating images from postscript

  % pconvert -nono -to gif pconvert.pod 
  /bin/cat pconvert.pod|
    (/bin/cat > pconvert.$$;/usr/local/ls6/perl/bin/pod2man \
           pconvert.$$;/bin/rm pconvert.$$)|
    /usr/local/groff-1.09/bin/groff -mandoc|
    /usr/local/X11R5/bin/gs -q -sDEVICE=pbmraw -sOutputFile=- -|
    /usr/local/image-tools/bin/ppmquant 256|
    /usr/local/image-tools/bin/ppmtogif>pconvert.gif

=item Generating postscript manpages

  % pconvert -nono pconvert.pod
  /bin/cat pconvert.pod|
    (/bin/cat > pconvert.$$;/usr/local/ls6/perl/bin/pod2man \
           pconvert.$$;/bin/rm pconvert.$$)|
    /usr/local/groff-1.09/bin/groff -mandoc>pconvert.ps

=item Building a tar archive from a directory

  % pconvert -nono -to TAR -gzip image
  /bin/find image -depth  -xdev -type f -print|
    /usr/local/ls6/unsupported/bin/sun4-sunos/gcpio -Htar -o|
    /usr/local/bin/gzip -c>image.tar.gz

=item Building a tar archive from a MANIFEST file

  % pconvert -nono -to TAR -gzip image/MANIFEST
  /bin/cat image/MANIFEST|
    /bin/awk '{printf "image/%s\n", $1}'|
    /usr/local/ls6/unsupported/bin/sun4-sunos/gcpio -Htar -o|
    /usr/local/bin/gzip -c>image.tar.gz

=head1 ENVIRONMENT

C<PATH> is used in addition to build-in paths to search for programs.

=head1 SEE ALSO

B<Getopts::Long>(3),
B<awk>(1),
B<cjpeg>(1),
B<compress>(1),
B<djpeg>(1),
B<gcpio>(1),
B<giftopnm>(1),
B<gs>(1),
B<gzip>(1),
B<pbmtopgm>(1),
B<perl>(1),
B<pgmtopbm>(1),
B<pnmtops>(1),
B<pnmtotiff>(1),
B<ppmquant>(1),
B<ppmtogif>(1),
B<tar>(1),
B<tifftopnm>(1).

=head1 EXTENSION

Extension should be pretty easy. B<Help safe the world>:

=over 5

=item 

Please mail your extension to the author.

=back

=head2 New types

To add a new type, just append an entry to the C<%TYPE> hash.
Each entry should be a reference to an array containing:

=over 5

=item

B<o> the name of the type,

=item

B<o> a regular expression which matches the extension, and

=item

B<o> optionally a regular expression which matches the start of the file.

=back

Here is the definition of the B<GIF> type:

    GIF  => ['\.gif',	'^GIF8[79]a'],

=head2 Add a conversion rule.

To add a new filter, just append a an array reference to C<@RULE>. The
array should contain the I<from> and I<to> type an the name of the
filter program. Here are some examples:

     [GIF             => PPM,  'giftopnm'],
     [[PPM, PGM, PBM] => GIF,  ['ppmquant 256', 'ppmtogif']],
     [POD             => MAN,  
                  '(cat > %O.$$; pod2man %O.$$; rm %O.$$;)'],

The C<%O> is replaced by the target name (i.e. the name of the output file).


=head1 AUTHOR

Ulrich Pfeifer F<E<lt>pfeifer@ls6.informatik.uni-dortmund.deE<gt>>

!NO!SUBS!

close OUT or die "Can't close $file: $!";
chmod 0755, $file or die "Can't reset permissions for $file: $!\n";
exec("$Config{'eunicefix'} $file") if $Config{'eunicefix'} ne ':';
