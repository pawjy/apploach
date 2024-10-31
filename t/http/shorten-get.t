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
    return $current->json (['shorten', 'create.json'], {
      space_nobj_key => $current->o ('s1')->{nobj_key},
      data => {foo => "\x{1233}"},
    });
  })->then (sub {
    my $result = $_[0];
    $current->set_o (u1 => $result->{json});
    return $current->are_errors (
      [['shorten', 'get.json'], {
        space_nobj_key => $current->o ('s1')->{nobj_key},
        key => $current->o ('u1')->{key},
      }],
      [
        ['new_nobj', 'space'],
      ],
    );
  })->then (sub {
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
    return $current->json (['shorten', 'get.json'], {
      space_nobj_key => $current->o ('s1')->{nobj_key} . "a",
      key => $current->o ('u1')->{key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{data}, undef;
      is $result->{json}->{created}, undef;
    } $current->c;
    return $current->json (['shorten', 'get.json'], {
      space_nobj_key => $current->o ('s1')->{nobj_key},
      key => $current->o ('u1')->{key} . "a",
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{data}, undef;
      is $result->{json}->{created}, undef;
    } $current->c;
    return $current->json (['shorten', 'get.json'], {
      space_nobj_key => $current->o ('s1')->{nobj_key},
      key => undef,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{data}, undef;
      is $result->{json}->{created}, undef;
    } $current->c;
    return $current->json (['shorten', 'get.json'], {
      space_nobj_key => $current->o ('s1')->{nobj_key} . "a",
      key => rand,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{data}, undef;
      is $result->{json}->{created}, undef;
    } $current->c;
  });
} n => 11, name => 'create';

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
