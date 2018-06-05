use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [a1 => account => {}],
    [v1 => nobj => {}],
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [l1 => log => {status_info => 1, operator => 'a1',
                   target => 't1', verb => 'v1',
                   data => {foo => $current->generate_text (g1 => {})}}],
    [l2 => log => {status_info => 1, operator => 'a1',
                   target => 't2', verb => 'v1',
                   data => {foo => $current->generate_text (g2 => {})}}],
  )->then (sub {
    return $current->json (['nobj', 'statusinfo.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{info}}, 1;
      my $log = $result->{json}->{info}->{$current->o ('t1')->{nobj_key}};
      is $log->{log_id}, $current->o ('l1')->{log_id};
      is $log->{timestamp}, $current->o ('l1')->{timestamp};
      is $log->{foo}, $current->o ('g1');
    } $current->c, name => 'statusinfo.json';
    return $current->json (['nobj', 'statusinfo.json'], {
      target_nobj_key => [$current->o ('t1')->{nobj_key},
                          rand,
                          $current->o ('t2')->{nobj_key},
                          0],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{info}}, 2;
      my $log = $result->{json}->{info}->{$current->o ('t1')->{nobj_key}};
      is $log->{log_id}, $current->o ('l1')->{log_id};
      is $log->{timestamp}, $current->o ('l1')->{timestamp};
      is $log->{foo}, $current->o ('g1');
      my $log2 = $result->{json}->{info}->{$current->o ('t2')->{nobj_key}};
      is $log2->{log_id}, $current->o ('l2')->{log_id};
      is $log2->{timestamp}, $current->o ('l2')->{timestamp};
      is $log2->{foo}, $current->o ('g2');
    } $current->c, name => 'statusinfo.json';
    return $current->json (['nobj', 'statusinfo.json'], {
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{info}}, 0;
    } $current->c, name => 'statusinfo.json';
  });
} n => 12, name => 'statusinfo';

RUN;

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
