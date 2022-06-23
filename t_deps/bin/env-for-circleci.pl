use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/modules/*/lib');
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use AbortController;
use ApploachSS;

my $RootPath = path (__FILE__)->parent->parent->parent;

my $ac = AbortController->new;
ApploachSS->run (
  app_docker_image => $ENV{TEST_APP_DOCKER_IMAGE},
  mysqld_database_name_suffix => '_test',
  no_set_uid => 1,
  write_ss_env => 1,
  signal => $ac->signal,
)->then (sub {
  warn "$$: Test env is ready\n";

  return $_[0]->{done};
})->to_cv->recv; # or croak

=head1 LICENSE

Copyright 2018-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
