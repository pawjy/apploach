use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  $current->set_o (t1 => time);
  return $current->create (
    [o1 => nobj => {}],
    [s1 => nobj => {}],
    [s2 => nobj => {}],
    [r1 => nobj => {}],
    [y1 => nobj => {}],
    [l1 => nobj => {}],
  )->then (sub {
    return $current->json (['alarm', 'update.json'], {
      operator_nobj_key => $current->o ('o1')->{nobj_key},
      scope_nobj_key => $current->o ('s1')->{nobj_key},
      timestamp => $current->o ('t1'),
      alarm => [
        map { perl2json_chars $_ }
            {
              target_nobj_key => $current->o ('r1')->{nobj_key},
              type_nobj_key => $current->o ('y1')->{nobj_key},
              level_nobj_key => $current->o ('l1')->{nobj_key},
              data => {
                abc => $current->generate_text (x1 => {}),
              },
            },
      ],
    });
  })->then (sub {
    return $current->are_errors (
      [['alarm', 'update.json'], {
        scope_nobj_key => $current->o ('s1')->{nobj_key},
        timestamp => $current->o ('t1') + 6000,
        alarm => [
          map { perl2json_chars $_ }
              {
                target_nobj_key => $current->o ('r1')->{nobj_key},
                type_nobj_key => rand,
                level_nobj_key => rand,
                data => {
                  abc => $current->generate_text (x2 => {}),
                },
              },
        ],
      }],
      [
        ['new_nobj', 'operator'],
        ['new_nobj', 'scope'],
        ['json_opt', 'alarm'],
        {p => {
          alarm => perl2json_chars ({
            target_nobj_key => undef,
            type_nobj_key => rand,
            level_nobj_key => rand,
            data => {},
          }),
        }, status => 400},
        {p => {
          alarm => perl2json_chars ({
            target_nobj_key => rand,
            type_nobj_key => undef,
            level_nobj_key => rand,
            data => {},
          }),
        }, status => 400},
        {p => {
          alarm => perl2json_chars ({
            target_nobj_key => rand,
            type_nobj_key => rand,
            level_nobj_key => undef,
            data => {},
          }),
        }, status => 400},
        {p => {operator_nobj_key => undef}, status => 400},
        {p => {scope_nobj_key => undef}, status => 400},
      ],
    );
  })->then (sub {
    return $current->json (['alarm', 'list.json'], {
      scope_nobj_key => $current->o ('s1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      ok ! $result->{json}->{has_next};

      my $item1 = $result->{json}->{items}->[0];
      is $item1->{target_nobj_key}, $current->o ('r1')->{nobj_key};
      is $item1->{target_index_nobj_key}, 'apploach-null';
      is $item1->{type_nobj_key}, $current->o ('y1')->{nobj_key};
      is $item1->{level_nobj_key}, $current->o ('l1')->{nobj_key};
      ok $item1->{created};
      is $item1->{started}, $current->o ('t1');
      is $item1->{latest}, $current->o ('t1');
      is $item1->{ended}, 0;
      is $item1->{data}->{abc}, $current->o ('x1');
    } $current->c;
  })->then (sub {
    return $current->json (['alarm', 'list.json'], {
      scope_nobj_key => $current->o ('s2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c, name => 'other scope not affected';
  });
} n => 13, name => 'new nobj key';

Test {
  my $current = shift;
  $current->set_o (t1 => time);
  return $current->create (
    [o1 => nobj => {}],
    [s1 => nobj => {}],
    [s2 => nobj => {}],
    [r1 => nobj => {}],
    [y1 => nobj => {}],
    [l1 => nobj => {}],
    [l2 => nobj => {}],
    [u1 => nobj => {}],
    [topic1 => nobj => {}],
  )->then (sub {
    return $current->create (
      [sub1 => topic_subscription => {
        topic_nobj_key => $current->o ('topic1')->{nobj_key},
        subscriber => 'u1',
      }],
    );
  })->then (sub {
    return $current->json (['alarm', 'update.json'], {
      operator_nobj_key => $current->o ('o1')->{nobj_key},
      scope_nobj_key => $current->o ('s1')->{nobj_key},
      timestamp => $current->o ('t1'),
      alarm => [
        map { perl2json_chars $_ }
            {
              target_nobj_key => $current->o ('r1')->{nobj_key},
              type_nobj_key => $current->o ('y1')->{nobj_key},
              level_nobj_key => $current->o ('l1')->{nobj_key},
            },
      ],
      notification_topic_nobj_key => $current->o ('topic1')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      {
        my $item = $result->{json}->{items}->[0];
        is $item->{data}->{scope_nobj_key}, $current->o ('s1')->{nobj_key};
        is $item->{timestamp}, $current->o ('t1');
        is $item->{data}->{timestamp}, $current->o ('t1');
        is $item->{data}->{prev_timestamp}, 0;
        ok $item->{data}->{has_in_active};
        ok $item->{data}->{has_started};
        ok ! $item->{data}->{has_ended};
      }
    } $current->c;
    return $current->json (['alarm', 'update.json'], {
      operator_nobj_key => $current->o ('o1')->{nobj_key},
      scope_nobj_key => $current->o ('s1')->{nobj_key},
      timestamp => $current->o ('t1')+100,
      alarm => [
        map { perl2json_chars $_ }
            {
              target_nobj_key => $current->o ('r1')->{nobj_key},
              type_nobj_key => $current->o ('y1')->{nobj_key},
              level_nobj_key => $current->o ('l2')->{nobj_key}, # changed
            },
      ],
      notification_topic_nobj_key => $current->o ('topic1')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
    } $current->c;
    return $current->json (['alarm', 'update.json'], {
      operator_nobj_key => $current->o ('o1')->{nobj_key},
      scope_nobj_key => $current->o ('s1')->{nobj_key},
      timestamp => $current->o ('t1')+200,
      alarm => [
      ],
      notification_topic_nobj_key => $current->o ('topic1')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      {
        my $item = $result->{json}->{items}->[0];
        is $item->{data}->{scope_nobj_key}, $current->o ('s1')->{nobj_key};
        is $item->{timestamp}, $current->o ('t1')+200;
        is $item->{data}->{timestamp}, $current->o ('t1')+200;
        is $item->{data}->{prev_timestamp}, $current->o ('t1')+100;
        ok ! $item->{data}->{has_in_active};
        ok ! $item->{data}->{has_started};
        ok $item->{data}->{has_ended};
      }
    } $current->c;
  });
} n => 17, name => 'notification';

Test {
  my $current = shift;
  $current->set_o (t1 => time);
  return $current->create (
    [o1 => nobj => {}],
    [s1 => nobj => {}],
    [r1 => nobj => {}],
    [ri1 => nobj => {}],
    [y1 => nobj => {}],
    [l1 => nobj => {}],
    [r2 => nobj => {}],
    [y2 => nobj => {}],
    [l2 => nobj => {}],
  )->then (sub {
    return $current->json (['alarm', 'list.json'], {
      scope_nobj_key => $current->o ('s1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c;
    return $current->json (['alarm', 'update.json'], {
      operator_nobj_key => $current->o ('o1')->{nobj_key},
      scope_nobj_key => $current->o ('s1')->{nobj_key},
      timestamp => $current->o ('t1'),
      alarm => [
        map { perl2json_chars $_ }
            {
              target_nobj_key => $current->o ('r1')->{nobj_key},
              target_index_nobj_key => $current->o ('ri1')->{nobj_key},
              type_nobj_key => $current->o ('y1')->{nobj_key},
              level_nobj_key => $current->o ('l1')->{nobj_key},
              data => {
                abc => $current->generate_text (x1 => {}),
              },
            },
      ],
    });
  })->then (sub {
    return $current->json (['alarm', 'list.json'], {
      scope_nobj_key => $current->o ('s1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;

      my $item1 = $result->{json}->{items}->[0];
      is $item1->{target_nobj_key}, $current->o ('r1')->{nobj_key};
      is $item1->{target_index_nobj_key}, $current->o ('ri1')->{nobj_key};
      is $item1->{type_nobj_key}, $current->o ('y1')->{nobj_key};
      is $item1->{level_nobj_key}, $current->o ('l1')->{nobj_key};
      ok $item1->{created};
      is $item1->{started}, $current->o ('t1');
      is $item1->{latest}, $current->o ('t1');
      is $item1->{ended}, 0;
      is $item1->{data}->{abc}, $current->o ('x1');
    } $current->c;
    return $current->json (['alarm', 'update.json'], {
      operator_nobj_key => $current->o ('o1')->{nobj_key},
      scope_nobj_key => $current->o ('s1')->{nobj_key},
      timestamp => $current->o ('t1')+100,
      alarm => [
        map { perl2json_chars $_ }
            {
              target_nobj_key => $current->o ('r1')->{nobj_key},
              type_nobj_key => $current->o ('y1')->{nobj_key},
              level_nobj_key => $current->o ('l1')->{nobj_key},
              data => {
                abc => $current->generate_text (x2 => {}),
              },
            },
            {
              target_nobj_key => $current->o ('r2')->{nobj_key},
              type_nobj_key => $current->o ('y2')->{nobj_key},
              level_nobj_key => $current->o ('l2')->{nobj_key},
              data => {
                abc => $current->generate_text (x3 => {}),
              },
            },
      ],
    });
  })->then (sub {
    return $current->json (['alarm', 'list.json'], {
      scope_nobj_key => $current->o ('s1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;

      my $item1 = $result->{json}->{items}->[1];
      is $item1->{target_nobj_key}, $current->o ('r1')->{nobj_key};
      is $item1->{type_nobj_key}, $current->o ('y1')->{nobj_key};
      is $item1->{level_nobj_key}, $current->o ('l1')->{nobj_key};
      ok $item1->{created};
      is $item1->{started}, $current->o ('t1');
      is $item1->{latest}, $current->o ('t1')+100;
      is $item1->{ended}, 0;
      is $item1->{data}->{abc}, $current->o ('x2');

      my $item2 = $result->{json}->{items}->[0];
      is $item2->{target_nobj_key}, $current->o ('r2')->{nobj_key};
      is $item2->{type_nobj_key}, $current->o ('y2')->{nobj_key};
      is $item2->{level_nobj_key}, $current->o ('l2')->{nobj_key};
      ok $item2->{created};
      is $item2->{started}, $current->o ('t1')+100;
      is $item2->{latest}, $current->o ('t1')+100;
      is $item2->{ended}, 0;
      is $item2->{data}->{abc}, $current->o ('x3');
    } $current->c;
    return $current->json (['alarm', 'update.json'], {
      operator_nobj_key => $current->o ('o1')->{nobj_key},
      scope_nobj_key => $current->o ('s1')->{nobj_key},
      timestamp => $current->o ('t1')+200,
      alarm => [
        map { perl2json_chars $_ }
            {
              target_nobj_key => $current->o ('r1')->{nobj_key},
              type_nobj_key => $current->o ('y2')->{nobj_key},
              level_nobj_key => $current->o ('l2')->{nobj_key},
              data => {
                abc => $current->generate_text (x4 => {}),
              },
            },
            {
              target_nobj_key => $current->o ('r2')->{nobj_key},
              type_nobj_key => $current->o ('y2')->{nobj_key},
              level_nobj_key => $current->o ('l1')->{nobj_key},
              data => {
                abc => $current->generate_text (x5 => {}),
              },
            },
      ],
    });
  })->then (sub {
    return $current->json (['alarm', 'list.json'], {
      scope_nobj_key => $current->o ('s1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 3;
      {
        my $item1 = $result->{json}->{items}->[2];
        is $item1->{target_nobj_key}, $current->o ('r1')->{nobj_key};
        is $item1->{type_nobj_key}, $current->o ('y1')->{nobj_key};
        is $item1->{level_nobj_key}, $current->o ('l1')->{nobj_key};
        ok $item1->{created};
        is $item1->{started}, $current->o ('t1');
        is $item1->{latest}, $current->o ('t1')+100;
        is $item1->{ended}, $current->o ('t1')+200, 'closed';
        is $item1->{data}->{abc}, $current->o ('x2');
      }
      my $item2 = $result->{json}->{items}->[1];
      is $item2->{target_nobj_key}, $current->o ('r2')->{nobj_key};
      is $item2->{type_nobj_key}, $current->o ('y2')->{nobj_key};
      is $item2->{level_nobj_key}, $current->o ('l1')->{nobj_key}, 'level changed';
      ok $item2->{created};
      is $item2->{started}, $current->o ('t1')+100;
      is $item2->{latest}, $current->o ('t1')+200;
      is $item2->{ended}, 0;
      is $item2->{data}->{abc}, $current->o ('x5');
      {
        my $item1 = $result->{json}->{items}->[0];
        is $item1->{target_nobj_key}, $current->o ('r1')->{nobj_key};
        is $item1->{type_nobj_key}, $current->o ('y2')->{nobj_key};
        is $item1->{level_nobj_key}, $current->o ('l2')->{nobj_key};
        ok $item1->{created};
        is $item1->{started}, $current->o ('t1')+200;
        is $item1->{latest}, $current->o ('t1')+200;
        is $item1->{ended}, 0;
        is $item1->{data}->{abc}, $current->o ('x4');
      }
    } $current->c;
    return $current->json (['alarm', 'update.json'], {
      operator_nobj_key => $current->o ('o1')->{nobj_key},
      scope_nobj_key => $current->o ('s1')->{nobj_key},
      timestamp => $current->o ('t1')+300,
    });
  })->then (sub {
    return $current->json (['alarm', 'list.json'], {
      scope_nobj_key => $current->o ('s1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 3;
      {
        my $item1 = $result->{json}->{items}->[2];
        is $item1->{target_nobj_key}, $current->o ('r1')->{nobj_key};
        is $item1->{type_nobj_key}, $current->o ('y1')->{nobj_key};
        is $item1->{level_nobj_key}, $current->o ('l1')->{nobj_key};
        ok $item1->{created};
        is $item1->{started}, $current->o ('t1');
        is $item1->{latest}, $current->o ('t1')+100;
        is $item1->{ended}, $current->o ('t1')+200;
        is $item1->{data}->{abc}, $current->o ('x2');
      }
      my $item2 = $result->{json}->{items}->[1];
      is $item2->{target_nobj_key}, $current->o ('r2')->{nobj_key};
      is $item2->{type_nobj_key}, $current->o ('y2')->{nobj_key};
      is $item2->{level_nobj_key}, $current->o ('l1')->{nobj_key}, 'level changed';
      ok $item2->{created};
      is $item2->{started}, $current->o ('t1')+100;
      is $item2->{latest}, $current->o ('t1')+200;
      is $item2->{ended}, $current->o ('t1')+300;
      is $item2->{data}->{abc}, $current->o ('x5');
      {
        my $item1 = $result->{json}->{items}->[0];
        is $item1->{target_nobj_key}, $current->o ('r1')->{nobj_key};
        is $item1->{type_nobj_key}, $current->o ('y2')->{nobj_key};
        is $item1->{level_nobj_key}, $current->o ('l2')->{nobj_key};
        ok $item1->{created};
        is $item1->{started}, $current->o ('t1')+200;
        is $item1->{latest}, $current->o ('t1')+200;
        is $item1->{ended}, $current->o ('t1')+300;
        is $item1->{data}->{abc}, $current->o ('x4');
      }
    } $current->c;
  });
} n => 78, name => 'alarm updates';

Test {
  my $current = shift;
  $current->set_o (t1 => time);
  return $current->create (
    [o1 => nobj => {}],
    [s1 => nobj => {}],
    [r1 => nobj => {}],
    [ri1 => nobj => {}],
    [y1 => nobj => {}],
    [l1 => nobj => {}],
    [r2 => nobj => {}],
    [ri2 => nobj => {}],
    [y2 => nobj => {}],
    [l2 => nobj => {}],
  )->then (sub {
    return $current->json (['alarm', 'update.json'], {
      operator_nobj_key => $current->o ('o1')->{nobj_key},
      scope_nobj_key => $current->o ('s1')->{nobj_key},
      timestamp => $current->o ('t1')+100,
      alarm => [
        map { perl2json_chars $_ }
            {
              target_nobj_key => $current->o ('r1')->{nobj_key},
              target_index_nobj_key => $current->o ('ri1')->{nobj_key},
              type_nobj_key => $current->o ('y1')->{nobj_key},
              level_nobj_key => $current->o ('l1')->{nobj_key},
              data => {
                abc => $current->generate_text (x2 => {}),
              },
            },
            {
              target_nobj_key => $current->o ('r2')->{nobj_key},
              target_index_nobj_key => $current->o ('ri2')->{nobj_key},
              type_nobj_key => $current->o ('y2')->{nobj_key},
              level_nobj_key => $current->o ('l2')->{nobj_key},
              data => {
                abc => $current->generate_text (x3 => {}),
              },
            },
      ],
    });
  })->then (sub {
    return $current->json (['alarm', 'list.json'], {
      scope_nobj_key => $current->o ('s1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;

      my $item1 = $result->{json}->{items}->[1];
      is $item1->{target_nobj_key}, $current->o ('r1')->{nobj_key};
      is $item1->{type_nobj_key}, $current->o ('y1')->{nobj_key};
      is $item1->{level_nobj_key}, $current->o ('l1')->{nobj_key};
      ok $item1->{created};
      is $item1->{started}, $current->o ('t1')+100;
      is $item1->{latest}, $current->o ('t1')+100;
      is $item1->{ended}, 0;
      is $item1->{data}->{abc}, $current->o ('x2');

      my $item2 = $result->{json}->{items}->[0];
      is $item2->{target_nobj_key}, $current->o ('r2')->{nobj_key};
      is $item2->{type_nobj_key}, $current->o ('y2')->{nobj_key};
      is $item2->{level_nobj_key}, $current->o ('l2')->{nobj_key};
      ok $item2->{created};
      is $item2->{started}, $current->o ('t1')+100;
      is $item2->{latest}, $current->o ('t1')+100;
      is $item2->{ended}, 0;
      is $item2->{data}->{abc}, $current->o ('x3');
    } $current->c;
    return $current->json (['alarm', 'update.json'], {
      operator_nobj_key => $current->o ('o1')->{nobj_key},
      scope_nobj_key => $current->o ('s1')->{nobj_key},
      timestamp => $current->o ('t1')+300,
    });
  })->then (sub {
    return $current->json (['alarm', 'list.json'], {
      scope_nobj_key => $current->o ('s1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      {
        my $item2 = $result->{json}->{items}->[1];
        is $item2->{target_nobj_key}, $current->o ('r1')->{nobj_key};
        is $item2->{type_nobj_key}, $current->o ('y1')->{nobj_key};
        is $item2->{level_nobj_key}, $current->o ('l1')->{nobj_key}, 'level changed';
        ok $item2->{created};
        is $item2->{started}, $current->o ('t1')+100;
        is $item2->{latest}, $current->o ('t1')+100;
        is $item2->{ended}, $current->o ('t1')+300;
        is $item2->{data}->{abc}, $current->o ('x2');
      }
      {
        my $item1 = $result->{json}->{items}->[0];
        is $item1->{target_nobj_key}, $current->o ('r2')->{nobj_key};
        is $item1->{type_nobj_key}, $current->o ('y2')->{nobj_key};
        is $item1->{level_nobj_key}, $current->o ('l2')->{nobj_key};
        ok $item1->{created};
        is $item1->{started}, $current->o ('t1')+100;
        is $item1->{latest}, $current->o ('t1')+100;
        is $item1->{ended}, $current->o ('t1')+300;
        is $item1->{data}->{abc}, $current->o ('x3');
      }
    } $current->c;
    return $current->json (['alarm', 'update.json'], {
      operator_nobj_key => $current->o ('o1')->{nobj_key},
      scope_nobj_key => $current->o ('s1')->{nobj_key},
      timestamp => $current->o ('t1')+200,
      alarm => [
        map { perl2json_chars $_ }
            {
              target_nobj_key => $current->o ('r1')->{nobj_key},
              target_index_nobj_key => $current->o ('ri1')->{nobj_key},
              type_nobj_key => $current->o ('y1')->{nobj_key},
              level_nobj_key => $current->o ('l2')->{nobj_key},
              data => {
                abc => $current->generate_text (x4 => {}),
              },
            },
            {
              target_nobj_key => $current->o ('r2')->{nobj_key},
              target_index_nobj_key => $current->o ('ri2')->{nobj_key},
              type_nobj_key => $current->o ('y2')->{nobj_key},
              level_nobj_key => $current->o ('l1')->{nobj_key},
              data => {
                abc => $current->generate_text (x5 => {}),
              },
            },
      ],
    });
  })->then (sub {
    return $current->json (['alarm', 'list.json'], {
      scope_nobj_key => $current->o ('s1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;

      my $item1 = $result->{json}->{items}->[1];
      is $item1->{target_nobj_key}, $current->o ('r1')->{nobj_key};
      is $item1->{type_nobj_key}, $current->o ('y1')->{nobj_key};
      is $item1->{level_nobj_key}, $current->o ('l2')->{nobj_key};
      ok $item1->{created};
      is $item1->{started}, $current->o ('t1')+100;
      is $item1->{latest}, $current->o ('t1')+200;
      is $item1->{ended}, $current->o ('t1')+300;
      is $item1->{data}->{abc}, $current->o ('x4');

      my $item2 = $result->{json}->{items}->[0];
      is $item2->{target_nobj_key}, $current->o ('r2')->{nobj_key};
      is $item2->{type_nobj_key}, $current->o ('y2')->{nobj_key};
      is $item2->{level_nobj_key}, $current->o ('l1')->{nobj_key};
      ok $item2->{created};
      is $item2->{started}, $current->o ('t1')+100;
      is $item2->{latest}, $current->o ('t1')+200;
      is $item2->{ended}, $current->o ('t1')+300;
      is $item2->{data}->{abc}, $current->o ('x5');
    } $current->c;
    return $current->json (['alarm', 'update.json'], {
      operator_nobj_key => $current->o ('o1')->{nobj_key},
      scope_nobj_key => $current->o ('s1')->{nobj_key},
      timestamp => $current->o ('t1')-100,
      alarm => [
        map { perl2json_chars $_ }
            {
              target_nobj_key => $current->o ('r1')->{nobj_key},
              target_index_nobj_key => $current->o ('ri1')->{nobj_key},
              type_nobj_key => $current->o ('y1')->{nobj_key},
              level_nobj_key => $current->o ('l1')->{nobj_key},
              data => {
                abc => $current->generate_text (x6 => {}),
              },
            },
            {
              target_nobj_key => $current->o ('r2')->{nobj_key},
              target_index_nobj_key => $current->o ('ri2')->{nobj_key},
              type_nobj_key => $current->o ('y2')->{nobj_key},
              level_nobj_key => $current->o ('l2')->{nobj_key},
              data => {
                abc => $current->generate_text (x7 => {}),
              },
            },
      ],
    });
  })->then (sub {
    return $current->json (['alarm', 'list.json'], {
      scope_nobj_key => $current->o ('s1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;

      my $item1 = $result->{json}->{items}->[1];
      is $item1->{target_nobj_key}, $current->o ('r1')->{nobj_key};
      is $item1->{type_nobj_key}, $current->o ('y1')->{nobj_key};
      is $item1->{level_nobj_key}, $current->o ('l2')->{nobj_key};
      ok $item1->{created};
      is $item1->{started}, $current->o ('t1')+100;
      is $item1->{latest}, $current->o ('t1')+200;
      is $item1->{ended}, $current->o ('t1')+300;
      is $item1->{data}->{abc}, $current->o ('x4');

      my $item2 = $result->{json}->{items}->[0];
      is $item2->{target_nobj_key}, $current->o ('r2')->{nobj_key};
      is $item2->{type_nobj_key}, $current->o ('y2')->{nobj_key};
      is $item2->{level_nobj_key}, $current->o ('l1')->{nobj_key};
      ok $item2->{created};
      is $item2->{started}, $current->o ('t1')+100;
      is $item2->{latest}, $current->o ('t1')+200;
      is $item2->{ended}, $current->o ('t1')+300;
      is $item2->{data}->{abc}, $current->o ('x5');
    } $current->c;
    return $current->json (['alarm', 'update.json'], {
      operator_nobj_key => $current->o ('o1')->{nobj_key},
      scope_nobj_key => $current->o ('s1')->{nobj_key},
      timestamp => $current->o ('t1')+150,
      alarm => [
        map { perl2json_chars $_ }
            {
              target_nobj_key => $current->o ('r1')->{nobj_key},
              target_index_nobj_key => $current->o ('ri1')->{nobj_key},
              type_nobj_key => $current->o ('y1')->{nobj_key},
              level_nobj_key => $current->o ('l1')->{nobj_key},
              data => {
                abc => $current->generate_text (x6 => {}),
              },
            },
            {
              target_nobj_key => $current->o ('r2')->{nobj_key},
              target_index_nobj_key => $current->o ('ri2')->{nobj_key},
              type_nobj_key => $current->o ('y2')->{nobj_key},
              level_nobj_key => $current->o ('l2')->{nobj_key},
              data => {
                abc => $current->generate_text (x7 => {}),
              },
            },
      ],
    });
  })->then (sub {
    return $current->json (['alarm', 'list.json'], {
      scope_nobj_key => $current->o ('s1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;

      my $item1 = $result->{json}->{items}->[1];
      is $item1->{target_nobj_key}, $current->o ('r1')->{nobj_key};
      is $item1->{type_nobj_key}, $current->o ('y1')->{nobj_key};
      is $item1->{level_nobj_key}, $current->o ('l2')->{nobj_key};
      ok $item1->{created};
      is $item1->{started}, $current->o ('t1')+100;
      is $item1->{latest}, $current->o ('t1')+200;
      is $item1->{ended}, $current->o ('t1')+300;
      is $item1->{data}->{abc}, $current->o ('x4');

      my $item2 = $result->{json}->{items}->[0];
      is $item2->{target_nobj_key}, $current->o ('r2')->{nobj_key};
      is $item2->{type_nobj_key}, $current->o ('y2')->{nobj_key};
      is $item2->{level_nobj_key}, $current->o ('l1')->{nobj_key};
      ok $item2->{created};
      is $item2->{started}, $current->o ('t1')+100;
      is $item2->{latest}, $current->o ('t1')+200;
      is $item2->{ended}, $current->o ('t1')+300;
      is $item2->{data}->{abc}, $current->o ('x5');
    } $current->c;
    return $current->json (['nobj', 'logs.json'], {
      target_nobj_key => $current->o ('r1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      {
        my $item = $result->{json}->{items}->[0];
        is $item->{operator_nobj_key}, $current->o ('o1')->{nobj_key};
        is $item->{target_nobj_key}, $current->o ('r1')->{nobj_key};
        is $item->{verb_nobj_key}, $current->o ('y1')->{nobj_key};
        is $item->{data}->{timestamp}, $current->o ('t1')+300;
        is $item->{data}->{started}, $current->o ('t1')+100;
        is $item->{data}->{ended}, $current->o ('t1')+300;
        is $item->{data}->{scope_nobj_key}, $current->o ('s1')->{nobj_key};
        is $item->{data}->{level_nobj_key}, $current->o ('l1')->{nobj_key};
        is $item->{data}->{data}->{abc}, undef;
      }
      {
        my $item = $result->{json}->{items}->[1];
        is $item->{operator_nobj_key}, $current->o ('o1')->{nobj_key};
        is $item->{target_nobj_key}, $current->o ('r1')->{nobj_key};
        is $item->{verb_nobj_key}, $current->o ('y1')->{nobj_key};
        is $item->{data}->{timestamp}, $current->o ('t1')+100;
        is $item->{data}->{started}, $current->o ('t1')+100;
        is $item->{data}->{ended}, 0;
        is $item->{data}->{scope_nobj_key}, $current->o ('s1')->{nobj_key};
        is $item->{data}->{level_nobj_key}, $current->o ('l1')->{nobj_key};
        is $item->{data}->{data}->{abc}, $current->o ('x2');
      }
    } $current->c;
    return $current->json (['nobj', 'logs.json'], {
      target_nobj_key => $current->o ('r1')->{nobj_key},
      target_index_nobj_key => $current->o ('ri1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
    } $current->c;
    return $current->json (['nobj', 'logs.json'], {
      target_nobj_key => $current->o ('r1')->{nobj_key},
      target_index_nobj_key => rand,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c;
  });
} n => 106, name => 'alarm updates old timestamp';

RUN;

=head1 LICENSE

Copyright 2022 Wakaba <wakaba@suikawiki.org>.

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
