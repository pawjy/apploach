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
    return $current->are_empty (
      [['tag', 'index.json'], {
        context_nobj_key => $current->o ('t1')->{nobj_key},
      }],
      [
        {},
      ],
    );
  });
} n => 1, name => 'empty';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [i1 => nobj => {}],
    [i2 => nobj => {}],
    [tag2 => tag => {tag_name => $current->generate_text (name2 => {}),
                     context => 't1',
                     author_status => 5,
                     owner_status => 6,
                     admin_status => 7}],
  )->then (sub {
    return $current->json (['tag', 'publish.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag => [
        $current->generate_text ('name1' => {}),
        $current->o ('name2'),
      ],
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['tag', 'publish.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag => [
        $current->o ('name1'),
      ],
      item_nobj_key => $current->o ('i2')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['tag', 'index.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $item1 = $result->{json}->{items}->[0];
      is $item1->{tag_name}, $current->o ('name1');
      is $item1->{count}, 2;
      ok $item1->{timestamp};
      is $item1->{author_status}, 0;
      is $item1->{owner_status}, 0;
      is $item1->{admin_status}, 0;
      my $item2 = $result->{json}->{items}->[1];
      is $item2->{tag_name}, $current->o ('name2');
      is $item2->{count}, 1;
      ok $item2->{timestamp};
      is $item2->{author_status}, 5;
      is $item2->{owner_status}, 6;
      is $item2->{admin_status}, 7;
    } $current->c;
    return $current->are_empty (
      [['tag', 'index.json'], {
        context_nobj_key => $current->o ('t1')->{nobj_key},
      }],
      [
        'app_id',
        {p => {context_nobj_key => rand}},
        ['get_nobj', 'context'],
      ],
    );
  })->then (sub {
    return $current->are_errors (
      [['tag', 'index.json'], {
        context_nobj_key => $current->o ('t1')->{nobj_key},
      }],
      [
        {p => {limit => 100000}, reason => 'Bad |limit|'},
      ],
    );
  });
} n => 15, name => 'index';

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
