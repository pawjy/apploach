use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->are_errors (
    [['comment', 'list.json'], {}],
    [
      {params => {}, name => 'no params', reason => 'Either thread or |comment_id| is required'},
    ],
  )->then (sub {
    return $current->create (
      [t1 => nobj => {}],
      [a1 => account => {}],
      [c1 => comment => {
        thread => 't1',
        data => {
          body => $current->generate_text (text1 => {}),
        },
        internal_data => {
          hoge => $current->generate_text (text2 => {}),
        },
        author => 'a1',
        author_status => 5,
        owner_status => 6,
        admin_status => 7,
      }],
    );
  })->then (sub {
    return $current->json (['comment', 'list.json'], {
      comment_id => $current->o ('c1')->{comment_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{comment_id}, $current->o ('c1')->{comment_id};
      is $c->{data}->{timestamp}, $current->o ('c1')->{timestamp};
      is $c->{author_nobj_key}, $current->o ('a1')->{nobj_key};
      is $c->{thread_nobj_key}, $current->o ('t1')->{nobj_key};
      is $c->{data}->{body}, $current->o ('text1');
      is $c->{internal_data}, undef, 'no internal_data';
      is $c->{author_status}, 5;
      is $c->{owner_status}, 6;
      is $c->{admin_status}, 7;
      has_json_string $result, 'comment_id';
    } $current->c, name => 'get by comment_id';
    return $current->json (['comment', 'list.json'], {
      comment_id => $current->o ('c1')->{comment_id},
      with_internal_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{comment_id}, $current->o ('c1')->{comment_id};
      is $c->{data}->{timestamp}, $current->o ('c1')->{timestamp};
      is $c->{author_nobj_key}, $current->o ('a1')->{nobj_key};
      is $c->{thread_nobj_key}, $current->o ('t1')->{nobj_key};
      is $c->{data}->{body}, $current->o ('text1');
      is $c->{internal_data}->{hoge}, $current->o ('text2');
      is $c->{author_status}, 5;
      is $c->{owner_status}, 6;
      is $c->{admin_status}, 7;
      has_json_string $result, 'comment_id';
    } $current->c, name => 'get by comment_id, with_internal_data';
  });
} n => 23, name => 'list.json get a comment';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [c1 => comment => {thread => 't1'}],
    [c2 => comment => {thread => 't1'}],
    [c3 => comment => {thread => 't1'}],
  )->then (sub {
    return $current->json (['comment', 'list.json'], {
      thread_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 3;
      is $result->{json}->{items}->[0]->{comment_id},
         $current->o ('c3')->{comment_id}, 'item #0';
      is $result->{json}->{items}->[1]->{comment_id},
         $current->o ('c2')->{comment_id}, 'item #1';
      is $result->{json}->{items}->[2]->{comment_id},
         $current->o ('c1')->{comment_id}, 'item #2';
    } $current->c, name => 'get by target_key';
    return $current->json (['comment', 'list.json'], {
      thread_nobj_key => $current->o ('t1')->{thread_nobj_key},
      comment_id => $current->o ('c1')->{comment_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      is $result->{json}->{items}->[0]->{comment_id},
         $current->o ('c1')->{comment_id};
    } $current->c, name => 'get by target_key and comment_id';
    return $current->are_empty (
      [['comment', 'list.json'], {
        thread_nobj_key => $current->o ('t1')->{thread_nobj_key},
        comment_id => $current->o ('c1')->{comment_id},
      }],
      [
        'app_id',
        ['get_nobj', 'thread'],
      ],
    );
  });
} n => 7, name => 'get by target';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [c1 => comment => {thread => 't1'}],
    [c2 => comment => {thread => 't1'}],
    [c3 => comment => {thread => 't1'}],
    [c4 => comment => {thread => 't1'}],
    [c5 => comment => {thread => 't1'}],
  )->then (sub {
    return $current->pages_ok ([['comment', 'list.json'], {
      thread_nobj_key => $current->o ('t1')->{nobj_key},
    }] => ['c1', 'c2', 'c3', 'c4', 'c5'], 'comment_id');
  });
} n => 1, name => 'pager paging';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [c1 => comment => {
      thread => 't1',
      author_status => 10, owner_status => 2, admin_status => 3,
    }],
    [c2 => comment => {
      thread => 't1',
      author_status => 4, owner_status => 3, admin_status => 5,
    }],
    [c3 => comment => {
      thread => 't1',
      author_status => 10, owner_status => 5, admin_status => 3,
    }],
  )->then (sub {
    return $current->json (['comment', 'list.json'], {
      thread_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{comment_id}}++ for @{$result->{json}->{items}};
      ok $has->{$current->o ('c1')->{comment_id}};
      ok $has->{$current->o ('c2')->{comment_id}};
      ok $has->{$current->o ('c3')->{comment_id}};
    } $current->c, name => 'no filter';
    return $current->json (['comment', 'list.json'], {
      thread_nobj_key => $current->o ('t1')->{nobj_key},
      author_status => 10,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{comment_id}}++ for @{$result->{json}->{items}};
      ok $has->{$current->o ('c1')->{comment_id}};
      ok ! $has->{$current->o ('c2')->{comment_id}};
      ok $has->{$current->o ('c3')->{comment_id}};
    } $current->c, name => 'author_status only';
    return $current->json (['comment', 'list.json'], {
      thread_nobj_key => $current->o ('t1')->{nobj_key},
      owner_status => [2, 3],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{comment_id}}++ for @{$result->{json}->{items}};
      ok $has->{$current->o ('c1')->{comment_id}};
      ok $has->{$current->o ('c2')->{comment_id}};
      ok ! $has->{$current->o ('c3')->{comment_id}};
    } $current->c, name => 'multiple values';
    return $current->json (['comment', 'list.json'], {
      thread_nobj_key => $current->o ('t1')->{nobj_key},
      admin_status => 6,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{comment_id}}++ for @{$result->{json}->{items}};
      ok ! $has->{$current->o ('c1')->{comment_id}};
      ok ! $has->{$current->o ('c2')->{comment_id}};
      ok ! $has->{$current->o ('c3')->{comment_id}};
    } $current->c, name => 'no result';
    return $current->json (['comment', 'list.json'], {
      thread_nobj_key => $current->o ('t1')->{nobj_key},
      author_status => 10,
      owner_status => 5,
      admin_status => 3,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{comment_id}}++ for @{$result->{json}->{items}};
      ok ! $has->{$current->o ('c1')->{comment_id}};
      ok ! $has->{$current->o ('c2')->{comment_id}};
      ok $has->{$current->o ('c3')->{comment_id}};
    } $current->c, name => 'multiple filters';
    return $current->json (['comment', 'list.json'], {
      thread_nobj_key => $current->o ('t1')->{nobj_key},
      author_status => 0,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{comment_id}}++ for @{$result->{json}->{items}};
      ok ! $has->{$current->o ('c1')->{comment_id}};
      ok ! $has->{$current->o ('c2')->{comment_id}};
      ok ! $has->{$current->o ('c3')->{comment_id}};
    } $current->c, name => 'bad value';
    return $current->json (['comment', 'list.json'], {
      thread_nobj_key => $current->o ('t1')->{nobj_key},
      author_status => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{comment_id}}++ for @{$result->{json}->{items}};
      ok ! $has->{$current->o ('c1')->{comment_id}};
      ok ! $has->{$current->o ('c2')->{comment_id}};
      ok ! $has->{$current->o ('c3')->{comment_id}};
    } $current->c, name => 'bad value';
    return $current->json (['comment', 'list.json'], {
      thread_nobj_key => $current->o ('t1')->{nobj_key},
      author_status => "abc",
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{comment_id}}++ for @{$result->{json}->{items}};
      ok ! $has->{$current->o ('c1')->{comment_id}};
      ok ! $has->{$current->o ('c2')->{comment_id}};
      ok ! $has->{$current->o ('c3')->{comment_id}};
    } $current->c, name => 'bad value';
  });
} n => 24, name => 'status filters';

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
