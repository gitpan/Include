#

package Include;

use Carp;
require Exporter;

$VERSION  = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use strict;

my @include = qw(/usr/include /usr/local/include);
my %include = ();

my %isatype = ();
my @isatype = qw(char	uchar	u_char
		 short	ushort	u_short
		 int	uint	u_int
		 long	ulong	u_long
		 FILE
                );
@isatype{@isatype} = (1) x @isatype;

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

sub _include {
  my $file = shift;
  my $pkg;
  local *IN;
  my $tab = 4;
  my $t = "\t" x ($tab / 8) . ' ' x ($tab % 8);

  ($pkg = "Include::$file") =~ s,/+,::,g;
  $pkg =~ s/.h//;

  my $code = "
{
    package $pkg;
    require Include;
    require Exporter;
    no strict qw(refs subs vars);
    \@ISA = qw(Exporter);
    \@EXPORT = ();
";

  my $dir = (grep(-r "$_/$file", @include))[0];

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

  $code .= "1;\n}\n";

  eval $code;

  croak $@ if $@;

  return $pkg;
}

sub import {
  my $pkg = shift;
  my $file = shift;

  return unshift(@include, @_)
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

