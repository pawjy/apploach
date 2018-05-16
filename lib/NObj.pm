package NObj;
use strict;
use warnings;

sub new ($%) {
  my $class = shift;
  return bless {@_}, $class;
} # new

sub missing ($) {
  return $_[0]->{missing};
} # missing

sub not_found ($) {
  return $_[0]->{not_found};
} # not_found

sub invalid_key ($) {
  return $_[0]->{invalid_key};
} # invalid_key

sub is_error ($) {
  return $_[0]->{missing} || $_[0]->{not_found};
} # is_error

sub nobj_id ($) {
  die "Not available" unless defined $_[0]->{nobj_id};
  return $_[0]->{nobj_id};
} # nobj_id

sub nobj_key ($) {
  return $_[0]->{nobj_key};
} # nobj_key

sub to_columns ($$) {
  my ($self, $name) = @_;
  die "Not available" unless defined $self->{nobj_id};
  return ($name."_nobj_id" => $self->{nobj_id});
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
