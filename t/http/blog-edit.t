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
      [c1 => blog_entry => {
        thread => 't1',
        data => {
          body => $current->generate_text (text1 => {}),
          abc => $current->generate_text (text3 => {}),
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
    return $current->are_errors (
      [['blog', 'edit.json'], {
        blog_entry_id => $current->o ('c1')->{blog_entry_id},
        operator_nobj_key => $current->generate_key (rand, {}),
      }],
      [
        {p => {blog_entry_id => undef},
         reason => 'Bad ID parameter |blog_entry_id|'},
        {p => {blog_entry_id => ''},
         reason => 'Bad ID parameter |blog_entry_id|'},
        {p => {blog_entry_id => 0},
         reason => 'Bad ID parameter |blog_entry_id|'},
        {p => {blog_entry_id => 'abave'},
         reason => 'Bad ID parameter |blog_entry_id|'},
        {p => {blog_entry_id => $current->generate_id (rand, {})},
         reason => 'Object not found'},
        {app_id => $current->generate_id (rand, {}),
         reason => 'Object not found',
         name => 'Different application'},
        {p => {operator_nobj_key => ''}, reason => 'Bad |operator_nobj_key|'},
      ],
    );
  })->then (sub {
    return $current->json (['blog', 'edit.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      data_delta => {
        body => $current->generate_text (text4 => {}),
        abc => undef,
        foo => $current->generate_text (text5 => {}),
      },
      author_status => 10,
      operator_nobj_key => $current->generate_key (rand, {}),
    });
  })->then (sub {
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      with_internal_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{blog_entry_id}, $current->o ('c1')->{blog_entry_id};
      is $c->{data}->{timestamp}, $current->o ('c1')->{timestamp};
      ok $c->{data}->{modified} > $c->{data}->{timestamp};
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
      [c1 => blog_entry => {
        thread => 't1',
        data => {
          body => $current->generate_text (text1 => {}),
          abc => $current->generate_text (text3 => {}),
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
    return $current->json (['blog', 'edit.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      data_delta => {
        timestamp => 63463444,
      },
      internal_data_delta => {
        abc => $current->generate_text (text5 => {}),
      },
      admin_status => 53,
      operator_nobj_key => $current->generate_key (rand, {}),
    });
  })->then (sub {
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      with_internal_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{blog_entry_id}, $current->o ('c1')->{blog_entry_id};
      is $c->{data}->{timestamp}, 63463444;
      ok $c->{data}->{modified} > $c->{data}->{timestamp};
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
      [c1 => blog_entry => {
        thread => 't1',
        data => {
          body => $current->generate_text (text1 => {}),
          abc => $current->generate_text (text3 => {}),
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
    return $current->json (['blog', 'edit.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      data_delta => {
        modified => 63463444,
      },
      internal_data_delta => {
        abc => $current->generate_text (text5 => {}),
      },
      admin_status => 53,
      operator_nobj_key => $current->generate_key (rand, {}),
    });
  })->then (sub {
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      with_internal_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{blog_entry_id}, $current->o ('c1')->{blog_entry_id};
      is $c->{data}->{timestamp}, $current->o ('c1')->{timestamp};
      ok $c->{data}->{modified} > $c->{data}->{timestamp};
      is $c->{data}->{body}, $current->o ('text1');
      is $c->{data}->{abc}, $current->o ('text3');
      is $c->{internal_data}->{abc}, $current->o ('text5');
      is $c->{internal_data}->{hoge}, $current->o ('text2');
      is $c->{internal_data}->{timestamp}, undef;
      is $c->{internal_data}->{modified}, undef;
      is $c->{author_status}, 5;
      is $c->{owner_status}, 6;
      is $c->{admin_status}, 53;
    } $current->c;
  });
} n => 13, name => 'edit.json modify data and modified';

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->create (
      [t1 => nobj => {}],
      [a1 => account => {}],
      [c1 => blog_entry => {
        thread => 't1',
        data => {
          body => $current->generate_text (text1 => {}),
          abc => $current->generate_text (text3 => {}),
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
    return $current->json (['blog', 'edit.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      operator_nobj_key => $current->generate_key (rand, {}),
    });
  })->then (sub {
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      with_internal_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{blog_entry_id}, $current->o ('c1')->{blog_entry_id};
      is $c->{data}->{timestamp}, $current->o ('c1')->{timestamp};
      is $c->{data}->{body}, $current->o ('text1');
      is $c->{data}->{abc}, $current->o ('text3');
      is $c->{internal_data}->{hoge}, $current->o ('text2');
      is $c->{author_status}, 5;
      is $c->{owner_status}, 6;
      is $c->{admin_status}, 7;
    } $current->c;
  });
} n => 9, name => 'edit.json empty change';

Test {
  my $current = shift;
  return $current->create (
    [a1 => account => {}],
    [a2 => account => {}],
    [c1 => blog_entry => {data => {body => $current->generate_text (t1 => {})},
                       author => 'a1'}],
  )->then (sub {
    return $current->json (['blog', 'edit.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      data_delta => {
        body => $current->generate_text (t2 => {}),
      },
    });
  })->then (sub {
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $c = $result->{json}->{items}->[0];
      is $c->{data}->{body}, $current->o ('t2');
    } $current->c, name => 'validation passed';
    return $current->json (['blog', 'edit.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      operator_nobj_key => $current->o ('a2')->{nobj_key},
      data_delta => {
        body => $current->generate_text (t3 => {}),
      },
    });
  })->then (sub {
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $c = $result->{json}->{items}->[0];
      is $c->{data}->{body}, $current->o ('t3');
    } $current->c, name => 'anyone can be operator';
    return $current->json (['blog', 'edit.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      operator_nobj_key => $current->o ('a2')->{nobj_key},
      data_delta => {
        body => $current->generate_text (t4 => {}),
      },
    });
  })->then (sub {
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $c = $result->{json}->{items}->[0];
      is $c->{data}->{body}, $current->o ('t4');
    } $current->c, name => 'validation skipped';
    return $current->are_errors ([['blog', 'edit.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      data_delta => {
        body => $current->generate_text (t5 => {}),
      },
      validate_operator_is_author => 1,
    }], [{reason => 'Bad |operator_nobj_key|'}]);
  })->then (sub {
    return $current->are_errors ([['blog', 'edit.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      data_delta => {
        body => $current->generate_text (t6 => {}),
      },
    }], [{reason => 'Bad |operator_nobj_key|'}]);
  })->then (sub {
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $c = $result->{json}->{items}->[0];
      is $c->{data}->{body}, $current->o ('t4');
    } $current->c, name => 'validation failed because of missing operator';
  });
} n => 6, name => 'author validation';

Test {
  my $current = shift;
  return $current->create (
    [a1 => account => {}],
    [c1 => blog_entry => {}],
  )->then (sub {
    return $current->json (['blog', 'edit.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      author_status => 4,
    });
  })->then (sub {
    return $current->json (['nobj', 'statusinfo.json'], {
      target_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $v = $result->{json}->{info}->{$current->o ('c1')->{nobj_key}};
      $current->set_o (l1 => $v->{data});
      ok $v->{data}->{log_id};
      ok $v->{data}->{timestamp};
      is $v->{data}->{old}->{author_status}, 2;
      is $v->{data}->{old}->{owner_status}, 2;
      is $v->{data}->{old}->{admin_status}, 2;
      is $v->{data}->{new}->{author_status}, 4;
      is $v->{data}->{new}->{owner_status}, 2;
      is $v->{data}->{new}->{admin_status}, 2;
      is 0+keys %{$v->{author_data}}, 0;
      is 0+keys %{$v->{owner_data}}, 0;
      is 0+keys %{$v->{admin_data}}, 0;
    } $current->c;
    return $current->json (['nobj', 'logs.json'], {
      log_id => $current->o ('l1')->{log_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $v = $result->{json}->{items}->[0];
      is $v->{log_id}, $current->o ('l1')->{log_id};
      is $v->{data}->{timestamp}, $current->o ('l1')->{timestamp};
      is $v->{data}->{data}->{old}->{author_status}, 2;
      is $v->{data}->{data}->{old}->{owner_status}, 2;
      is $v->{data}->{data}->{old}->{admin_status}, 2;
      is $v->{data}->{data}->{new}->{author_status}, 4;
      is $v->{data}->{data}->{new}->{owner_status}, 2;
      is $v->{data}->{data}->{new}->{admin_status}, 2;
      is 0+keys %{$v->{data}->{author_data}}, 0;
      is 0+keys %{$v->{data}->{owner_data}}, 0;
      is 0+keys %{$v->{data}->{admin_data}}, 0;
      is $v->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('c1')->{nobj_key};
      is $v->{verb_nobj_key}, 'apploach-set-status';
    } $current->c;
  });
} n => 25, name => 'status, logs';

Test {
  my $current = shift;
  return $current->create (
    [a1 => account => {}],
    [c1 => blog_entry => {author => 'a1'}],
  )->then (sub {
    return $current->json (['blog', 'edit.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      owner_status => 4,
      status_info_author_data => {
        hoge => $current->generate_text (t1 => {}),
      },
      status_info_owner_data => {
        hoge => $current->generate_text (t2 => {}),
      },
      status_info_admin_data => {
        hoge => $current->generate_text (t3 => {}),
      },
    });
  })->then (sub {
    return $current->json (['nobj', 'statusinfo.json'], {
      target_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $v = $result->{json}->{info}->{$current->o ('c1')->{nobj_key}};
      $current->set_o (l1 => $v->{data});
      ok $v->{data}->{log_id};
      ok $v->{data}->{timestamp};
      is $v->{data}->{old}->{author_status}, 2;
      is $v->{data}->{old}->{owner_status}, 2;
      is $v->{data}->{old}->{admin_status}, 2;
      is $v->{data}->{new}->{author_status}, 2;
      is $v->{data}->{new}->{owner_status}, 4;
      is $v->{data}->{new}->{admin_status}, 2;
      is $v->{author_data}->{hoge}, $current->o ('t1');
      is $v->{owner_data}->{hoge}, $current->o ('t2');
      is $v->{admin_data}->{hoge}, $current->o ('t3');
    } $current->c;
    return $current->json (['nobj', 'logs.json'], {
      log_id => $current->o ('l1')->{log_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $v = $result->{json}->{items}->[0];
      is $v->{log_id}, $current->o ('l1')->{log_id};
      is $v->{data}->{timestamp}, $current->o ('l1')->{timestamp};
      is $v->{data}->{data}->{old}->{author_status}, 2;
      is $v->{data}->{data}->{old}->{owner_status}, 2;
      is $v->{data}->{data}->{old}->{admin_status}, 2;
      is $v->{data}->{data}->{new}->{author_status}, 2;
      is $v->{data}->{data}->{new}->{owner_status}, 4;
      is $v->{data}->{data}->{new}->{admin_status}, 2;
      is $v->{data}->{author_data}->{hoge}, $current->o ('t1');
      is $v->{data}->{owner_data}->{hoge}, $current->o ('t2');
      is $v->{data}->{admin_data}->{hoge}, $current->o ('t3');
      is $v->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('c1')->{nobj_key};
      is $v->{verb_nobj_key}, 'apploach-set-status';
    } $current->c;
    return $current->json (['blog', 'edit.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      status_info_owner_data => {
        hoge => $current->generate_text (t5 => {}),
      },
    });
  })->then (sub {
    return $current->json (['nobj', 'statusinfo.json'], {
      target_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $v = $result->{json}->{info}->{$current->o ('c1')->{nobj_key}};
      is $v->{author_data}->{hoge}, $current->o ('t1');
      is $v->{owner_data}->{hoge}, $current->o ('t5');
      is $v->{admin_data}->{hoge}, $current->o ('t3');
    } $current->c;
  });
} n => 28, name => 'status, logs - 2';

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->create (
      [t1 => nobj => {}],
      [a1 => account => {}],
      [c1 => blog_entry => {
        thread => 't1',
        data => {
          title => $current->generate_text (text1 => {}),
        },
      }],
    );
  })->then (sub {
    return $current->json (['blog', 'edit.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      data_delta => {
        title => $current->generate_text (text3 => {}),
      },
      operator_nobj_key => $current->generate_key (rand, {}),
    });
  })->then (sub {
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      with_internal_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{data}->{title}, $current->o ('text3');
      is $c->{internal_data}->{title}, undef;
    } $current->c;
    return $current->json (['blog', 'edit.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      data_delta => {
        title => $current->generate_text (text4 => {}),
      },
      operator_nobj_key => $current->generate_key (rand, {}),
    });
  })->then (sub {
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      with_internal_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{data}->{title}, $current->o ('text4');
    } $current->c;
    return $current->json (['blog', 'edit.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
      data_delta => {
        title => undef,
      },
      operator_nobj_key => $current->generate_key (rand, {}),
    });
  })->then (sub {
    return $current->json (['blog', 'list.json'], {
      blog_entry_id => $current->o ('c1')->{blog_entry_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{data}->{title}, undef;
    } $current->c;
  });
} n => 7, name => 'modify title';

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
