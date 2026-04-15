package Devices;
use strict;
use warnings;
use Time::HiRes qw(time);

push our @ISA, qw(Application);

sub run_devices ($) {
  my ($self) = @_;

  if (@{$self->{path}} >=2 and $self->{path}->[0] eq 'soracom') {
    # {}/devices/soracom/{}
    return $self->run_devices_soracom;
  }

  return $self->{app}->throw_error (404);
} # run_devices

sub run_devices_soracom ($) {
  my ($self) = @_;

  return $self->{app}->throw_error (404);
} # run_devices_soracom

1;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

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
