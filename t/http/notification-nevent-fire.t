use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [c1 => nobj => {}],
    [u1 => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
  )->then (sub {
    return $current->are_errors (
      [['notification', 'nevent', 'fire.json'], {
        topic_nobj_key => $current->o ('t1')->{nobj_key},
        data => {abv => 10774},
      }],
      [
        ['new_nobj', 'topic'],
        ['new_nobj_opt', 'messages_station'],
        ['new_nobj_opt', 'messages_space'],
        ['json', 'data'],
      ],
    );
  })->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      data => {abv => 774},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{nevent_id};
      like $result->{res}->body_bytes, qr{"nevent_id"\s*:\s*"};
      ok $result->{json}->{timestamp};
      is $result->{json}->{expires}, $result->{json}->{timestamp} + 30*24*60*60;
      is $result->{json}->{queued_count}, 1;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      like $result->{res}->body_bytes, qr{"nevent_id"\s*:\s*"};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
    } $current->c, name => 'nevent record';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      like $result->{res}->body_bytes, qr{"nevent_id"\s*:\s*"};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
      is $ev1->{topic_subscription_data}->{foo}, 54;
    } $current->c, name => 'nevent_queue record';
  });
} n => 23, name => 'fire topic subscribed by a subscriber';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      data => {abv => 774.2},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{nevent_id};
      ok $result->{json}->{timestamp};
      ok $result->{json}->{timestamp} < $result->{json}->{expires};
      is $result->{json}->{queued_count}, 0;
    } $current->c;
  });
} n => 4, name => 'no subscription';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [c1 => nobj => {}],
    [c2 => nobj => {}],
    [c3 => nobj => {}],
    [c4 => nobj => {}],
    [u1 => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
    [sub2 => topic_subscription => {
      topic => 't1', channel => 'c2', subscriber => 'u1',
      status => 2, data => {foo => 12.5},
    }],
    [sub3 => topic_subscription => {
      topic => 't1', channel => 'c3', subscriber => 'u1',
      status => 3, # disabled
      data => {foo => 412.5},
    }],
    [sub4 => topic_subscription => {
      topic => 't1', channel => 'c4', subscriber => 'u1',
      status => 4, # inherit
      data => {foo => 4},
    }],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      data => {abv => 774},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{nevent_id};
      like $result->{res}->body_bytes, qr{"nevent_id"\s*:\s*"};
      ok $result->{json}->{timestamp};
      ok $result->{json}->{timestamp} < $result->{json}->{expires};
      is $result->{json}->{queued_count}, 2;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
    } $current->c, name => 'nevent record';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
      is $ev1->{topic_subscription_data}->{foo}, 54;
    } $current->c, name => 'nevent_queue record - 1';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
      is $ev1->{topic_subscription_data}->{foo}, 12.5;
    } $current->c, name => 'nevent_queue record - 2';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c3')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c, name => 'nevent_queue record - 3';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c4')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c, name => 'nevent_queue record - 4';
  });
} n => 30, name => 'multiple subscription channels';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [c1 => nobj => {}],
    [u1 => nobj => {}],
    [u2 => nobj => {}],
    [u3 => nobj => {}],
    [u4 => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
    [sub2 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u2',
      status => 2, data => {foo => 112.5},
    }],
    [sub3 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u3',
      status => 3, # disabled
      data => {foo => 412.5},
    }],
    [sub4 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u4',
      status => 4, # inherit
      data => {foo => 4},
    }],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      data => {abv => 774},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{nevent_id};
      like $result->{res}->body_bytes, qr{"nevent_id"\s*:\s*"};
      ok $result->{json}->{timestamp};
      ok $result->{json}->{timestamp} < $result->{json}->{expires};
      is $result->{json}->{queued_count}, 2;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
    } $current->c, name => 'nevent record - u1';
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u2')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
    } $current->c, name => 'nevent record - u2';
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u3')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c, name => 'nevent record - u3';
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u4')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c, name => 'nevent record - u4';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      $result->{json}->{items} = [sort {
        $a->{topic_subscription_data}->{foo} <=>
        $b->{topic_subscription_data}->{foo};
      } @{$result->{json}->{items}}];

      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
      is $ev1->{topic_subscription_data}->{foo}, 54;

      my $ev2 = $result->{json}->{items}->[1];
      is $ev2->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev2->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev2->{expires}, $current->o ('ev1')->{expires};
      is $ev2->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
      is $ev2->{subscriber_nobj_key}, $current->o ('u2')->{nobj_key};
      is $ev2->{data}->{abv}, 774;
      is $ev2->{topic_subscription_data}->{foo}, 112.5;
    } $current->c, name => 'nevent_queue record';
  });
} n => 36, name => 'multiple subscriptions';

Test {
  my $current = shift;
  return $current->create (
    [c1 => nobj => {}],
    [u1 => nobj => {}],
    ['u1-default' => nobj => {}],
    ['u1-followed' => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 'u1-default', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
    [sub2 => topic_subscription => {
      topic => 'u1-followed', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 12.5},
    }],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('u1-followed')->{nobj_key},
      topic_fallback_nobj_key => [rand,
                                  $current->o ('u1-default')->{nobj_key}],
      data => {abv => 774},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{queued_count}, 1;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{topic_nobj_key}, $current->o ('u1-followed')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
    } $current->c, name => 'nevent record';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{topic_nobj_key}, $current->o ('u1-followed')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
      is $ev1->{topic_subscription_data}->{foo}, 12.5;
    } $current->c, name => 'nevent_queue record';
  });
} n => 11, name => 'topic chain - specific topic subscription';

Test {
  my $current = shift;
  return $current->create (
    [c1 => nobj => {}],
    [u1 => nobj => {}],
    ['u1-default' => nobj => {}],
    ['u1-followed' => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 'u1-default', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('u1-followed')->{nobj_key},
      topic_fallback_nobj_key => [rand,
                                  $current->o ('u1-default')->{nobj_key}],
      data => {abv => 774},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{queued_count}, 1;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{topic_nobj_key}, $current->o ('u1-followed')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
    } $current->c, name => 'nevent record';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{topic_nobj_key}, $current->o ('u1-followed')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
      is $ev1->{topic_subscription_data}->{foo}, 54;
    } $current->c, name => 'nevent_queue record';
  });
} n => 11, name => 'topic chain - fallback topic subscription only';

Test {
  my $current = shift;
  return $current->create (
    [c1 => nobj => {}],
    [u1 => nobj => {}],
    ['u1-default' => nobj => {}],
    ['u1-followed' => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 'u1-default', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
    [sub2 => topic_subscription => {
      topic => 'u1-followed', channel => 'c1', subscriber => 'u1',
      status => 4, # inherit
      data => {foo => 12.5},
    }],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('u1-followed')->{nobj_key},
      topic_fallback_nobj_key => [rand,
                                  $current->o ('u1-default')->{nobj_key}],
      data => {abv => 774},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{queued_count}, 1;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{topic_nobj_key}, $current->o ('u1-followed')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
    } $current->c, name => 'nevent record';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{topic_nobj_key}, $current->o ('u1-followed')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
      is $ev1->{topic_subscription_data}->{foo}, 54;
    } $current->c, name => 'nevent_queue record';
  });
} n => 11, name => 'topic chain - explicit inherit topic subscription';

Test {
  my $current = shift;
  return $current->create (
    [c1 => nobj => {}],
    [u1 => nobj => {}],
    ['u1-default' => nobj => {}],
    ['u1-followed' => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 'u1-default', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
    [sub2 => topic_subscription => {
      topic => 'u1-followed', channel => 'c1', subscriber => 'u1',
      status => 3, # disabled
      data => {foo => 12.5},
    }],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('u1-followed')->{nobj_key},
      topic_fallback_nobj_key => [rand,
                                  $current->o ('u1-default')->{nobj_key}],
      data => {abv => 774},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{queued_count}, 0;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c, name => 'nevent record';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c, name => 'nevent_queue record';
  });
} n => 3, name => 'topic chain - specific topic subscription overridden';

Test {
  my $current = shift;
  my $timestamp = time - rand 10000000;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [c1 => nobj => {}],
    [u1 => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      data => {abv => 774},
      timestamp => $timestamp,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{timestamp}, $timestamp;
      ok time < $result->{json}->{expires};
      is $result->{json}->{queued_count}, 1;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
    } $current->c, name => 'nevent record';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
    } $current->c, name => 'nevent_queue record';
  });
} n => 9, name => 'timestamp';

Test {
  my $current = shift;
  my $expires = time + rand 100000;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [c1 => nobj => {}],
    [u1 => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      data => {abv => 774},
      expires => $expires,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{timestamp};
      is $result->{json}->{expires}, $expires;
      is $result->{json}->{queued_count}, 1;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
    } $current->c, name => 'nevent record';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
    } $current->c, name => 'nevent_queue record';
  });
} n => 9, name => 'expires';

Test {
  my $current = shift;
  my $expires = time - rand 100000;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [c1 => nobj => {}],
    [u1 => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      data => {abv => 774},
      expires => $expires,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{timestamp};
      is $result->{json}->{expires}, $expires;
      is $result->{json}->{queued_count}, 1;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c, name => 'nevent record';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c, name => 'nevent_queue record';
  });
} n => 5, name => 'expired';

Test {
  my $current = shift;
  my $key = 'entry-'.rand.'-star';
  return $current->create (
    ['obj1-starred' => nobj => {}],
    [c1 => nobj => {}],
    [u1 => nobj => {}],
    [u2 => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 'obj1-starred', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
    [sub2 => topic_subscription => {
      topic => 'obj1-starred', channel => 'c1', subscriber => 'u2',
      status => 2, data => {foo => 12.5},
    }],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('obj1-starred')->{nobj_key},
      data => {abv => 774},
      nevent_key => $key,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{nevent_id};
      ok $result->{json}->{timestamp};
      ok $result->{json}->{timestamp} < $result->{json}->{expires};
      is $result->{json}->{queued_count}, 2;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('obj1-starred')->{nobj_key},
      data => {abv => 63.1},
      nevent_key => $key,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{nevent_id};
      ok $result->{json}->{timestamp};
      ok $result->{json}->{timestamp} < $result->{json}->{expires};
      is $result->{json}->{queued_count}, 2;
    } $current->c;
    $current->set_o (ev2 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('obj1-starred')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
    } $current->c, name => 'nevent record - u1';
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('obj1-starred')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u2')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
    } $current->c, name => 'nevent record - u2';
    return $current->create (
      [u3 => nobj => {}],
      [sub3 => topic_subscription => {
        topic => 'obj1-starred', channel => 'c1', subscriber => 'u3',
        status => 2, data => {foo => 563.1},
      }],
    );
  })->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('obj1-starred')->{nobj_key},
      data => {abv => 7.75},
      nevent_key => $key,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{nevent_id};
      ok $result->{json}->{timestamp};
      ok $result->{json}->{timestamp} < $result->{json}->{expires};
      is $result->{json}->{queued_count}, 3;
    } $current->c;
    $current->set_o (ev3 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{data}->{abv}, 774;
    } $current->c, name => 'nevent record - u1';
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{data}->{abv}, 774;
    } $current->c, name => 'nevent record - u2';
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u3')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev3')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev3')->{timestamp};
      is $ev1->{data}->{abv}, 7.75;
    } $current->c, name => 'nevent record - u3';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 3;
      
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{data}->{abv}, 774;
      is $ev1->{topic_subscription_data}->{foo}, 54;
      
      my $ev2 = $result->{json}->{items}->[1];
      is $ev2->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev2->{expires}, $current->o ('ev1')->{expires};
      is $ev2->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev2->{data}->{abv}, 774;
      is $ev2->{topic_subscription_data}->{foo}, 12.5;
      
      my $ev3 = $result->{json}->{items}->[2];
      is $ev3->{timestamp}, $current->o ('ev3')->{timestamp};
      is $ev3->{expires}, $current->o ('ev3')->{expires};
      is $ev3->{nevent_id}, $current->o ('ev3')->{nevent_id};
      is $ev3->{data}->{abv}, 7.75;
      is $ev3->{topic_subscription_data}->{foo}, 563.1;
    } $current->c, name => 'nevent_queue record';
  });
} n => 54, name => 'nevent_key (replace=0)';

Test {
  my $current = shift;
  my $key = 'entry-'.rand.'-star';
  return $current->create (
    ['obj1-starred' => nobj => {}],
    [c1 => nobj => {}],
    [u1 => nobj => {}],
    [u2 => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 'obj1-starred', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
    [sub2 => topic_subscription => {
      topic => 'obj1-starred', channel => 'c1', subscriber => 'u2',
      status => 2, data => {foo => 12.5},
    }],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('obj1-starred')->{nobj_key},
      data => {abv => 774},
      nevent_key => $key,
    });
  })->then (sub {
    my $result = $_[0];
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('obj1-starred')->{nobj_key},
      data => {abv => 63.1},
      nevent_key => $key,
      replace => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      isnt $result->{json}->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $result->{json}->{queued_count}, 2;
    } $current->c;
    $current->set_o (ev2 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev2')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev2')->{timestamp};
      is $ev1->{expires}, $current->o ('ev2')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('obj1-starred')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 63.1;
    } $current->c, name => 'nevent record - u1';
    return $current->create (
      [u3 => nobj => {}],
      [sub3 => topic_subscription => {
        topic => 'obj1-starred', channel => 'c1', subscriber => 'u3',
        status => 2, data => {foo => 563.1},
      }],
    );
  })->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('obj1-starred')->{nobj_key},
      data => {abv => 7.75},
      nevent_key => $key,
      replace => 1,
    });
  })->then (sub {
    my $result = $_[0];
    $current->set_o (ev3 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev3')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev3')->{timestamp};
      is $ev1->{data}->{abv}, 7.75;
    } $current->c, name => 'nevent record - u1';
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u3')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev3')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev3')->{timestamp};
      is $ev1->{data}->{abv}, 7.75;
    } $current->c, name => 'nevent record - u3';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 3;
      $result->{json}->{items} = [sort {
        $a->{topic_subscription_data}->{foo} <=> $b->{topic_subscription_data}->{foo};
      } @{$result->{json}->{items}}];
      
      my $ev2 = $result->{json}->{items}->[0];
      is $ev2->{timestamp}, $current->o ('ev3')->{timestamp};
      is $ev2->{expires}, $current->o ('ev3')->{expires};
      is $ev2->{nevent_id}, $current->o ('ev3')->{nevent_id};
      is $ev2->{data}->{abv}, 7.75;
      is $ev2->{topic_subscription_data}->{foo}, 12.5;
      
      my $ev1 = $result->{json}->{items}->[1];
      is $ev1->{timestamp}, $current->o ('ev3')->{timestamp};
      is $ev1->{expires}, $current->o ('ev3')->{expires};
      is $ev1->{nevent_id}, $current->o ('ev3')->{nevent_id};
      is $ev1->{data}->{abv}, 7.75;
      is $ev1->{topic_subscription_data}->{foo}, 54;
      
      my $ev3 = $result->{json}->{items}->[2];
      is $ev3->{timestamp}, $current->o ('ev3')->{timestamp};
      is $ev3->{expires}, $current->o ('ev3')->{expires};
      is $ev3->{nevent_id}, $current->o ('ev3')->{nevent_id};
      is $ev3->{data}->{abv}, 7.75;
      is $ev3->{topic_subscription_data}->{foo}, 563.1;
    } $current->c, name => 'nevent_queue record';
  });
} n => 33, name => 'nevent_key (replace=1)';

Test {
  my $current = shift;
  return $current->create (
    ['g1-followed' => nobj => {}],
    ['g1-notifications' => nobj => {}],
    [c1 => nobj => {}],
    [c2 => nobj => {}],
    [u1 => nobj => {}],
  )->then (sub {
    return $current->create (
      [sub1 => topic_subscription => {
        topic => 'g1-notifications',
        channel => 'c1', subscriber => 'u1',
        status => 4, # inherit
        data => {foo => 5632},
      }],
      [sub2 => topic_subscription => {
        topic_nobj_key => $current->o ('u1')->{nobj_key} . '-group-notifications',
        channel => 'c1', subscriber => 'u1',
        status => 2, data => {foo => 54},
      }],
      [sub3 => topic_subscription => {
        topic_nobj_key => $current->o ('u1')->{nobj_key} . '-group-notifications',
        channel => 'c2', subscriber => 'u1',
        status => 2, data => {foo => 561},
      }],
    );
  })->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('g1-followed')->{nobj_key},
      topic_fallback_nobj_key => [
        $current->o ('g1-notifications')->{nobj_key},
      ],
      topic_fallback_nobj_key_template => [
        '{subscriber}-group-followed',
        '{subscriber}-group-notifications',
      ],
      data => {abv => 774},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{nevent_id};
      ok $result->{json}->{timestamp};
      ok $result->{json}->{expires};
      is $result->{json}->{queued_count}, 1;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('g1-followed')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
    } $current->c, name => 'nevent record';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('g1-followed')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
      is $ev1->{topic_subscription_data}->{foo}, 54;
    } $current->c, name => 'nevent_queue record';
  });
} n => 19, name => 'topic_fallback_nobj_key_template';

Test {
  my $current = shift;
  return $current->create (
    ['g1-followed' => nobj => {}],
    ['g1-notifications' => nobj => {}],
    [c1 => nobj => {}],
    [c2 => nobj => {}],
    [u1 => nobj => {}],
  )->then (sub {
    return $current->create (
      [sub1 => topic_subscription => {
        topic => 'g1-notifications',
        channel_nobj_key => 'apploach-any-channel',
        subscriber => 'u1',
        status => 4, # inherit
        data => {foo => 5632},
      }],
      [sub2 => topic_subscription => {
        topic_nobj_key => $current->o ('u1')->{nobj_key} . '-group-notifications',
        channel => 'c1', subscriber => 'u1',
        status => 2, data => {foo => 54},
      }],
      [sub3 => topic_subscription => {
        topic_nobj_key => $current->o ('u1')->{nobj_key} . '-group-notifications',
        channel => 'c2', subscriber => 'u1',
        status => 2, data => {foo => 561},
      }],
    );
  })->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('g1-followed')->{nobj_key},
      topic_fallback_nobj_key => [
        $current->o ('g1-notifications')->{nobj_key},
      ],
      topic_fallback_nobj_key_template => [
        '{subscriber}-group-followed',
        '{subscriber}-group-notifications',
      ],
      data => {abv => 774},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{nevent_id};
      ok $result->{json}->{timestamp};
      ok $result->{json}->{expires};
      is $result->{json}->{queued_count}, 2;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('g1-followed')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
    } $current->c, name => 'nevent record';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('g1-followed')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
      is $ev1->{topic_subscription_data}->{foo}, 54;
    } $current->c, name => 'nevent_queue record 1';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('g1-followed')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
      is $ev1->{topic_subscription_data}->{foo}, 561;
    } $current->c, name => 'nevent_queue record 2';
  });
} n => 27, name => 'topic_fallback_nobj_key_template apploach-any-channel';

Test {
  my $current = shift;
  return $current->create (
    ['g1-followed' => nobj => {}],
    ['g1-notifications' => nobj => {}],
    [c1 => nobj => {}],
    [c2 => nobj => {}],
    [u1 => nobj => {}],
  )->then (sub {
    return $current->create (
      [sub1 => topic_subscription => {
        topic => 'g1-notifications',
        channel_nobj_key => 'apploach-any-channel',
        subscriber => 'u1',
        status => 4, # inherit
        data => {foo => 5632},
      }],
      [sub2 => topic_subscription => {
        topic_nobj_key => $current->o ('u1')->{nobj_key} . '-group-notifications',
        channel => 'c1', subscriber => 'u1',
        status => 2, data => {foo => 54},
      }],
      [sub3 => topic_subscription => {
        topic_nobj_key => $current->o ('u1')->{nobj_key} . '-group-notifications',
        channel => 'c2', subscriber => 'u1',
        status => 3, # disabled
        data => {foo => 561},
      }],
    );
  })->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('g1-followed')->{nobj_key},
      topic_fallback_nobj_key => [
        $current->o ('g1-notifications')->{nobj_key},
      ],
      topic_fallback_nobj_key_template => [
        '{subscriber}-group-followed',
        '{subscriber}-group-notifications',
      ],
      data => {abv => 774},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{nevent_id};
      ok $result->{json}->{timestamp};
      ok $result->{json}->{expires};
      is $result->{json}->{queued_count}, 1;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('g1-followed')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
    } $current->c, name => 'nevent record';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      is $ev1->{timestamp}, $current->o ('ev1')->{timestamp};
      is $ev1->{expires}, $current->o ('ev1')->{expires};
      is $ev1->{topic_nobj_key}, $current->o ('g1-followed')->{nobj_key};
      is $ev1->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $ev1->{data}->{abv}, 774;
      is $ev1->{topic_subscription_data}->{foo}, 54;
    } $current->c, name => 'nevent_queue record 1';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c, name => 'nevent_queue record 2';
  });
} n => 20, name => 'topic_fallback_nobj_key_template apploach-any-channel some disabled';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [c1 => nobj => {}],
    [u1 => nobj => {}],
    [u2 => nobj => {}],
    [u3 => nobj => {}],
    [u4 => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
    [sub2 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u2',
      status => 2, data => {foo => 112.5},
    }],
    [sub3 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u3',
      status => 3, # disabled
      data => {foo => 412.5},
    }],
    [sub4 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u4',
      status => 4, # inherit (disabled)
      data => {foo => 4},
    }],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      data => {abv => 774},
      excluded_subscriber_nobj_key => [$current->o ('u2')->{nobj_key},
                                       $current->o ('u4')->{nobj_key}],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{nevent_id};
      is $result->{json}->{queued_count}, 1;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
    } $current->c, name => 'nevent record - u1';
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c, name => 'nevent record - u2';
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u3')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c, name => 'nevent record - u3';
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u4')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c, name => 'nevent record - u4';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
    } $current->c, name => 'nevent_queue record';
  });
} n => 9, name => 'excluded_subscriber';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [c1 => nobj => {}],
    [u1 => nobj => {}],
    [u2 => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
    [sub2 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u2',
      status => 2, data => {foo => 112.5},
    }],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      data => {abv => 774},
      excluded_subscriber_nobj_key => [rand],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{nevent_id};
      is $result->{json}->{queued_count}, 2;
    } $current->c;
    $current->set_o (ev1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
    } $current->c, name => 'nevent record - u1';
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
    } $current->c, name => 'nevent record - u2';
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
    } $current->c, name => 'nevent_queue record';
  });
} n => 7, name => 'excluded_subscriber no exclusion';

RUN;

=head1 LICENSE

Copyright 2018-2019 Wakaba <wakaba@suikawiki.org>.

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
