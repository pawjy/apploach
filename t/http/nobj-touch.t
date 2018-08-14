use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
  )->then (sub {
    return $current->json (['nobj', 'touch.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['nobj', 'touch.json'], {
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok 1;
    } $current->c;
  });
} n => 1, name => 'touch noop';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [t3 => nobj => {}],
    [f1 => follow => {subject => 't2', object => 't1', type => 't3'}],
  )->then (sub {
    return $current->json (['nobj', 'touch.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok 1;
    } $current->c;
  });
} n => 1, name => 'touch followed';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [t3 => nobj => {}],
    [t4 => nobj => {}],
    [f1 => follow => {subject => 't2', object => 't1', type => 't3'}],
    [f2 => follow => {subject => 't2', object => 't4', type => 't3'}],
  )->then (sub {
    return $current->json (['nobj', 'touch.json'], {
      target_nobj_key => [
        $current->o ('t1')->{nobj_key},
        rand,
        $current->o ('t4')->{nobj_key},
        0,
      ],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok 1;
    } $current->c;
  });
} n => 1, name => 'touch followed multiple';

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
