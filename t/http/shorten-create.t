use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [s1 => nobj => {}],
  )->then (sub {
    return $current->are_errors (
      [['shorten', 'create.json'], {
        space_nobj_key => $current->o ('s1')->{nobj_key},
        data => {a => 1},
      }],
      [
        ['new_nobj', 'space'],
        ['json', 'data'],
      ],
    );
  })->then (sub {
    return $current->json (['shorten', 'create.json'], {
      space_nobj_key => $current->o ('s1')->{nobj_key},
      data => {foo => "\x{1233}"},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{key} =~ /\A[0-9a-zA-Z]{8,}\z/;
      ok $result->{json}->{created};
    } $current->c;
    $current->set_o (u1 => $result->{json});
    return $current->json (['shorten', 'get.json'], {
      space_nobj_key => $current->o ('s1')->{nobj_key},
      key => $current->o ('u1')->{key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{data}->{foo}, "\x{1233}";
      is $result->{json}->{created}, $current->o ('u1')->{created};
    } $current->c;
    return $current->json (['shorten', 'create.json'], {
      space_nobj_key => $current->o ('s1')->{nobj_key},
      data => {foo => "\x{1233}"},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      isnt $result->{json}->{key}, $current->o ('u1')->{key};
      isnt $result->{json}->{created}, $current->o ('u1')->{created};
    } $current->c;
  });
} n => 7, name => 'create';

RUN;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

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
