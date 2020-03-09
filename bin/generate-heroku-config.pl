use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $Config = {};

my $cert_path = path (__FILE__)->parent->parent->child ('local/cert.pem')->absolute;

$ENV{CLEARDB_DATABASE_URL} =~ m{^mysql://([^#?/\@:]*):([^#?/\@]*)\@([^#?/:]+)/([^#?]+)\?}
    or die "Bad |CLEARDB_DATABASE_URL| ($ENV{CLEARDB_DATABASE_URL})";
$Config->{dsn} = "dbi:mysql:host=$3;dbname=$4;user=$1;password=$2;mysql_ssl=1;mysql_ssl_ca_file=$cert_path";

$Config->{bearer} = $ENV{APP_BEARER} // die "No |APP_BEARER|";

$Config->{ikachan_url_prefix} = $ENV{APP_IKACHAN_URL_PREFIX}; # or undef
$Config->{ikachan_channel} = $ENV{APP_IKACHAN_CHANNEL};
$Config->{ikachan_message_prefix} = $ENV{APP_IKACHAN_MESSAGE_PREFIX};

$Config->{s3_aws4} = [split /\s+/, $ENV{APP_S3_AWS4}];
$Config->{s3_sts_role_arn} = $ENV{APP_S3_STS_ROLE_ASN};
$Config->{s3_bucket} = $ENV{APP_S3_BUCKET};
$Config->{s3_form_url} = $ENV{APP_S3_FORM_URL};
$Config->{s3_file_url_prefix} = $ENV{APP_S3_FILE_URL_PREFIX};

$Config->{push_application_server_key_public} = [split /,/, $ENV{APP_PUSH_PUBLIC_KEY}];
$Config->{push_application_server_key_private} = [split /,/, $ENV{APP_PUSH_PRIVATE_KEY}];

print perl2json_bytes $Config;

## License: Public Domain.
