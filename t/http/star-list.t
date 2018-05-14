use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->create (
      [t1 => nobj => {}],
      [t2 => nobj => {}],
      [i1 => nobj => {}],
      [a1 => account => {}],
      [a2 => account => {}],
      [s1 => star => {
        starred => 't1', count => 2, item => 'i1', author => 'a1',
      }],
      [s1_2 => star => {
        starred => 't1', count => 3, item => 'i1', author => 'a2',
      }],
      [s2 => star => {
        starred => 't2', count => 4, item => 'i1', author => 'a1',
      }],
    );
  })->then (sub {
    return $current->json (['star', 'list.json'], {
      author_nobj_key => $current->o ('a1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $c2 = $result->{json}->{items}->[0];
      is $c2->{starred_nobj_key}, $current->o ('t2')->{nobj_key};
      is $c2->{author_nobj_key}, $current->o ('a1')->{nobj_key};
      is $c2->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      is $c2->{count}, 4;
      my $c = $result->{json}->{items}->[1];
      is $c->{starred_nobj_key}, $current->o ('t1')->{nobj_key};
      is $c->{author_nobj_key}, $current->o ('a1')->{nobj_key};
      is $c->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      is $c->{count}, 2;
    } $current->c;
  });
} n => 9, name => 'list.json by author';

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->create (
      [t1 => nobj => {}],
      [t2 => nobj => {}],
      [i1 => nobj => {}],
      [a1 => account => {}],
      [a2 => account => {}],
      [a3 => account => {}],
      [a4 => account => {}],
      [s1 => star => {
        starred => 't1', count => 2, item => 'i1', starred_author => 'a1',
        author => 'a3',
      }],
      [s1_2 => star => {
        starred => 't2', count => 3, item => 'i1', starred_author => 'a2',
        author => 'a3',
      }],
      [s2 => star => {
        starred => 't1', count => 4, item => 'i1', starred_author => 'a1',
        author => 'a4',
      }],
    );
  })->then (sub {
    return $current->json (['star', 'list.json'], {
      starred_author_nobj_key => $current->o ('a1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $c2 = $result->{json}->{items}->[0];
      is $c2->{starred_nobj_key}, $current->o ('t1')->{nobj_key};
      is $c2->{author_nobj_key}, $current->o ('a4')->{nobj_key};
      is $c2->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      is $c2->{count}, 4;
      my $c = $result->{json}->{items}->[1];
      is $c->{starred_nobj_key}, $current->o ('t1')->{nobj_key};
      is $c->{author_nobj_key}, $current->o ('a3')->{nobj_key};
      is $c->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      is $c->{count}, 2;
    } $current->c;
  });
} n => 9, name => 'list.json by starred author';

Test {
  my $current = shift;
  return $current->create (
    [a1 => account => {}],
    [in1 => nobj => {}],
    [in2 => nobj => {}],
    [s1 => star => {author => 'a1', starred_index => 'in1'}],
  )->then (sub {
    return $current->are_empty (
      [['star', 'list.json'], {
        author_nobj_key => $current->o ('a1')->{nobj_key},
      }],
      [
        'app_id',
        ['get_nobj', 'starred_index'],
        {p => {
          starred_index_nobj_key => $current->o ('in2')->{nobj_key},
        }},
      ],
    );
  })->then (sub {
    return $current->are_empty (
      [['star', 'list.json'], {
      }],
      [
        {name => 'No author/starred_author'},
        ['get_nobj', 'author'],
        ['get_nobj', 'starred_author'],
        ['get_nobj', 'starred_index'],
      ],
    );
  });
} n => 2, name => 'Bad';

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->create (
      [t1 => nobj => {}],
      [t2 => nobj => {}],
      [i1 => nobj => {}],
      [a1 => account => {}],
      [a2 => account => {}],
      [a3 => account => {}],
      [in1 => nobj => {}],
      [in2 => nobj => {}],
      [s1 => star => {
        starred => 't1', count => 2, item => 'i1', author => 'a1',
        starred_index => 'in1',
      }],
      [s1_2 => star => {
        starred => 't1', count => 3, item => 'i1', author => 'a2',
        starred_index => 'in1',
      }],
      [s2 => star => {
        starred => 't2', count => 4, item => 'i1', author => 'a1',
        starred_index => 'in1',
      }],
      [s3 => star => {
        starred => 't1', count => 2, item => 'i1', author => 'a3',
        starred_index => 'in2',
      }],
    );
  })->then (sub {
    return $current->json (['star', 'list.json'], {
      author_nobj_key => $current->o ('a1')->{nobj_key},
      starred_index_nobj_key => $current->o ('in1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $c2 = $result->{json}->{items}->[0];
      is $c2->{starred_nobj_key}, $current->o ('t2')->{nobj_key};
      is $c2->{author_nobj_key}, $current->o ('a1')->{nobj_key};
      is $c2->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      is $c2->{count}, 4;
      my $c = $result->{json}->{items}->[1];
      is $c->{starred_nobj_key}, $current->o ('t1')->{nobj_key};
      is $c->{author_nobj_key}, $current->o ('a1')->{nobj_key};
      is $c->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      is $c->{count}, 2;
    } $current->c;
  });
} n => 9, name => 'list.json by author and index';

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->create (
      [t1 => nobj => {}],
      [t2 => nobj => {}],
      [i1 => nobj => {}],
      [in1 => nobj => {}],
      [in2 => nobj => {}],
      [a1 => account => {}],
      [a2 => account => {}],
      [a3 => account => {}],
      [a4 => account => {}],
      [a5 => account => {}],
      [s1 => star => {
        starred => 't1', count => 2, item => 'i1', starred_author => 'a1',
        author => 'a3',
        starred_index => 'in1',
      }],
      [s1_2 => star => {
        starred => 't2', count => 3, item => 'i1', starred_author => 'a2',
        author => 'a3',
        starred_index => 'in1',
      }],
      [s2 => star => {
        starred => 't1', count => 4, item => 'i1', starred_author => 'a1',
        author => 'a4',
        starred_index => 'in1',
      }],
      [s3 => star => {
        starred => 't1', count => 2, item => 'i1', starred_author => 'a1',
        author => 'a5',
        starred_index => 'in2',
      }],
    );
  })->then (sub {
    return $current->json (['star', 'list.json'], {
      starred_author_nobj_key => $current->o ('a1')->{nobj_key},
      starred_index_nobj_key => $current->o ('in1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $c2 = $result->{json}->{items}->[0];
      is $c2->{starred_nobj_key}, $current->o ('t1')->{nobj_key};
      is $c2->{author_nobj_key}, $current->o ('a4')->{nobj_key};
      is $c2->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      is $c2->{count}, 4;
      my $c = $result->{json}->{items}->[1];
      is $c->{starred_nobj_key}, $current->o ('t1')->{nobj_key};
      is $c->{author_nobj_key}, $current->o ('a3')->{nobj_key};
      is $c->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      is $c->{count}, 2;
    } $current->c;
  });
} n => 9, name => 'list.json by starred author and index';

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
