#!perl
use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');

BEGIN {
  $ENV{SQL_DEBUG} //= 0;
  $ENV{WEBUA_DEBUG} //= 0;
  $ENV{WEBSERVER_DEBUG} //= 0;
  $ENV{PROMISED_COMMAND_DEBUG} //= 0;
}

use Web::Host;
use ApploachSS;

my $RootPath = path (__FILE__)->parent->parent->absolute;
my $LocalPath = $RootPath->child ('local/local-server');

ApploachSS->run (
  data_root_path => $LocalPath,
  app_host => Web::Host->parse_string ('0'),
  app_port => 6315,
  mysqld_database_name_suffix => '_local',
  dont_run_xs => 1,
)->then (sub {
  my $v = $_[0];
  warn sprintf "\n\nURL: <%s>\n\n",
      $v->{data}->{app_local_url}->stringify;
  
  return $v->{done};
})->to_cv->recv;

=head1 LICENSE

Copyright 2018-2019 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
