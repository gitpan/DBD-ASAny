# Makefile.PL for Adaptive Server Anywhere DBD driver

use ExtUtils::MakeMaker;
use Getopt::Long;

require 5.004;

use strict;

# This DBI must be installed before we can build a DBD.
# For those not using Dynamic loading this means building a
# new static perl in the DBI directory by saying 'make perl'
# and then using _that_ perl to make this one.
use DBI;
use DBI::DBD;	# DBD creation tools
use Config;
if( $Config{osname} eq "MSWin32" ) {
    eval 'use Win32::Registry;';
}

my $dbi_dir      = dbd_dbi_dir();
my $dbi_arch_dir = dbd_dbi_arch_dir();
my $os = $^O;
my $osvers = $Config{osvers};
$osvers =~ s/^\s*(\d+\.\d+).*/$1/;	# drop sub-sub-version: 2.5.1 -> 2.5

my %opts = (
    NAME => 'DBD::ASAny',
    VERSION_FROM => 'ASAny.pm',
    OBJECT => 'ASAny.o dbdimp.o',
    clean => {	FILES=> 'ASAny.xsi' },
    dist  => {	DIST_DEFAULT	=> 'clean distcheck disttest ci tardist',
		PREOP		=> '$(MAKE) -f Makefile.old distdir',
		COMPRESS	=> 'gzip -v9', SUFFIX => 'gz',
    },
);
if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $opts{AUTHOR} = 'Tim Bunce and John Smirnios (smirnios@sybase.com)';
    $opts{ABSTRACT} = 'Adaptive Server Anywhere DBD driver';
    $opts{PREREQ_PM} = { DBI => 0 };
    $opts{CAPI} = 'TRUE' if $Config{archname} =~ /-object\b/i;
}

$opts{LINKTYPE} = 'static' if $Config{dlsrc} =~ /dl_none/;

# Options (rarely needed)
$::opt_g = '';	# enable debugging (-g for compiler and linker)

GetOptions(qw(g!))
	or die "Invalid arguments";

$::opt_g &&= '-g';	# convert to actual string

# --- Introduction

print "\nConfiguring DBD::ASAny ...\n";

# --- Where is ASA installed...

my $dblib;
my $sqlpp_platform;

if( $Config{osname} eq "MSWin32" ) {
    $sqlpp_platform = "WINNT";
} else {
    $sqlpp_platform = "UNIX";
}

my @install_dirs;

if( defined $ENV{ASANY} ) {
    push( @install_dirs, $ENV{ASANY} );
}

my $location;
my $key;
my $type;
my $ver;
if( $Config{osname} eq "MSWin32" ) {
    foreach $ver ( ("9.0","8.0","7.0","6.0") ) {
	if( $main::HKEY_CURRENT_USER->Open( "Software\\Sybase\\Adaptive Server Anywhere\\${ver}", $key ) ) {
	    if( $key->QueryValueEx( 'Location', $type, $location ) ) {
		push( @install_dirs, $location );
	    }
	    $key->Close();
	}
	if( $main::HKEY_LOCAL_MACHINE->Open( "SOFTWARE\\Sybase\\Adaptive Server Anywhere\\${ver}", $key ) ) {
	    if( $key->QueryValueEx( 'Location', $type, $location ) ) {
		push( @install_dirs, $location );
	    }
	    $key->Close();
	}
    }
} else {
    push( @install_dirs, "/opt/SYBSsa9" );
    push( @install_dirs, "/opt/SYBSasa9" );
    push( @install_dirs, "/opt/SYBSsa8" );
    push( @install_dirs, "/opt/SYBSasa8" );
    push( @install_dirs, "/opt/SYBSsa7" );
    push( @install_dirs, "/opt/SYBSasa7" );
    push( @install_dirs, "/opt/SYBSsa6" );
    push( @install_dirs, "/opt/SYBSasa6" );
}

my $ASA = "";
my $asa_version_major = "";
my $dir;
my $found = 0;

foreach $dir ( @install_dirs ) {
    next if $dir eq "";

    if( $Config{osname} eq "MSWin32" ) {
	if( -d "${dir}/win32/lib" &&
	    -d "${dir}/h" ) {
	    foreach $ver ( (9,8,7,6) ) {
		if( -e "${dir}/win32/dbeng${ver}.exe" ) {
		    $ASA = $dir;
		    $asa_version_major = $ver;
		    $found = 1;
		    last;
		}
	    }
	}
    } else {
	if( -d "${dir}/lib" &&
	    -d "${dir}/bin" &&
	    -d "${dir}/include" ) {
	    foreach $ver ( (9,8,7,6) ) {
		if( -e "${dir}/bin/dbeng${ver}" ) {
		    $ASA = $dir;
		    $asa_version_major = $ver;
		    $found = 1;
		    last;
		}
	    }
	}
    }
    last if $found;
}

if( !$found ) {
    die "** Unable to find Adaptiver Server Anywhere installation\n\n** Please set ASANY.\n";
}

print "Using ASA version ${asa_version_major} in $ASA\n";

if( $Config{osname} eq "MSWin32" ) {
    $dblib = "dblibtm";
} else {
    $dblib = "dblib${asa_version_major}";
}

my $is_gcc;
if( "$Config{cc}" eq "gcc" ||
    "$Config{gccversion}" ne "" ) {
    $is_gcc = 1;
    printf( "Using GNU compiler\n" ); 
} else {
    $is_gcc = 0;
    printf( "Using non-GNU compiler %s\n", $Config{cc} ); 
}

my $perllib;
$perllib = $Config{libperl};
if( $Config{osname} ne "MSWin32" ) {
    $perllib =~ s/^lib//;
}
$perllib =~ s/\..*//;

my $sysliblist;
my $libdir;
$sysliblist = "";
if( $Config{osname} eq "MSWin32" ) {
    $sysliblist .= qq( -L"$ASA/win32/lib" );
    $sysliblist .= qq( -L"$Config{archlibexp}/CORE" );
    foreach $libdir ( split( /;/, $ENV{LIB} ) ) {
	$sysliblist .= qq( -L"$libdir" );
    }
} else {
    $sysliblist .= "-L$ASA/lib ";
    $sysliblist .= "-L$Config{archlibexp}/CORE ";
}

$sysliblist .= " -l${dblib}";
# On UNIX platforms, leave the perllib symbols unresolved and
# get them from the perl executable at runtime. Libperl.a is not
# built as relocatable code so linking against it now will leave
# relocations in a shared object which is forbidden on some
# platforms.
$opts{CCFLAGS} = $Config{ccflags};	
if( $Config{osname} eq "MSWin32" ) {
    $sysliblist .= " -l${perllib}";
} elsif( "$Config{osname}" eq "solaris" ) {
    $sysliblist .= " -lsocket -lnsl -lm -lc";
    if( $is_gcc ) {
#	$opts{dynamic_lib}{OTHERLDFLAGS} .= " -Wl,-z,defs";
    } else {
	$opts{CCFLAGS} .= " -xCC -g";
#	$opts{dynamic_lib}{OTHERLDFLAGS} .= " -z defs";
    }
} elsif( "$Config{osname}" eq "hpux" ) {
    if( ! $is_gcc ) {
	$opts{CCFLAGS} =~ s/-Aa\s*//;
    }
} elsif( "$Config{osname}" eq "aix" ) {
    if( ! $is_gcc ) {
	$opts{CCFLAGS} .= " -qcpluscmt"
    }
} 

if( $is_gcc ) {
#    $opts{dynamic_lib}{OTHERLDFLAGS} .= ' -shared';
}

$opts{LIBS} = [ $sysliblist ];
if( $Config{osname} eq "MSWin32" ) {
    $opts{INC}  = qq( -I"$ASA/h" );
    $opts{INC}  .= qq( -I"$Config{sitearchexp}/auto/DBI" );
    $opts{DEFINE} .= ' -DWINNT';
} else {
    $opts{INC}  = "-I$ASA/include ";
    $opts{INC}  .= "-I$Config{sitearchexp}/auto/DBI";
    $opts{DEFINE} .= ' -DUNIX';
}
#$opts{OPTIMIZE}="-g";

# uncomment log key platform information to help me help you quickly
print "System: perl$] @Config{qw(myuname archname dlsrc)}\n";
print "Compiler: @Config{qw(cc optimize ccflags)}\n";

WriteMakefile(%opts);

exit 0;

sub MY::postamble {
    return( dbd_postamble(@_) .
"
dbdimp.c: dbdimp.sqc
	sqlpp -q -n -o ${sqlpp_platform} dbdimp.sqc dbdimp.c
" );
}

__END__
