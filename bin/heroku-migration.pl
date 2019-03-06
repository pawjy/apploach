use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use JSON::PS;
use Promise;
use Promised::Flow;
use Promised::File;
use ServerSet::Migration;

my $mysqld_db_names = [qw(apploach)];
my $mysqld_database_schema_path = path (__FILE__)->parent->parent->child ('db');

my $Config = json_bytes2perl path ($ENV{APP_CONFIG})->slurp;
my $get_dsn = sub {
  return $Config->{dsn};
};

Promise->resolve->then (sub {
  return promised_for {
    my $name = shift;
    return Promised::File->new_from_path ($mysqld_database_schema_path->child ("$name.sql"))->read_byte_string->then (sub {
      return ServerSet::Migration->run ($_[0] => $get_dsn->($name));
    });
  } $mysqld_db_names;
})->to_cv->recv;

## License: Public Domain.
