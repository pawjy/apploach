use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->are_errors (
    [['star', 'add.json'], {
      starred_nobj_key => $current->generate_key (key1 => {}),
      item_nobj_key => $current->generate_key (type1 => {}),
      starred_author_nobj_key => $current->generate_key (id2 => {}),
      starred_index_nobj_key => $current->generate_key (id3 => {}),
      author_nobj_key => $current->generate_key (id1 => {}),
      delta => 3,
    }],
    [
      ['new_nobj', 'starred'],
      ['new_nobj', 'starred_author'],
      ['new_nobj', 'author'],
    ],
  )->then (sub {
    return $current->json (['star', 'add.json'], {
      starred_nobj_key => $current->o ('key1'),
      item_nobj_key => $current->o ('type1'),
      starred_author_nobj_key => $current->o ('id2'),
      starred_index_nobj_key => $current->o ('id3'),
      author_nobj_key => $current->o ('id1'),
      delta => 4,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is ref $result->{json}, 'HASH';
    } $current->c;
    return $current->json (['star', 'get.json'], {
      starred_nobj_key => $current->o ('key1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{stars}}, 1;
      my $stars = $result->{json}->{stars}->{$current->o ('key1')};
      is 0+@$stars, 1;
      my $c = $stars->[0];
      is $c->{author_nobj_key}, $current->o ('id1');
      is $c->{count}, 4;
    } $current->c;
  });
} n => 6, name => 'add.json';

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->create (
      [a1 => account => {}],
      [a2 => account => {}],
    );
  })->then (sub {
    return $current->json (['star', 'add.json'], {
      starred_nobj_key => $current->generate_key ('key1' => {}),
      starred_author_nobj_key => $current->o ('a2')->{nobj_key},
      starred_index_nobj_key => $current->generate_key ('id3' => {}),
      item_nobj_key => $current->generate_key ('type1' => {}),
      author_nobj_key => $current->o ('a1')->{nobj_key},
      delta => 4,
    });
  })->then (sub {
    return $current->json (['star', 'add.json'], {
      starred_nobj_key => $current->o ('key1'),
      starred_author_nobj_key => $current->o ('a2')->{nobj_key},
      starred_index_nobj_key => $current->o ('id3'),
      item_nobj_key => $current->o ('type1'),
      author_nobj_key => $current->o ('a1')->{nobj_key},
      delta => 0,
    });
  })->then (sub {
    return $current->json (['star', 'add.json'], {
      starred_nobj_key => $current->o ('key1'),
      starred_author_nobj_key => $current->o ('a2')->{nobj_key},
      starred_index_nobj_key => $current->o ('id3'),
      item_nobj_key => $current->o ('type1'),
      author_nobj_key => $current->o ('a1')->{nobj_key},
      delta => -2,
    });
  })->then (sub {
    return $current->json (['star', 'get.json'], {
      starred_nobj_key => $current->o ('key1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{stars}}, 1;
      my $stars = $result->{json}->{stars}->{$current->o ('key1')};
      is 0+@$stars, 1;
      my $c = $stars->[0];
      is $c->{count}, 2;
    } $current->c, name => 'decreased';
    return $current->json (['star', 'add.json'], {
      starred_nobj_key => $current->o ('key1'),
      starred_author_nobj_key => $current->o ('a2')->{nobj_key},
      starred_index_nobj_key => $current->o ('id3'),
      item_nobj_key => $current->o ('type1'),
      author_nobj_key => $current->o ('a1')->{nobj_key},
      delta => -10,
    });
  })->then (sub {
    return $current->json (['star', 'add.json'], {
      starred_nobj_key => $current->o ('key1'),
      starred_author_nobj_key => $current->o ('a2')->{nobj_key},
      starred_index_nobj_key => $current->o ('id3'),
      item_nobj_key => $current->o ('type1'),
      author_nobj_key => $current->o ('a1')->{nobj_key},
      delta => 0,
    });
  })->then (sub {
    return $current->json (['star', 'get.json'], {
      starred_nobj_key => $current->o ('key1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{stars}}, 0;
    } $current->c, name => 'decreased';
  });
} n => 4, name => 'add.json decreased';

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
