use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [s1 => nobj => {}],
    [s10 => nobj => {}],
    [s11 => nobj => {}],
    [s20 => nobj => {}],
    [s21 => nobj => {}],
    [s22 => nobj => {}],
    [t1 => nobj => {}],
  )->then (sub {
    return $current->json (['message', 'setroutes.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      operator_nobj_key => $current->o ('s10')->{nobj_key},
      verb_nobj_key => $current->o ('s11')->{nobj_key},
      channel => 'vonage',
      table => (perl2json_chars {
        $current->generate_text (to1 => {}) => {
          addr => $current->generate_message_addr (a1 => {}),
        },
      }),
    });
  })->then (sub {
    return $current->json (['notification', 'topic', 'subscribe.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      topic_index_nobj_key => 'null',
      channel_nobj_key => 'apploach-messages',
      subscriber_nobj_key => 'apploach-messages',
      data => {foo => 3},
      status => 2, # enabled
    });
  })->then (sub {
    return $current->json (['notification', 'topic', 'subscribe.json'], {
      topic_nobj_key => $current->o ('s1')->{nobj_key} . '-messages-vonage',
      topic_index_nobj_key => 'null',
      channel_nobj_key => 'vonage',
      subscriber_nobj_key => 'apploach-messages-routes',
      data => {foo => 2},
      status => 2, # enabled
    });
  })->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      data => {abv => 774},
      messages_station_nobj_key => $current->o ('s1')->{nobj_key},
      messages_to => $current->o ('to1'),
    });
  })->then (sub {
    return promised_wait_until {
      return $current->json (['notification', 'nevent', 'lockqueued.json'], {
        channel_nobj_key => 'vonage',
      })->then (sub {
        my $result = $_[0];
        return not 'done' unless @{$result->{json}->{items}};
        $current->set_o (items => $result->{json}->{items});
        return 'done';
      });
    };
  })->then (sub {
    my $items = $current->o ('items');
    test {
      is 0+@$items, 1;
      {
        my $item = $items->[0];
        is $item->{subscriber_nobj_key}, 'apploach-messages-routes';
        is $item->{topic_subscription_data}->{foo}, 2;
        ok $item->{data}->{addr_key};
        is $item->{data}->{channel}, 'vonage';
        is $item->{data}->{data}->{apploach_messages_station_nobj_key}, $current->o ('s1')->{nobj_key};
        is $item->{data}->{data}->{apploach_messages_to}, $current->o ('to1');
        is $item->{data}->{data}->{apploach_messages_space_nobj_key}, undef;
        is $item->{data}->{data}->{abv}, 774;
        is $item->{data}->{shorten_key}, undef;
      }
    } $current->c;
    return $current->json (['message', 'send.json'], {
      from_name => $current->generate_key (t2 => {}),
      body => $current->generate_text (t3 => {}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s21')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
      station_nobj_key => $items->[0]->{data}->{data}->{apploach_messages_station_nobj_key},
      to => $items->[0]->{data}->{data}->{apploach_messages_to},
      addr_key => $items->[0]->{data}->{addr_key},
    });
  })->then (sub {
    return $current->wait_for_messages ($current->o ('a1'));
  })->then (sub {
    my $messages = $_[0];
    test {
      my $m = $messages->[0];
      is $m->{channel}, 'sms';
      ok $m->{client_ref};
      is $m->{to}, $current->o ('a1');
      is $m->{from}, $current->o ('t2');
      is $m->{text}, $current->o ('t3');
    } $current->c;
    return $current->json (['nobj', 'logs.json'], {
      verb_nobj_key => $current->o ('s21')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{operator_nobj_key}, $current->o ('s20')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('s1')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('s21')->{nobj_key};
      is $v->{data}->{channel}, 'vonage';
    } $current->c, name => 's & v';
  });
} n => 20, name => 'sent', timeout => 200;

Test {
  my $current = shift;
  return $current->create (
    [s1 => nobj => {}],
    [s10 => nobj => {}],
    [s11 => nobj => {}],
    [s20 => nobj => {}],
    [s21 => nobj => {}],
    [s22 => nobj => {}],
    [t1 => nobj => {}],
  )->then (sub {
    return $current->json (['message', 'setroutes.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      operator_nobj_key => $current->o ('s10')->{nobj_key},
      verb_nobj_key => $current->o ('s11')->{nobj_key},
      channel => 'vonage',
      table => (perl2json_chars {
        $current->generate_text (to1 => {}) => {
          addr => $current->generate_message_addr (a2 => {}),
          cc_addrs => [$current->generate_message_addr (a1 => {})],
        },
      }),
    });
  })->then (sub {
    return $current->json (['notification', 'topic', 'subscribe.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      topic_index_nobj_key => 'null',
      channel_nobj_key => 'apploach-messages',
      subscriber_nobj_key => 'apploach-messages',
      data => {foo => 3},
      status => 2, # enabled
    });
  })->then (sub {
    return $current->json (['notification', 'topic', 'subscribe.json'], {
      topic_nobj_key => $current->o ('s1')->{nobj_key} . '-messages-vonage',
      topic_index_nobj_key => 'null',
      channel_nobj_key => 'vonage',
      subscriber_nobj_key => 'apploach-messages-routes',
      data => {foo => 2},
      status => 2, # enabled
    });
  })->then (sub {
    return $current->json (['notification', 'topic', 'subscribe.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key} . '-messages-vonage-' . sha1_hex (encode_web_utf8 ($current->o ('a2'))),
      topic_index_nobj_key => 'null',
      channel_nobj_key => 'vonage',
      subscriber_nobj_key => 'apploach-messages-routes',
      data => {foo => 4},
      status => 3, # disabled
    });
  })->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      data => {abv => 774},
      messages_station_nobj_key => $current->o ('s1')->{nobj_key},
      messages_to => $current->o ('to1'),
    });
  })->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      data => {abv => 775},
      messages_station_nobj_key => $current->o ('s1')->{nobj_key},
      messages_to => $current->generate_text (to2 => {}),
    });
  })->then (sub {
    return promised_wait_until {
      return $current->json (['notification', 'nevent', 'lockqueued.json'], {
        channel_nobj_key => 'vonage',
      })->then (sub {
        my $result = $_[0];
        return not 'done' unless @{$result->{json}->{items}};
        $current->set_o (items => $result->{json}->{items});
        return 'done';
      });
    };
  })->then (sub {
    my $items = $current->o ('items');
    test {
      is 0+@$items, 1;
      {
        my $item = $items->[0];
        is $item->{subscriber_nobj_key}, 'apploach-messages-routes';
        is $item->{topic_subscription_data}->{foo}, 2;
        ok $item->{data}->{addr_key};
        is $item->{data}->{channel}, 'vonage';
        is $item->{data}->{data}->{apploach_messages_station_nobj_key}, $current->o ('s1')->{nobj_key};
        is $item->{data}->{data}->{apploach_messages_to}, $current->o ('to1');
        is $item->{data}->{data}->{abv}, 774;
      }
    } $current->c;
    return $current->json (['message', 'send.json'], {
      from_name => $current->generate_key (t2 => {}),
      body => $current->generate_text (t3 => {}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s21')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
      station_nobj_key => $items->[0]->{data}->{data}->{apploach_messages_station_nobj_key},
      to => $items->[0]->{data}->{data}->{apploach_messages_to},
      addr_key => $items->[0]->{data}->{addr_key},
    });
  })->then (sub {
    return $current->wait_for_messages ($current->o ('a1'));
  })->then (sub {
    my $messages = $_[0];
    test {
      my $m = $messages->[0];
      is $m->{channel}, 'sms';
      ok $m->{client_ref};
      is $m->{to}, $current->o ('a1');
      is $m->{from}, $current->o ('t2');
      is $m->{text}, $current->o ('t3');
    } $current->c;
    return $current->json (['nobj', 'logs.json'], {
      verb_nobj_key => $current->o ('s21')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{operator_nobj_key}, $current->o ('s20')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('s1')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('s21')->{nobj_key};
      is $v->{data}->{channel}, 'vonage';
    } $current->c, name => 's & v';
    return $current->get_message_count ($current->o ('a2'));
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 0;
    } $current->c;
  });
} n => 19, name => 'sent and not sent', timeout => 200;

Test {
  my $current = shift;
  return $current->create (
    [s1 => nobj => {}],
    [s10 => nobj => {}],
    [s11 => nobj => {}],
    [s20 => nobj => {}],
    [s21 => nobj => {}],
    [s22 => nobj => {}],
    [t1 => nobj => {}],
    [sh1 => nobj => {}],
  )->then (sub {
    return $current->json (['message', 'setroutes.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      operator_nobj_key => $current->o ('s10')->{nobj_key},
      verb_nobj_key => $current->o ('s11')->{nobj_key},
      channel => 'vonage',
      table => (perl2json_chars {
        $current->generate_text (to1 => {}) => {
          addr => $current->generate_message_addr (a1 => {}),
        },
      }),
    });
  })->then (sub {
    return $current->json (['notification', 'topic', 'subscribe.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      topic_index_nobj_key => 'null',
      channel_nobj_key => 'apploach-messages',
      subscriber_nobj_key => 'apploach-messages',
      data => {foo => 3},
      status => 2, # enabled
    });
  })->then (sub {
    return $current->json (['notification', 'topic', 'subscribe.json'], {
      topic_nobj_key => $current->o ('s1')->{nobj_key} . '-messages-vonage',
      topic_index_nobj_key => 'null',
      channel_nobj_key => 'vonage',
      subscriber_nobj_key => 'apploach-messages-routes',
      data => {foo => 2},
      status => 2, # enabled
    });
  })->then (sub {
    return $current->json (['notification', 'nevent', 'fire.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      data => {abv => 774},
      messages_station_nobj_key => $current->o ('s1')->{nobj_key},
      messages_to => $current->o ('to1'),
      messages_space_nobj_key => $current->o ('sh1')->{nobj_key},
    });
  })->then (sub {
    return promised_wait_until {
      return $current->json (['notification', 'nevent', 'lockqueued.json'], {
        channel_nobj_key => 'vonage',
      })->then (sub {
        my $result = $_[0];
        return not 'done' unless @{$result->{json}->{items}};
        $current->set_o (items => $result->{json}->{items});
        return 'done';
      });
    };
  })->then (sub {
    my $items = $current->o ('items');
    test {
      is 0+@$items, 1;
      {
        my $item = $items->[0];
        is $item->{subscriber_nobj_key}, 'apploach-messages-routes';
        is $item->{topic_subscription_data}->{foo}, 2;
        ok $item->{data}->{addr_key};
        is $item->{data}->{channel}, 'vonage';
        is $item->{data}->{data}->{apploach_messages_station_nobj_key}, $current->o ('s1')->{nobj_key};
        is $item->{data}->{data}->{apploach_messages_space_nobj_key}, $current->o ('sh1')->{nobj_key};
        is $item->{data}->{data}->{apploach_messages_to}, $current->o ('to1');
        is $item->{data}->{data}->{abv}, 774;
        ok $item->{data}->{shorten_key};
      }
    } $current->c;
    return $current->json (['message', 'send.json'], {
      from_name => $current->generate_key (t2 => {}),
      body => $current->generate_text (t3 => {}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s21')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
      station_nobj_key => $items->[0]->{data}->{data}->{apploach_messages_station_nobj_key},
      to => $items->[0]->{data}->{data}->{apploach_messages_to},
      addr_key => $items->[0]->{data}->{addr_key},
    });
  })->then (sub {
    return $current->wait_for_messages ($current->o ('a1'));
  })->then (sub {
    my $messages = $_[0];
    test {
      my $m = $messages->[0];
      is $m->{channel}, 'sms';
      ok $m->{client_ref};
      is $m->{to}, $current->o ('a1');
      is $m->{from}, $current->o ('t2');
      is $m->{text}, $current->o ('t3');
    } $current->c;
    return $current->json (['nobj', 'logs.json'], {
      verb_nobj_key => $current->o ('s21')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{operator_nobj_key}, $current->o ('s20')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('s1')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('s21')->{nobj_key};
      is $v->{data}->{channel}, 'vonage';
    } $current->c, name => 's & v';
    return $current->json (['shorten', 'get.json'], {
      space_nobj_key => $current->o ('sh1')->{nobj_key},
      key => $current->o ('items')->[0]->{data}->{shorten_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{created};
      my $data = $result->{json}->{data};
      is $data->{addr_key}, $current->o ('items')->[0]->{data}->{addr_key};
      is $data->{data}->{abv}, 774;
    } $current->c;
  });
} n => 23, name => 'shorten', timeout => 200;

RUN;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

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
