use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
  )->then (sub {
    return $current->json (['alarm', 'list.json'], {
      scope_nobj_key => rand,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
      ok ! $result->{json}->{has_next};
    } $current->c;
  });
} n => 2, name => 'new nobj key';

Test {
  my $current = shift;
  return $current->create (
  )->then (sub {
    return $current->json (['alarm', 'list.json'], {
      scope_nobj_key => '',
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
      ok ! $result->{json}->{has_next};
    } $current->c;
  });
} n => 2, name => 'bad nobj key';

Test {
  my $current = shift;
  return $current->create (
    [u1 => nobj => {}],
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [t3 => nobj => {}],
    [t4 => nobj => {}],
    [t5 => nobj => {}],
    [l1 => nobj => {}],
    [y1 => nobj => {}],
    [s1 => nobj => {}],
  )->then (sub {
    return $current->json (['alarm', 'update.json'], {
      operator_nobj_key => $current->o ('u1')->{nobj_key},
      scope_nobj_key => $current->o ('s1')->{nobj_key},
      timestamp => time,
      alarm => [
        map {
          perl2json_chars {
            target_nobj_key => $current->o ($_)->{nobj_key},
            type_nobj_key => $current->o ('y1')->{nobj_key},
            level_nobj_key => $current->o ('l1')->{nobj_key},
          };
        } qw(t1 t2 t3 t4 t5)
      ],
    });
  })->then (sub {
    return $current->pages_ok ([['alarm', 'list.json'], {
      scope_nobj_key => $current->o ('s1')->{nobj_key},
    }] => ['t1', 't2', 't3', 't4', 't5'], ['target_nobj_key', 'nobj_key']);
  });
} n => 1, name => 'pager paging';

RUN;

=head1 LICENSE

Copyright 2022 Wakaba <wakaba@suikawiki.org>.

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
