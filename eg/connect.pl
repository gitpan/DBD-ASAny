#!/usr/local/bin/perl -w
#
use DBI;
use strict;
my $database = "asademo";
my $data_source = "DBI:ASAny:$database";
my $username = "UID=dba;PWD=sql;ENG=asademo";
my $dbh = DBI->connect( $data_source, $username, '' );
#or die "Can't connect to $data_source: $dbh->errstr\n";
$dbh->disconnect;
exit(0);
__END__
