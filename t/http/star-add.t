use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->are_errors (
    [['star', 'add.json'], {
      target_key => $current->generate_key (key1 => {}),
      item_target_key => $current->generate_key (type1 => {}),
      target_author_account_id => $current->generate_id (id2 => {}),
      author_account_id => $current->generate_id (id1 => {}),
      delta => 3,
    }],
    [
      'new_target',
      {p => {target_author_account_id => 0},
       reason => 'Bad ID parameter |target_author_account_id|'},
      {p => {author_account_id => 0},
       reason => 'Bad ID parameter |author_account_id|'},
    ],
  )->then (sub {
    return $current->json (['star', 'add.json'], {
      target_key => $current->o ('key1'),
      item_target_key => $current->o ('type1'),
      target_author_account_id => $current->o ('id2'),
      author_account_id => $current->o ('id1'),
      delta => 4,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is ref $result->{json}, 'HASH';
    } $current->c;
    return $current->json (['star', 'get.json'], {
      target_key => $current->o ('key1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{stars}}, 1;
      my $stars = $result->{json}->{stars}->{$current->o ('key1')};
      is 0+@$stars, 1;
      my $c = $stars->[0];
      is $c->{author_account_id}, $current->o ('id1');
      is $c->{count}, 4;
      has_json_string $result, 'author_account_id';
    } $current->c;
  });
} n => 7, name => 'add.json';

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->json (['star', 'add.json'], {
      target_key => $current->generate_key ('key1' => {}),
      item_target_key => $current->generate_key ('type1' => {}),
      delta => 4,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is ref $result->{json}, 'HASH';
    } $current->c;
    return $current->json (['star', 'get.json'], {
      target_key => $current->o ('key1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{stars}}, 1;
      my $stars = $result->{json}->{stars}->{$current->o ('key1')};
      is 0+@$stars, 1;
      my $c = $stars->[0];
      is $c->{author_account_id}, undef;
      is $c->{count}, 4;
    } $current->c;
  });
} n => 5, name => 'add.json no author';

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->json (['star', 'add.json'], {
      target_key => $current->generate_key ('key1' => {}),
      item_target_key => $current->generate_key ('type1' => {}),
      delta => 4,
    });
  })->then (sub {
    return $current->json (['star', 'add.json'], {
      target_key => $current->o ('key1'),
      item_target_key => $current->o ('type1'),
      delta => 0,
    });
  })->then (sub {
    return $current->json (['star', 'add.json'], {
      target_key => $current->o ('key1'),
      item_target_key => $current->o ('type1'),
      delta => -2,
    });
  })->then (sub {
    return $current->json (['star', 'get.json'], {
      target_key => $current->o ('key1'),
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
      target_key => $current->o ('key1'),
      item_target_key => $current->o ('type1'),
      delta => -10,
    });
  })->then (sub {
    return $current->json (['star', 'add.json'], {
      target_key => $current->o ('key1'),
      item_target_key => $current->o ('type1'),
      delta => 0,
    });
  })->then (sub {
    return $current->json (['star', 'get.json'], {
      target_key => $current->o ('key1'),
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
