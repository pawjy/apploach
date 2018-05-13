use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->create (
      [t1 => target => {}],
      [i1 => target => {}],
      [a1 => account => {}],
      [s1 => star => {
        target => 't1', count => 2, item_target => 'i1', author => 'a1',
      }],
    );
  })->then (sub {
    return $current->json (['star', 'get.json'], {
      target_key => $current->o ('t1')->{target_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{stars}}, 1;
      my $stars = $result->{json}->{stars}->{$current->o ('t1')->{target_key}};
      is 0+@$stars, 1;
      my $c = $stars->[0];
      is $c->{author_account_id}, $current->o ('a1')->{account_id};
      is $c->{item_target_key}, $current->o ('i1')->{target_key};
      is $c->{count}, 2;
      has_json_string $result, 'author_account_id';
    } $current->c;
    return $current->create (
      [t2 => target => {}],
      [s2 => star => {
        target => 't2', count => 4, item_target => 'i1', author => 'a1',
      }],
    );
  })->then (sub {
    return $current->json (['star', 'get.json'], {
      target_key => [
        $current->o ('t1')->{target_key},
        $current->generate_key (key1 => {}),
        $current->o ('t2')->{target_key},
        undef,
        '',
        rand,
      ],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{stars}}, 2;
      my $stars = $result->{json}->{stars}->{$current->o ('t1')->{target_key}};
      is 0+@$stars, 1;
      my $c = $stars->[0];
      is $c->{author_account_id}, $current->o ('a1')->{account_id};
      is $c->{item_target_key}, $current->o ('i1')->{target_key};
      is $c->{count}, 2;
      my $stars2 = $result->{json}->{stars}->{$current->o ('t2')->{target_key}};
      is 0+@$stars2, 1;
      my $c2 = $stars2->[0];
      is $c2->{author_account_id}, $current->o ('a1')->{account_id};
      is $c2->{item_target_key}, $current->o ('i1')->{target_key};
      is $c2->{count}, 4;
    } $current->c, name => 'different targets';
    return $current->create (
      [a2 => account => {}],
      [s3 => star => {
        target => 't1', count => 6, item_target => 'i1', author => 'a2',
      }],
    );
  })->then (sub {
    return $current->json (['star', 'get.json'], {
      target_key => $current->o ('t1')->{target_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{stars}}, 1;
      my $stars = $result->{json}->{stars}->{$current->o ('t1')->{target_key}};
      is 0+@$stars, 2;
      my $c = $stars->[0];
      is $c->{author_account_id}, $current->o ('a1')->{account_id};
      is $c->{item_target_key}, $current->o ('i1')->{target_key};
      is $c->{count}, 2;
      my $c2 = $stars->[1];
      is $c2->{author_account_id}, $current->o ('a2')->{account_id};
      is $c2->{item_target_key}, $current->o ('i1')->{target_key};
      is $c2->{count}, 6;
    } $current->c;
  })->then (sub {
    return $current->json (['star', 'get.json'], {
      target_key => $current->o ('t1')->{target_key},
    }, app_id => $current->generate_id (appid2 => {}));
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{stars}}, 0;
    } $current->c, name => 'Bad app_id';
  });
} n => 24, name => 'get.json';

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->json (['star', 'get.json'], {
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{stars} or {}}, 0;
    } $current->c;
  });
} n => 1, name => 'empty params';

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->json (['star', 'get.json'], {
      target_key => $current->generate_id (id1 => {}),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{stars} or {}}, 0;
    } $current->c;
  });
} n => 1, name => 'no data';

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
