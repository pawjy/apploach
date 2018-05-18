use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $Config = {};

my $cert_path = path ('mysqld_cert.pem')->absolute;
my $cert = $ENV{CLEARDB_CERT} // die "No |CLEARDB_CERT|";
$cert_path->spew ($cert);

$ENV{CLEARDB_DATABASE_URL} =~ m{^mysql://([^#?/\@:]*):([^#?/\@]*)\@([^#?/:]+)/([^#?]+)\?}
    or die "Bad |CLEARDB_DATABASE_URL| ($ENV{CLEARDB_DATABASE_URL})";
my $dsn = "dbi:mysql:host=$3;dbname=$4;user=$1;password=$2;mysql_ssl=1;mysql_ssl_ca_file=$cert_path";

$Config->{bearer} = $ENV{APP_BEARER} // die "No |APP_BEARER|";

$Config->{ikachan_url_prefix} = $ENV{APP_IKACHAN_URL_PREFIX}; # or undef
$Config->{ikachan_channel} = $ENV{APP_IKACHAN_CHANNEL};
$Config->{ikachan_message_prefix} = $ENV{APP_IKACHAN_MESSAGE_PREFIX};

print perl2json_bytes $Config;

## License: Public Domain.
