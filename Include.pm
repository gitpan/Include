#

package Include;

use Carp;
use Config;
require Exporter;

#--- Configuration section ---

# Set to 1 to perform Auto Cache-ing
my $CACHE    = 0;

# Set to the full path of the cache directory
# Must end with dir separator
my $CACHEDIR = $Config{archlib} . "/ph-cache/"; 

# A list of paths to search for includes
my @INCPATH = ($Config{usrinc}, split(/ +/, $Config{locincpth}));

#--- End User Configuration - You should not have to change anything below this line

=head1 NAME

Include - allow use #defines from C header files

=head1 SYNOPSIS

    use Include qw(-I /some/path/of/mine);
    use Include q<sys/types.h>;
    use Include q<sys/types.h> "/[A-Z]/";

=head1 DESCRIPTION

The Include module implements a method of using #define constants from
C header files. It does this by putting an extra level of indirection
on the use operator.

To enhance performance a cache scheme is used. When a new module is
required the cache is checked first, if the package is not found then
it will be generated from the C header files.

Include can be configured to place any generated packages into the cache
automatically, for security reasons this is turned off by default.

There are three ways in which the C<use Include> statement can be used.

    use Include qw(-I /some/path/of/mine);

Will unshift the directory I</some/path/of/mine> onto the search path used
so that subsequent searches for .h header files will search the given
directories first.

    use Include q<sys/types.h>;
    use Include q<sys/types.h> "/[A-Z]/";

Both of these will define all the constants found in <sys/types.h> and
any header files included by it. The first will export all of these
into the calling package, but the second will only export defined
macros that contain an unppercase character.

=head2 Subroutines

Under normal use the Include package is only used via the use/import interface.
But there are some routines that are defined.

=over 4

=item CacheOn

This subroutine will cause the Include module to save any generated packages
into the cache.

=item Generate( @headers )

This subroutine will force the generation of the given header files, and
any files included in them, reguardless of whether they are currently in
the cache. If cache writing is turned on then the cache files will be 
overwritten.

=item Search( @dirs )

This subroutine will unshift the given directories onto the search
path used for locating the header files.

=back

=head1 NOTE

Having the cache writing turned on by default if a potential security
risk as all users will need write rights to the cache directory

=head1 AUTHOR

Graham Barr <Graham.Barr@tiuk.ti.com>

=head1 REVISION

$Revision: 1.2 $

=head1 BUGS

None known

=head1 COPYRIGHT

Parsing code is based on the h2ph program which comes with the perl
distribution. All other code is Copyright (c) 1995 Graham Barr. All
rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
$VERSION = $VERSION;

my $GENERATE = 0;

my %include = ();

my %isatype = ();
my @isatype = qw(char	uchar	u_char
		 short	ushort	u_short
		 int	uint	u_int
		 long	ulong	u_long
		 FILE
                );
@isatype{@isatype} = (1) x @isatype;

sub CacheOn { $CACHE = 1; }

my($new,%curargs,$args,$name);

sub _expr {
  while ($_ ne '') {
    while(s/\*\s*\(([^)]*)\)/*{$1}/) {}; # Change *(x) -> *{x}
    s/^(\s+)//              && do {$new .= ' '; next;};
    s/^(0x[0-9a-fA-F]+)//   && do {$new .= $1; next;};
    s/^(\d+)//              && do {$new .= $1; next;};
    s/^("(\\"|[^"])*")//    && do {$new .= $1; next;};
    s/^'((\\"|[^"])*)'//    && do {
      if ($curargs{$1}) {
        $new .= "ord('\$$1')";
      }
      else {
        $new .= "ord('$1')";
      }
      next;
    };
    s/^sizeof\s*\(([^)]+)\)/{$1}/ && do {
      $new .= '$sizeof';
      next;
    };
    s/^([_a-zA-Z]\w*)//     && do {
      my $id = $1;
      if ($id eq 'struct') {
        s/^\s+(\w+)//;
        $id .= ' ' . $1;
        $isatype{$id} = 1;
      }
      elsif ($id eq 'unsigned') {
        s/^\s+(\w+)//;
        $id .= ' ' . $1;
        $isatype{$id} = 1;
      }
      if ($curargs{$id}) {
        $new .= '$' . $id;
      }
      elsif ($id eq 'defined') {
        $new .= 'defined';
      }
      elsif (/^\(/) {
        s/^\((\w),/("$1",/ if $id =~ /^_IO[WR]*$/i;     # cheat
        $new .= " &$id";
      }
      elsif ($isatype{$id}) {
        if ($new =~ /{\s*$/) {
          $new .= "'$id'";
        }
        elsif ($new =~ /\(\s*$/ && /^[\s*]*\)/) {
          $new =~ s/\(\s*$//;
          s/^[\s*]*\)//;
        }
        else {
          $new .= $id;
        }
      }
      else {
        $new .= ' &' . $id;
      }
      next;
    };
    s/^(.)// && do {$new .= $1; next;};
  }
}

sub _read {
  my $file = shift;
  my $pkg = shift;
  my $ph = shift;
  local *IN;
  my $tab = 0;
  my $t = "\t" x ($tab / 8) . ' ' x ($tab % 8);

  my $code = "#
# This file was auto generated by Include.pm
# Any modifications made here will be lost

package $pkg;
require Include;
require Exporter;

no strict qw(refs subs vars);

\@ISA = qw(Exporter);
\@EXPORT = ();

";

  my $dir = (grep(-r "$_/$file", @INCPATH))[0];

  defined $dir && open(IN,"$dir/$file") or
    croak "Can't open <$file>: $!\n";

  while (<IN>) {
    chop;
    while (/\\$/) {
      chop;
      $_ .= <IN>;
      chop;
    }
    if (s:/\*:\200:g) {
      s:\*/:\201:g;
      s/\200[^\201]*\201//g;      # delete single line comments
      if (s/\200.*//) {           # begin multi-line comment?
        $_ .= '/*';
        $_ .= <IN>;
        redo;
      }
    }
    if (s/^#\s*//) {
      if (s/^define\s+(\w+)//) {
        $name = $1;
        $new = '';
        s/\s+$//;
        if (s/^\(([\w,\s]*)\)//) {
          $args = $1;
          if ($args ne '') {
            my $arg;
            foreach $arg (split(/,\s*/,$args)) {
              $arg =~ s/^\s*([^\s].*[^\s])\s*$/$1/;
              $curargs{$arg} = 1;
            }
            $args =~ s/\b(\w)/\$$1/g;
            $args = "local($args) = \@_;\n$t    ";
          }
          s/^\s+//;
          _expr();
          $new =~ s/(["\\])/\\$1/g;
          if ($t ne '') {
            $new =~ s/(['\\])/\\$1/g;
            $code .= $t .
              "eval 'sub $name {\n$t    ${args}eval \"$new\";\n$t}';\n";
          }
          else {
            $code .= "sub $name {\n    ${args}eval \"$new\";\n}\n";
          }
          $code .= $t . "push(\@EXPORT, \"$name\");\n";
          %curargs = ();
        }
        else {
          s/^\s+//;
          _expr();
          $new = 1 if $new eq '';
          if ($t ne '') {
            $new =~ s/(['\\])/\\$1/g;
            $code .= $t . "eval 'sub $name {" . $new . ";}';\n";
          }
          else {
            $code .= $t . "sub $name {" . $new . ";}\n";
          }
          $code .= $t . "push(\@EXPORT, \"$name\");\n";
        }
      }
      elsif (/^include\s+<(.*)>/) {
        $code .= $t . "my \$incpkg = Include->import( '$1' );\n";
        $code .= $t . 'push(@EXPORT, @{$incpkg . "::EXPORT"});' . "\n";
      }
      elsif (/^ifdef\s+(\w+)/) {
        $code .=  $t . "if (defined &$1) {\n";
        $tab += 4;
        $t = "\t" x ($tab / 8) . ' ' x ($tab % 8);
      }
      elsif (/^ifndef\s+(\w+)/) {
        $code .=  $t . "if (!defined &$1) {\n";
        $tab += 4;
        $t = "\t" x ($tab / 8) . ' ' x ($tab % 8);
      }
      elsif (s/^if\s+//) {
        $new = '';
        _expr();
        $code .=  $t . "if ($new) {\n";
        $tab += 4;
        $t = "\t" x ($tab / 8) . ' ' x ($tab % 8);
      }
      elsif (s/^elif\s+//) {
        $new = '';
        _expr();
        $tab -= 4;
        $t = "\t" x ($tab / 8) . ' ' x ($tab % 8);
        $code .=  $t . "}\n${t}elsif ($new) {\n";
        $tab += 4;
        $t = "\t" x ($tab / 8) . ' ' x ($tab % 8);
      }
      elsif (/^else/) {
        $tab -= 4;
        $t = "\t" x ($tab / 8) . ' ' x ($tab % 8);
        $code .=  $t . "}\n${t}else {\n";
        $tab += 4;
        $t = "\t" x ($tab / 8) . ' ' x ($tab % 8);
      }
      elsif (/^endif/) {
        $tab -= 4;
        $t = "\t" x ($tab / 8) . ' ' x ($tab % 8);
        $code .=  $t . "}\n";
      }
    }
  }

  close(IN);

  $code .= "\n1;\n";

  eval $code;

  croak $@ if $@;

  if($CACHE) { # Cache the code
   my $path;
   local *PH;
   

   require File::Path;
   ($path = $ph) =~ s,/[^/]+$,,;

   File::Path::mkpath($path);

   ## Really want File::Lock here :-)
   
   if(open(PH,">$ph")) {
    print PH $code;
    close(PH);
   }
   elsif($GENERATE) {
    croak "Cannot open '$ph': $!";
   }

  }

  return $pkg;
}

sub _include {
 my $file = shift;
 my($ph,$pkg);

 ($pkg = "Include::$file") =~ s,/+,::,g;
 $pkg =~ s/.h//;

 ($ph = $CACHEDIR . $file) =~ s/\.h$/.ph/;

 if(!$GENERATE && -e $ph) {
  require $ph;

  return $pkg;
 }

 _read($file,$pkg,$ph);
}

sub Generate {
 my($file,$pkg,$ph);

 # We use a global here so that as we C<eval> each package it will force
 # the generation of all sub header files

 $GENERATE = 1;

 foreach $file (@_) {
  $include{$file} = _include($file)
 }

 $GENERATE = 0;
}

sub Search {
 unshift(@INCPATH, @_);
}

sub import {
  my $pkg = shift;

  return unless( @_ );

  my $file = shift;

  return unshift(@INCPATH, @_)
    if($file eq '-I');

  $include{$file} = _include($file)
    unless(exists $include{$file});

  if(defined $include{$file}) {
    $Exporter::ExportLevel++;
    $include{$file}->import( @_ );
    $Exporter::ExportLevel--;
  }
}

1;

