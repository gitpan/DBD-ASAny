require 5.002;


$DBD::ASAny::VERSION = '1.04';

{
    package DBD::ASAny;

    use DBI ();
    use DynaLoader ();
    use Exporter ();
    @ISA = qw(DynaLoader Exporter);

    my $Revision = substr(q$Revision: 1.57 $, 10);

    require_version DBI 0.92;

    bootstrap DBD::ASAny $VERSION;

    $err = 0;		# holds error code   for DBI::err    (XXX SHARED!)
    $errstr = "";	# holds error string for DBI::errstr (XXX SHARED!)
    $drh = undef;	# holds driver handle once initialised

    sub driver{
	return $drh if $drh;
	my($class, $attr) = @_;

	$class .= "::dr";

	# not a 'my' since we use it above to prevent multiple drivers

	$drh = DBI::_new_drh($class, {
	    'Name' => 'ASAny',
	    'Version' => $VERSION,
	    'Err'    => \$DBD::ASAny::err,
	    'Errstr' => \$DBD::ASAny::errstr,
	    'Attribution' => 'ASAny DBD by John Smirnios',
	    });

	$drh;
    }

    1;
}


{   package DBD::ASAny::dr; # ====== DRIVER ======
    use strict;

    sub connect {
	my($drh, $dbname, $user, $auth)= @_;

	# NOTE!
	# 
	# For ASA, $user must contain a connection string.
	# $dbname and $auth are ignored.

	# create a 'blank' dbh
	my $dbh = DBI::_new_dbh($drh, {
	    'Name' => $dbname,
	    'USER' => $user, 'CURRENT_USER' => $user,
	    });

	# Call ASAny connect func in ASAny.xs file
	# and populate internal handle data.

	DBD::ASAny::db::_login($dbh, $dbname, $user, $auth)
	    or return undef;

	$dbh;
    }
}


{   package DBD::ASAny::db; # ====== DATABASE ======
    use strict;

    sub prepare {
	my($dbh, $statement, @attribs)= @_;

	# create a 'blank' sth

	my $sth = DBI::_new_sth($dbh, {
	    'Statement' => $statement,
	    });

	# Call ASAny OCI oparse func in ASAny.xs file.
	# (This will actually also call oopen for you.)
	# and populate internal handle data.

	DBD::ASAny::st::_prepare($sth, $statement, @attribs)
	    or return undef;

	$sth;
    }


    sub ping {
	my($dbh) = @_;
	# we know that DBD::ASAny prepare does a describe so this will
	# actually talk to the server and is a valid and cheap test.
	return 1 if $dbh->prepare("select 1");
	return 0;
    }


    sub table_info {
	my($dbh) = @_;		# XXX add qualification

	my $sth = $dbh->prepare("select
	    NULL as TABLE_QUALIFIER,
	    u.user_name as TABLE_OWNER,
	    t.table_name as TABLE_NAME,
	    (if t.table_type = 'BASE' then (if t.creator = 0 then 'SYSTEM ' else '' endif) ||'TABLE'
		else (if t.table_type = 'GBL TEMP' then 'GLOBAL TEMPORARY' 
		      else t.table_type
		      endif)
		endif) as TABLE_TYPE,
	    t.remarks as REMARKS
	from SYSTABLE t, SYSUSERPERM u
	where t.creator = u.user_id
	") or return undef;
	$sth->execute or return undef;
	$sth;
    }

    sub type_info_all {
	return undef;
    }
}   # end of package DBD::ASAny::db


{   package DBD::ASAny::st; # ====== STATEMENT ======

    # all done in XS
}

1;

__END__

