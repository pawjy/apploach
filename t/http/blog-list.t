use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->are_errors (
    [['blog', 'list.json'], {}],
    [
      {params => {}, name => 'no params', reason => 'Either blog or |blog_entry_id| is required'},
    ],
  )->then (sub {
    return $current->create (
      [t1 => nobj => {}],
      [a1 => account => {}],
      [c1 => blog_entry => {
        blog => 't1',
        data => {
          body => $current->generate_text (text1 => {}),
        },
        internal_data => {
          hoge => $current->generate_text (text2 => {}),
        },
        author_status => 5,
        owner_status => 6,
        admin_status => 7,
      }],
    );
  })->then (sub {
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{blog_entry_id}, $current->o ('c1')->{blog_entry_id};
      is $c->{data}, undef;
      is $c->{title}, undef;
      is $c->{blog_nobj_key}, $current->o ('t1')->{nobj_key};
      is $c->{internal_data}, undef, 'no internal_data';
      is $c->{author_status}, 5;
      is $c->{owner_status}, 6;
      is $c->{admin_status}, 7;
      has_json_string $result, 'blog_entry_id';
    } $current->c, name => 'get by blog_entry_id';
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      with_title => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{blog_entry_id}, $current->o ('c1')->{blog_entry_id};
      is $c->{blog_nobj_key}, $current->o ('t1')->{nobj_key};
      is $c->{data}->{title}, '';
      is $c->{data}->{body}, undef;
      is $c->{internal_data}, undef, 'no internal_data';
      is $c->{author_status}, 5;
      is $c->{owner_status}, 6;
      is $c->{admin_status}, 7;
      has_json_string $result, 'blog_entry_id';
    } $current->c, name => 'get by blog_entry_id';
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      with_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{blog_entry_id}, $current->o ('c1')->{blog_entry_id};
      is $c->{data}->{timestamp}, $current->o ('c1')->{timestamp};
      is $c->{blog_nobj_key}, $current->o ('t1')->{nobj_key};
      is $c->{data}->{body}, $current->o ('text1');
      is $c->{internal_data}, undef, 'no internal_data';
      is $c->{author_status}, 5;
      is $c->{owner_status}, 6;
      is $c->{admin_status}, 7;
      has_json_string $result, 'blog_entry_id';
    } $current->c, name => 'get by blog_entry_id';
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      with_data => 1,
      with_internal_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{blog_entry_id}, $current->o ('c1')->{blog_entry_id};
      is $c->{data}->{timestamp}, $current->o ('c1')->{timestamp};
      is $c->{blog_nobj_key}, $current->o ('t1')->{nobj_key};
      is $c->{data}->{body}, $current->o ('text1');
      is $c->{internal_data}->{hoge}, $current->o ('text2');
      is $c->{author_status}, 5;
      is $c->{owner_status}, 6;
      is $c->{admin_status}, 7;
      has_json_string $result, 'blog_entry_id';
    } $current->c, name => 'get by blog_entry_id, with_internal_data';
  });
} n => 41, name => 'list.json get a comment';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [c1 => blog_entry => {blog => 't1'}],
    [c2 => blog_entry => {blog => 't1'}],
    [c3 => blog_entry => {blog => 't1'}],
  )->then (sub {
    return $current->json (['blog', 'list.json'], {
      blog_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 3;
      is $result->{json}->{items}->[0]->{blog_entry_id},
         $current->o ('c3')->{blog_entry_id}, 'item #0';
      is $result->{json}->{items}->[1]->{blog_entry_id},
         $current->o ('c2')->{blog_entry_id}, 'item #1';
      is $result->{json}->{items}->[2]->{blog_entry_id},
         $current->o ('c1')->{blog_entry_id}, 'item #2';
    } $current->c, name => 'get by target_key';
    return $current->json (['blog', 'list.json'], {
      blog_nobj_key => $current->o ('t1')->{blog_nobj_key},
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      is $result->{json}->{items}->[0]->{blog_entry_id},
         $current->o ('c1')->{blog_entry_id};
    } $current->c, name => 'get by target_key and blog_entry_id';
    return $current->are_empty (
      [['blog', 'list.json'], {
        blog_nobj_key => $current->o ('t1')->{blog_nobj_key},
        blog_entry_id => $current->o ('c1')->{blog_entry_id},
      }],
      [
        'app_id',
        ['get_nobj', 'blog'],
      ],
    );
  });
} n => 7, name => 'get by target';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [c1 => blog_entry => {blog => 't1'}],
    [c2 => blog_entry => {blog => 't1'}],
    [c3 => blog_entry => {blog => 't1'}],
    [c4 => blog_entry => {blog => 't1'}],
    [c5 => blog_entry => {blog => 't1'}],
  )->then (sub {
    return $current->pages_ok ([['blog', 'list.json'], {
      blog_nobj_key => $current->o ('t1')->{nobj_key},
    }] => ['c1', 'c2', 'c3', 'c4', 'c5'], 'blog_entry_id');
  });
} n => 1, name => 'pager paging';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [c1 => blog_entry => {
      blog => 't1',
      author_status => 10, owner_status => 2, admin_status => 3,
    }],
    [c2 => blog_entry => {
      blog => 't1',
      author_status => 4, owner_status => 3, admin_status => 5,
    }],
    [c3 => blog_entry => {
      blog => 't1',
      author_status => 10, owner_status => 5, admin_status => 3,
    }],
  )->then (sub {
    return $current->json (['blog', 'list.json'], {
      blog_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{blog_entry_id}}++ for @{$result->{json}->{items}};
      ok $has->{$current->o ('c1')->{blog_entry_id}};
      ok $has->{$current->o ('c2')->{blog_entry_id}};
      ok $has->{$current->o ('c3')->{blog_entry_id}};
    } $current->c, name => 'no filter';
    return $current->json (['blog', 'list.json'], {
      blog_nobj_key => $current->o ('t1')->{nobj_key},
      author_status => 10,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{blog_entry_id}}++ for @{$result->{json}->{items}};
      ok $has->{$current->o ('c1')->{blog_entry_id}};
      ok ! $has->{$current->o ('c2')->{blog_entry_id}};
      ok $has->{$current->o ('c3')->{blog_entry_id}};
    } $current->c, name => 'author_status only';
    return $current->json (['blog', 'list.json'], {
      blog_nobj_key => $current->o ('t1')->{nobj_key},
      owner_status => [2, 3],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{blog_entry_id}}++ for @{$result->{json}->{items}};
      ok $has->{$current->o ('c1')->{blog_entry_id}};
      ok $has->{$current->o ('c2')->{blog_entry_id}};
      ok ! $has->{$current->o ('c3')->{blog_entry_id}};
    } $current->c, name => 'multiple values';
    return $current->json (['blog', 'list.json'], {
      blog_nobj_key => $current->o ('t1')->{nobj_key},
      admin_status => 6,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{blog_entry_id}}++ for @{$result->{json}->{items}};
      ok ! $has->{$current->o ('c1')->{blog_entry_id}};
      ok ! $has->{$current->o ('c2')->{blog_entry_id}};
      ok ! $has->{$current->o ('c3')->{blog_entry_id}};
    } $current->c, name => 'no result';
    return $current->json (['blog', 'list.json'], {
      blog_nobj_key => $current->o ('t1')->{nobj_key},
      author_status => 10,
      owner_status => 5,
      admin_status => 3,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{blog_entry_id}}++ for @{$result->{json}->{items}};
      ok ! $has->{$current->o ('c1')->{blog_entry_id}};
      ok ! $has->{$current->o ('c2')->{blog_entry_id}};
      ok $has->{$current->o ('c3')->{blog_entry_id}};
    } $current->c, name => 'multiple filters';
    return $current->json (['blog', 'list.json'], {
      blog_nobj_key => $current->o ('t1')->{nobj_key},
      author_status => 0,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{blog_entry_id}}++ for @{$result->{json}->{items}};
      ok ! $has->{$current->o ('c1')->{blog_entry_id}};
      ok ! $has->{$current->o ('c2')->{blog_entry_id}};
      ok ! $has->{$current->o ('c3')->{blog_entry_id}};
    } $current->c, name => 'bad value';
    return $current->json (['blog', 'list.json'], {
      blog_nobj_key => $current->o ('t1')->{nobj_key},
      author_status => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{blog_entry_id}}++ for @{$result->{json}->{items}};
      ok ! $has->{$current->o ('c1')->{blog_entry_id}};
      ok ! $has->{$current->o ('c2')->{blog_entry_id}};
      ok ! $has->{$current->o ('c3')->{blog_entry_id}};
    } $current->c, name => 'bad value';
    return $current->json (['blog', 'list.json'], {
      blog_nobj_key => $current->o ('t1')->{nobj_key},
      author_status => "abc",
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $has = {};
      $has->{$_->{blog_entry_id}}++ for @{$result->{json}->{items}};
      ok ! $has->{$current->o ('c1')->{blog_entry_id}};
      ok ! $has->{$current->o ('c2')->{blog_entry_id}};
      ok ! $has->{$current->o ('c3')->{blog_entry_id}};
    } $current->c, name => 'bad value';
  });
} n => 24, name => 'status filters';

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->create (
      [t1 => nobj => {}],
      [a1 => account => {}],
      [c1 => blog_entry => {
        blog => 't1',
        data => {
          title => $current->generate_text (text1 => {}),
        },
      }],
    );
  })->then (sub {
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      with_title => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{title}, undef;
      is $c->{data}->{title}, $current->o ('text1');
    } $current->c;
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      with_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{title}, undef;
      is $c->{data}->{title}, $current->o ('text1');
    } $current->c;
  });
} n => 6, name => 'title';

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
