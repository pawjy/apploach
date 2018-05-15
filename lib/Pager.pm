package Pager;
use strict;
use warnings;

sub this_page ($%) {
  my ($self, %args) = @_;
  my $page = {
    order_direction => (($args{order_direction} || '') eq '+' ? 'ASC' : 'DESC'),
    limit => 0+($self->{app}->bare_param ('limit') // $args{limit} // 30),
    offset => 0,
    value => undef,
  };
  my $max_limit = $args{max_limit} // 100;
  return $self->throw ({reason => "Bad |limit|"})
      if $page->{limit} < 1 or $page->{limit} > $max_limit;
  my $ref = $self->{app}->bare_param ('ref');
  if (defined $ref) {
    if ($ref =~ /\A([+-])([0-9.]+),([0-9]+)\z/) {
      $page->{order_direction} = $1 eq '+' ? 'ASC' : 'DESC';
      $page->{exact_value} = 0+$2;
      $page->{value} = {($page->{order_direction} eq 'ASC' ? '>=' : '<='), $page->{exact_value}};
      $page->{offset} = 0+$3;
      return $self->throw ({reason => "Bad |ref| offset"})
          if $page->{offset} > 100;
      $page->{ref} = $ref;
    } else {
      return $self->throw ({reason => "Bad |ref|"});
    }
  }
  return $page;
} # this_page

sub next_page ($$$) {
  my ($this_page, $items, $value_key) = @_;
  my $next_page = {};
  my $sign = $this_page->{order_direction} eq 'ASC' ? '+' : '-';
  my $values = {};
  $values->{$this_page->{exact_value}} = $this_page->{offset}
      if defined $this_page->{exact_value};
  if (ref $items eq 'ARRAY') {
    if (@$items) {
      my $last_value = $items->[0]->{$value_key};
      for (@$items) {
        $values->{$_->{$value_key}}++;
        if ($sign eq '+') {
          $last_value = $_->{$value_key} if $last_value < $_->{$value_key};
        } else {
          $last_value = $_->{$value_key} if $last_value > $_->{$value_key};
        }
      }
      $next_page->{next_ref} = $sign . $last_value . ',' . $values->{$last_value};
      $next_page->{has_next} = @$items == $this_page->{limit};
    } else {
      $next_page->{next_ref} = $this_page->{ref};
      $next_page->{has_next} = 0;
    }
  } else { # HASH
    if (keys %$items) {
      my $last_value = $items->{each %$items}->{$value_key};
      for (values %$items) {
        $values->{$_->{$value_key}}++;
        if ($sign eq '+') {
          $last_value = $_->{$value_key} if $last_value < $_->{$value_key};
        } else {
          $last_value = $_->{$value_key} if $last_value > $_->{$value_key};
        }
      }
      $next_page->{next_ref} = $sign . $last_value . ',' . $values->{$last_value};
      $next_page->{has_next} = (keys %$items) == $this_page->{limit};
    } else {
      $next_page->{next_ref} = $this_page->{ref};
      $next_page->{has_next} = 0;
    }
  }
  return $next_page;
} # next_page

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
