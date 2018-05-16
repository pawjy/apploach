use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/modules/*/lib');
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use AbortController;
use Promised::Flow;
use Promised::File;

use ServerSet;

my $RootPath = path (__FILE__)->parent->parent->parent;
my $work_path = $RootPath->child ('local/test/circleci');
my $data_path = $work_path->child ('test-env.pl');
my $pid_path = $work_path->child ('pid');
my $pid_file = Promised::File->new_from_path ($pid_path);

my ($r_data, $s_data) = promised_cv;

my $ac = AbortController->new;
ServerSet->run (
  signal => $ac->signal,
  mysqld_database_name_suffix => '_test',
)->then (sub {
  my $data = $_[0]->{data};

  warn "$$: Test env is ready\n";
  warn "$$:   - SS_ENV_FILE=$data->{ss_env_file_path}\n";
  warn "$$:   - PID file=$data->{ss_env_pid_path}\n";

  return $_[0]->{done};
})->to_cv->recv;

=head1 LICENSE

Copyright 2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
