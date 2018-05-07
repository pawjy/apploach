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

use Promised::Flow;
use ServerSet;

my $RootPath = path (__FILE__)->parent->parent->absolute;
my $LocalPath = $RootPath->child ('local/local-server');

my ($r_dw, $s_dw) = promised_cv;

ServerSet->run (
  data_root_path => $LocalPath,
)->then (sub {
  my $v = $_[0];
  #XXX warn sprintf "\n\nURL: <%s>\n\n";
  warn "started";
  
  return $v->{done};
})->to_cv->recv;

=head1 LICENSE

Copyright 2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
