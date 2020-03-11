package WorkerState;
use strict;
use warnings;
use Path::Tiny;
use AbortController;
use Promise;
use Promised::Flow;
use JSON::PS;

my $config_path = path ($ENV{APP_CONFIG} // die "No |APP_CONFIG|");
my $Config = json_bytes2perl $config_path->slurp;

sub start ($%) {
  my ($class, %args) = @_;
  my ($r, $s) = promised_cv;
  my $obj = {config => $Config, clients => {}, dbs => {}};
  my $ac = new AbortController;
  my $t = $class->run_jobs ($obj, signal => $ac->signal)->catch (sub { });
  $args{signal}->manakai_onabort (sub {
    $ac->abort;
    return $t->then (sub {
      return Promise->all ([
        (map { $_->close } values %{$obj->{clients}}),
        (map { $_->disconnect } values %{$obj->{dbs}}),
      ]);
    })->finally ($s);
  });
  return [$obj, $r];
} # start

sub run_jobs ($$%) {
  my ($class, $obj, %args) = @_;
  return promised_wait_until {
    return $class->run_a_job ($obj)->catch (sub {
      warn $_[0];
      my $e = $_[0];
      #Application->error_log ($http->server_state->data->{config}, 'important', $e);
    });
  } signal => $args{signal};
} # run_jobs

sub run_a_job ($$) {
  my ($class, $obj) = @_;
  
  return Promise->resolve;
} # run_a_job

1;

=head1 LICENSE

Copyright 2019 Wakaba <wakaba@suikawiki.org>.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public
License along with this program.  If not, see
<https://www.gnu.org/licenses/>.

=cut
