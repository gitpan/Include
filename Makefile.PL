# This -*- perl -*- script makes the Makefile
# $Id: Makefile.PL,v 1.3 1996/01/04 12:56:50 gbarr Exp $

use ExtUtils::MakeMaker;
use ExtUtils::Manifest qw(maniread);
use lib qw(. ./lib);

#--- Configuration section ---

%install_pgm =  (
		 'bin/h2ph' => 1
		);

#--- End User Configuration - You should not have to change anything below this line

require 5.001;
use Getopt::Std;

$NAME     = 'Include';
$RELTYPE  = "a";

%chk_install = ();
$lib_only    = 0;

#--- End Configuration
#--- MY package
{
 package MY;

 sub libscan {
  return '' if m,/(RCS|CVS)/, || m,[~%]$, || m,\.(orig|rej)$,;
  $_;
 }
}
#--- End MY package

;# Package => [ $VERSION, $must ]
;#   $must = 1, must have
;#   $must = 0, reccomended

sub check_installation {
 my %pkg = @_;
 my $abort = 0;
 my $pkg;

 return unless @_;

 print "Checking your installation ...\n";

 foreach $pkg (keys %pkg) 
  {
   { eval "package dummy; require $pkg"; }

   my $ins_ver;
   my($version,$must) = @{$pkg{$pkg}};
   $version = sprintf("%.02f",$version);

   $ins_ver = defined ${$pkg . "::VERSION"}
                ? sprintf("%.02f",${$pkg . "::VERSION"})
                : undef;

   printf " %s %s, ",$pkg, (defined $ins_ver ? "Found v" . $ins_ver
                                             : "NOT FOUND");

   $ins_ver = "0.00" unless(defined $ins_ver);

   if($ins_ver < $version)
    {
     $abort += $must;
     printf "%s v%s\n", $must ? "REQUIRE " : "Recommend ", $version;
    }
   else
    {
     print "OK\n";
    }
  }

 die "Abort\n" if $abort;

 print "Done.\n";
}

sub initialize {
 local($_);

 check_installation(%chk_install)
  if(%chk_install);

 my $manifest = maniread();

 my %PL_FILES = ();
 my %EXE_FILES = ();
 my %macro = ();

 foreach (keys %$manifest) {
  $PL_FILES{$_} = $1 if(/(.*)\.PL\Z/ && !/^Makefile.PL$/);

  if((m#\bbin/# && !m#demo#) || m#\.PL\Z#) {
   my $f = $_;

   $f =~ s#\.PL$##;

   if(defined $install_pgm{$f} && $install_pgm{$f}) {
    $EXE_FILES{$f} = 1 if(-x $f || -f "$f.PL");
   }
  }
 }

 %EXE_FILES = () if($lib_only);

 unless(defined $VERSION) {
  my($pm,$rcs);

  ($pm = $NAME . ".pm") =~ s,::,/,g;
  $pm = "lib/" . $pm unless(-f $pm);

  $VERSION  =  eval { require "./$pm"; ${"${NAME}::VERSION"} } || "0.00";
  
  ($rcs = $pm) =~ s:([^/]+\.pm):RCS/$1,v:;

  # update VERSION when checked in
  $macro{CONFIGDEP} = $rcs
    if(-f $rcs);
 }

 $VERSION .= $RELTYPE if(defined $RELTYPE);

 my $hash = {
	VERSION   => $VERSION,
	NAME      => $NAME,
	SKIP      => [qw(static dynamic linkext)],
	PL_FILES  => \%PL_FILES,
	EXE_FILES => [ keys %EXE_FILES ],
	LINKTYPE  => 'dynamic',

	'dist'    => {COMPRESS => 'gzip -9f',
		      SUFFIX   => 'gz', 
		      POSTOP   => 'mv $(DISTNAME)-$(VERSION).tar.gz ../',
		      DIST_DEFAULT => 'all tardist',
		      CI => 'ci -l'
		     },

	'clean'   => {FILES => join(" ", qw(*% *.html *.bak *.old lib/*% lib/*/*%),values %PL_FILES)},
 };

 $hash->{macro} = \%macro if(%macro);
 $hash->{DISTNAME} = $DISTNAME if(defined $DISTNAME);
 $hash;
}


# -- Make the Makefile

my $hash = initialize();
WriteMakefile( %$hash ) ;


