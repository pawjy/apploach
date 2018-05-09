package Target;
use strict;
use warnings;

sub new ($%) {
  my $class = shift;
  return bless {@_}, $class;
} # new

sub no_target ($) {
  return $_[0]->{no_target};
} # no_target

sub not_found ($) {
  return $_[0]->{not_found};
} # not_found

sub to_columns ($) {
  die "Not available" unless defined $_[0]->{target_id};
  return (target_id => $_[0]->{target_id});
} # to_columns

1;

=head1 LICENSE

Copyright 2018 Wakaba <wakaba@suikawiki.org>.

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
