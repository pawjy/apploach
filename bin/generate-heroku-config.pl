use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $Config = {};

my $cert_path = path ('mysqld_cert.pem')->absolute;
die "No |mysqld_cert.pem|" unless $cert_path->is_file;
$ENV{CLEARDB_DATABASE_URL} =~ m{^mysql://([^#?/\@:]*):([^#?/\@]*)\@([^#?/:]+)/([^#?]+)\?}
    or die "Bad |CLEARDB_DATABASE_URL| ($ENV{CLEARDB_DATABASE_URL})";
my $dsn = "dbi:mysql:host=$3;dbname=$4;user=$1;password=$2;mysql_ssl=1;mysql_ssl_ca_file=$cert_path";

$Config->{bearer} = $ENV{APP_BEARER} // die "No |APP_BEARER|";

print perl2json_bytes $Config;

## License: Public Domain.
