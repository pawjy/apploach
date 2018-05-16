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
      [a1 => account => {}],
      [c1 => comment => {
        thread => 't1',
        data => {
          body => $current->generate_text (text1 => {}),
          abc => $current->generate_text (text3 => {}),
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
    return $current->are_errors (
      [['comment', 'edit.json'], {
        comment_id => $current->o ('c1')->{comment_id},
      }],
      [
        {p => {comment_id => undef},
         reason => 'Bad ID parameter |comment_id|'},
        {p => {comment_id => ''},
         reason => 'Bad ID parameter |comment_id|'},
        {p => {comment_id => 0},
         reason => 'Bad ID parameter |comment_id|'},
        {p => {comment_id => 'abave'},
         reason => 'Bad ID parameter |comment_id|'},
        {p => {comment_id => $current->generate_id (rand, {})},
         reason => 'Object not found'},
        {app_id => $current->generate_id (rand, {}),
         reason => 'Object not found',
         name => 'Different application'},
        {p => {operator_nobj_key => ''}, reason => 'Bad |operator_nobj_key|'},
      ],
    );
  })->then (sub {
    return $current->json (['comment', 'edit.json'], {
      comment_id => $current->o ('c1')->{comment_id},
      data_delta => {
        body => $current->generate_text (text4 => {}),
        abc => undef,
        foo => $current->generate_text (text5 => {}),
      },
      author_status => 10,
    });
  })->then (sub {
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
      is $c->{data}->{body}, $current->o ('text4');
      is $c->{data}->{abc}, undef;
      is $c->{data}->{foo}, $current->o ('text5'),
      is $c->{internal_data}->{hoge}, $current->o ('text2');
      is $c->{author_status}, 10;
      is $c->{owner_status}, 6;
      is $c->{admin_status}, 7;
    } $current->c;
  });
} n => 12, name => 'edit.json modify data';

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->create (
      [t1 => nobj => {}],
      [a1 => account => {}],
      [c1 => comment => {
        thread => 't1',
        data => {
          body => $current->generate_text (text1 => {}),
          abc => $current->generate_text (text3 => {}),
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
    return $current->json (['comment', 'edit.json'], {
      comment_id => $current->o ('c1')->{comment_id},
      data_delta => {
        timestamp => 63463444,
      },
      internal_data_delta => {
        abc => $current->generate_text (text5 => {}),
      },
      admin_status => 53,
    });
  })->then (sub {
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
      is $c->{data}->{timestamp}, 63463444;
      is $c->{author_nobj_key}, $current->o ('a1')->{nobj_key};
      is $c->{data}->{body}, $current->o ('text1');
      is $c->{data}->{abc}, $current->o ('text3');
      is $c->{internal_data}->{abc}, $current->o ('text5');
      is $c->{internal_data}->{hoge}, $current->o ('text2');
      is $c->{author_status}, 5;
      is $c->{owner_status}, 6;
      is $c->{admin_status}, 53;
    } $current->c;
  });
} n => 11, name => 'edit.json modify data and timestamp';

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->create (
      [t1 => nobj => {}],
      [a1 => account => {}],
      [c1 => comment => {
        thread => 't1',
        data => {
          body => $current->generate_text (text1 => {}),
          abc => $current->generate_text (text3 => {}),
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
    return $current->json (['comment', 'edit.json'], {
      comment_id => $current->o ('c1')->{comment_id},
    });
  })->then (sub {
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
      is $c->{data}->{body}, $current->o ('text1');
      is $c->{data}->{abc}, $current->o ('text3');
      is $c->{internal_data}->{hoge}, $current->o ('text2');
      is $c->{author_status}, 5;
      is $c->{owner_status}, 6;
      is $c->{admin_status}, 7;
    } $current->c;
  });
} n => 10, name => 'edit.json empty change';

Test {
  my $current = shift;
  return $current->create (
    [a1 => account => {}],
    [a2 => account => {}],
    [c1 => comment => {data => {body => $current->generate_text (t1 => {})},
                       author => 'a1'}],
  )->then (sub {
    return $current->json (['comment', 'edit.json'], {
      comment_id => $current->o ('c1')->{comment_id},
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      data_delta => {
        body => $current->generate_text (t2 => {}),
      },
      validate_operator_is_author => 1,
    });
  })->then (sub {
    return $current->json (['comment', 'list.json'], {
      comment_id => $current->o ('c1')->{comment_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $c = $result->{json}->{items}->[0];
      is $c->{data}->{body}, $current->o ('t2');
    } $current->c, name => 'validation passed';
    return $current->are_errors ([['comment', 'edit.json'], {
      comment_id => $current->o ('c1')->{comment_id},
      operator_nobj_key => $current->o ('a2')->{nobj_key},
      data_delta => {
        body => $current->generate_text (t3 => {}),
      },
      validate_operator_is_author => 1,
    }], [{reason => 'Bad operator'}]);
  })->then (sub {
    return $current->json (['comment', 'list.json'], {
      comment_id => $current->o ('c1')->{comment_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $c = $result->{json}->{items}->[0];
      is $c->{data}->{body}, $current->o ('t2');
    } $current->c, name => 'validation failed because of wrong operator';
    return $current->json (['comment', 'edit.json'], {
      comment_id => $current->o ('c1')->{comment_id},
      operator_nobj_key => $current->o ('a2')->{nobj_key},
      data_delta => {
        body => $current->generate_text (t4 => {}),
      },
    });
  })->then (sub {
    return $current->json (['comment', 'list.json'], {
      comment_id => $current->o ('c1')->{comment_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $c = $result->{json}->{items}->[0];
      is $c->{data}->{body}, $current->o ('t4');
    } $current->c, name => 'validation skipped';
    return $current->are_errors ([['comment', 'edit.json'], {
      comment_id => $current->o ('c1')->{comment_id},
      data_delta => {
        body => $current->generate_text (t5 => {}),
      },
      validate_operator_is_author => 1,
    }], [{reason => 'Bad operator'}]);
  })->then (sub {
    return $current->json (['comment', 'list.json'], {
      comment_id => $current->o ('c1')->{comment_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $c = $result->{json}->{items}->[0];
      is $c->{data}->{body}, $current->o ('t4');
    } $current->c, name => 'validation failed because of missing operator';
  });
} n => 6, name => 'author validation';

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
