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
my @subdirs;
my $install_dir;
my $subdir;
my $found_dir;

if( defined $ENV{ASANY} ) {
    push( @install_dirs, $ENV{ASANY} );
}

my $location;
my $key;
my $type;
if( $Config{osname} eq "MSWin32" ) {
    if( $main::HKEY_CURRENT_USER->Open( 'Software\Sybase\Adaptive Server Anywhere\7.0', $key ) ) {
	if( $key->QueryValueEx( 'Location', $type, $location ) ) {
	    push( @install_dirs, $location );
	}
	$key->Close();
    }
    if( $main::HKEY_LOCAL_MACHINE->Open( 'SOFTWARE\Sybase\Adaptive Server Anywhere\7.0', $key ) ) {
	if( $key->QueryValueEx( 'Location', $type, $location ) ) {
	    push( @install_dirs, $location );
	}
	$key->Close();
    }
    if( $main::HKEY_CURRENT_USER->Open( 'Software\Sybase\Adaptive Server Anywhere\6.0', $key ) ) {
	if( $key->QueryValueEx( 'Location', $type, $location ) ) {
	    push( @install_dirs, $location );
	}
	$key->Close();
    }
    if( $main::HKEY_LOCAL_MACHINE->Open( 'SOFTWARE\Sybase\Adaptive Server Anywhere\6.0', $key ) ) {
	if( $key->QueryValueEx( 'Location', $type, $location ) ) {
	    push( @install_dirs, $location );
	}
	$key->Close();
    }
    
    push( @subdirs, "win32/lib" );
    push( @subdirs, "h" );
} else {
    push( @install_dirs, "/opt/SYBSasa7" );
    push( @install_dirs, "/opt/SYBSasa6" );
    push( @subdirs, "lib" );
    push( @subdirs, "bin" );
    push( @subdirs, "include" );
}

my $ASA = "";
foreach $install_dir ( @install_dirs ) {
    if( $install_dir ne "" ) {
	$found_dir = 1;
	foreach $subdir ( @subdirs ) {
	    if( ! (-d "$install_dir/$subdir") ) {
		$found_dir = 0;
		last;
	   }
	}
	if( $found_dir ) {
	    $ASA = $install_dir;
	    last;
        }
    }
}

my $asa_version_major;

$asa_version_major = "";
if( $Config{osname} eq "MSWin32" ) {
    if( -e "$ASA/win32/dbeng7.exe" ) {
	$asa_version_major = 7;
    } elsif( -e "$ASA/win32/dbeng6.exe" ) {
	$asa_version_major = 6;
    } else {
	printf( "Cannot determine ASA version\n" );
	exit( 1 );
    }
} else {
    if( -e "$ASA/bin/dbeng7" ) {
	$asa_version_major = 7;
    } elsif( -e "$ASA/bin/dbeng6" ) {
	$asa_version_major = 6;
    } else {
	printf( "Cannot determine ASA version\n" );
	exit( 1 );
    }
}


if( $Config{osname} eq "MSWin32" ) {
    $dblib = "dblibtm";
} else {
    $dblib = "dblib${asa_version_major}";
}

if( "$ASA" eq "" ) {
    die "** Unable to find Adaptiver Server Anywhere installation\n\n** Please set ASANY.\n";
}

print "Using ASA in $ASA\n";

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
