# This -*- perl -*- script that outputs eveything found after __DATA__ prefixed
# with the correct #! line for perl

use Config;
use Cwd;

($script = $0) =~ s/\.PL$//;

unlink($script);

open OUT, ">$script" or
  die "open for writing $script: $!";

print OUT "#!$Config{'scriptdir'}/perl -w\n";

print OUT <DATA>;

close(OUT);

chmod(0755, $script);

__DATA__
use Getopt::Long;
use Include;

$Getopt::Long::ignorecase = 0;

GetOptions('I=s@') ||
 die "usage: $0 [-I dir] headers\n";

Include::Search(@opt_I) if( @opt_I );

Include::CacheOn;

Include::Generate(@_);

=head1 NAME

cache_ph - Generate and cache perl versions og C header files

=head1 SYNOPSIS

    cache_ph [-I <dir>] headers ...

=head1 DESCRIPTION

cache_ph will force the generation of the perl code which represents the given
header files and all headers included by them. The code that is generated
will be written into the cache directory.

=head1 OPTIONS

=item -I dir 

add dir to the begining of the list of directories to be searched for header
files.

=head1 AUTHOR

Graham Barr <Graham.Barr@tiuk.ti.com>

=head1 REVISION

$Revision: 1.1 $

=head1 BUGS

None known

=head1 COPYRIGHT

Copyright (c) 1995 Graham Barr. All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

