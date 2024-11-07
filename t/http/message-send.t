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
  )->then (sub {
    return $current->json (['message', 'setroutes.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      operator_nobj_key => $current->o ('s10')->{nobj_key},
      verb_nobj_key => $current->o ('s11')->{nobj_key},
      channel => 'vonage',
      table => (perl2json_chars {
        $current->generate_text (t1 => {}) => {
          addr => $current->generate_message_addr (a1 => {}),
        },
      }),
    });
  })->then (sub {
    return $current->json (['message', 'send.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      to => $current->o ('t1'),
      from_name => $current->generate_key (t2 => {}),
      body => $current->generate_text (t3 => {}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s21')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{request_set_id};
      like $result->{res}->body_bytes, qr{"request_set_id":"};
      $current->set_o (rs1 => $result->{json});
    } $current->c;
    return $current->are_errors (
      [['message', 'send.json'], {
        station_nobj_key => $current->o ('s1')->{nobj_key},
        to => $current->o ('t1'),
        from_name => $current->o ('t2'),
        body => $current->o ('t3'),
        operator_nobj_key => $current->o ('s20')->{nobj_key},
        verb_nobj_key => $current->o ('s21')->{nobj_key},
        status_verb_nobj_key => $current->o ('s21')->{nobj_key},
      }],
      [
        ['get_nobj', 'station'],
        ['new_nobj', 'operator'],
        ['new_nobj', 'verb'],
        ['new_nobj', 'status_verb'],
        {p => {to => rand}, status => 400},
      ],
    );
  })->then (sub {
    return $current->wait_for_messages ($current->o ('a1'));
  })->then (sub {
    my $messages = $_[0];
    test {
      my $m = $messages->[0];
      if (defined $m->{api_key}) {
        ok $m->{api_key};
        ok $m->{api_secret};
      } else {
        ok $m->{jwt};
        ok 1;
      }
      is $m->{channel}, 'sms';
      ok $m->{client_ref};
      is $m->{to}, $current->o ('a1');
      is $m->{from}, $current->o ('t2');
      is $m->{text}, $current->o ('t3');
    } $current->c;
    return promised_wait_until {
      return $current->json (['message', 'status.json'], {
        request_set_id => $current->o ('rs1')->{request_set_id},
      })->then (sub {
        my $result = $_[0];
        return $result->{json}->{items}->[0]->{status_6_count};
      });
    } timeout => 127;
  })->then (sub {
    return $current->json (['message', 'status.json'], {
      request_set_id => $current->o ('rs1')->{request_set_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $item = $result->{json}->{items}->[0];
      ok $item->{updated};
      is $item->{status_2_count}, 0;
      is $item->{status_3_count}, 0;
      is $item->{status_4_count}, 0;
      is $item->{status_5_count}, 0;
      is $item->{status_6_count}, 1;
      is $item->{status_7_count}, 0;
      is $item->{status_8_count}, 0;
      is $item->{status_9_count}, 0;
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
      ok $v->{data}->{timestamp};
      ok $v->{data}->{expires} > $v->{data}->{timestamp};
      is $v->{data}->{channel}, 'vonage';
      is $v->{data}->{size_for_cost}, 1;
      like $result->{res}->body_bytes, qr{"request_set_id":"};
      is $v->{data}->{request_set_id}, $current->o ('rs1')->{request_set_id};
      is $v->{data}->{destination}->{count}, 1;
    } $current->c, name => 's & v';
  });
} n => 30, name => 'sent', timeout => 200;

Test {
  my $current = shift;
  return $current->create (
    [s1 => nobj => {}],
    [s10 => nobj => {}],
    [s11 => nobj => {}],
    [s20 => nobj => {}],
    [s21 => nobj => {}],
    [s22 => nobj => {}],
  )->then (sub {
    return $current->json (['message', 'setroutes.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      operator_nobj_key => $current->o ('s10')->{nobj_key},
      verb_nobj_key => $current->o ('s11')->{nobj_key},
      channel => 'vonage',
      table => (perl2json_chars {
        $current->generate_text (t1 => {}) => {
          addr => $current->generate_message_addr (a1 => {}),
        },
      }),
    });
  })->then (sub {
    return $current->json (['message', 'send.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      to => $current->o ('t1'),
      from_name => $current->generate_key (t2 => {}),
      body => $current->generate_key (t3 => {prefix => "RFAILURE,"}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s21')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{request_set_id};
      like $result->{res}->body_bytes, qr{"request_set_id":"};
      $current->set_o (rs1 => $result->{json});
    } $current->c;
    return promised_wait_until {
      return $current->json (['message', 'status.json'], {
        request_set_id => $current->o ('rs1')->{request_set_id},
      })->then (sub {
        my $result = $_[0];
        return $result->{json}->{items}->[0]->{status_5_count};
      });
    } timeout => 126;
  })->then (sub {
    return $current->json (['message', 'status.json'], {
      request_set_id => $current->o ('rs1')->{request_set_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $item = $result->{json}->{items}->[0];
      ok $item->{updated};
      is $item->{status_2_count}, 0;
      is $item->{status_3_count}, 0;
      is $item->{status_4_count}, 0;
      is $item->{status_5_count}, 1;
      is $item->{status_6_count}, 0;
      is $item->{status_7_count}, 0;
      is $item->{status_8_count}, 0;
      is $item->{status_9_count}, 0;
    } $current->c;
  });
} n => 11, name => 'response error (400)', timeout => 202;

Test {
  my $current = shift;
  return $current->create (
    [s1 => nobj => {}],
    [s10 => nobj => {}],
    [s11 => nobj => {}],
    [s20 => nobj => {}],
    [s21 => nobj => {}],
    [s22 => nobj => {}],
  )->then (sub {
    return $current->json (['message', 'setroutes.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      operator_nobj_key => $current->o ('s10')->{nobj_key},
      verb_nobj_key => $current->o ('s11')->{nobj_key},
      channel => 'vonage',
      table => (perl2json_chars {
        $current->generate_text (t1 => {}) => {
          addr => $current->generate_message_addr (a1 => {}),
        },
      }),
    });
  })->then (sub {
    return $current->json (['message', 'send.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      to => $current->o ('t1'),
      from_name => $current->generate_key (t2 => {}),
      body => $current->generate_key (t3 => {prefix => "R500,"}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s21')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{request_set_id};
      like $result->{res}->body_bytes, qr{"request_set_id":"};
      $current->set_o (rs1 => $result->{json});
    } $current->c;
    return promised_wait_until {
      return $current->json (['message', 'status.json'], {
        request_set_id => $current->o ('rs1')->{request_set_id},
      })->then (sub {
        my $result = $_[0];
        return $result->{json}->{items}->[0]->{status_5_count};
      });
    } timeout => 60*5;
  })->then (sub {
    return $current->json (['message', 'status.json'], {
      request_set_id => $current->o ('rs1')->{request_set_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $item = $result->{json}->{items}->[0];
      ok $item->{updated};
      is $item->{status_2_count}, 0;
      is $item->{status_3_count}, 0;
      is $item->{status_4_count}, 0;
      is $item->{status_5_count}, 1;
      is $item->{status_6_count}, 0;
      is $item->{status_7_count}, 0;
      is $item->{status_8_count}, 0;
      is $item->{status_9_count}, 0;
    } $current->c;
  });
} n => 11, name => 'response error (500)', timeout => 60*5;

Test {
  my $current = shift;
  return $current->create (
    [s1 => nobj => {}],
    [s10 => nobj => {}],
    [s11 => nobj => {}],
    [s20 => nobj => {}],
    [s21 => nobj => {}],
    [s22 => nobj => {}],
  )->then (sub {
    return $current->json (['message', 'setroutes.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      operator_nobj_key => $current->o ('s10')->{nobj_key},
      verb_nobj_key => $current->o ('s11')->{nobj_key},
      channel => 'vonage',
      table => (perl2json_chars {
        $current->generate_text (t1 => {}) => {
          addr => $current->generate_message_addr (a1 => {}),
          cc_addrs => [
            $current->generate_message_addr (a2 => {}),
            $current->generate_message_addr (a3 => {}),
            $current->generate_message_addr (a4 => {}),
          ],
        },
      }),
    });
  })->then (sub {
    return $current->json (['message', 'send.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      to => $current->o ('t1'),
      from_name => $current->generate_key (t2 => {}),
      body => $current->generate_text (t3 => {}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s21')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{request_set_id};
      like $result->{res}->body_bytes, qr{"request_set_id":"};
      $current->set_o (rs1 => $result->{json});
    } $current->c;
  })->then (sub {
    return $current->wait_for_messages ($current->o ('a1'));
  })->then (sub {
    my $messages = $_[0];
    test {
      my $m = $messages->[0];
      if (defined $m->{api_key}) {
        ok $m->{api_key};
        ok $m->{api_secret};
      } else {
        ok $m->{jwt};
        ok 1;
      }
      is $m->{channel}, 'sms';
      ok $m->{client_ref};
      is $m->{to}, $current->o ('a1');
      is $m->{from}, $current->o ('t2');
      is $m->{text}, $current->o ('t3');
    } $current->c;
    return $current->wait_for_messages ($current->o ('a2'));
  })->then (sub {
    my $messages = $_[0];
    test {
      my $m = $messages->[0];
      if (defined $m->{api_key}) {
        ok $m->{api_key};
        ok $m->{api_secret};
      } else {
        ok $m->{jwt};
        ok 1;
      }
      is $m->{channel}, 'sms';
      ok $m->{client_ref};
      is $m->{to}, $current->o ('a2');
      is $m->{from}, $current->o ('t2');
      is $m->{text}, $current->o ('t3');
    } $current->c;
    return $current->wait_for_messages ($current->o ('a3'));
  })->then (sub {
    my $messages = $_[0];
    test {
      my $m = $messages->[0];
      if (defined $m->{api_key}) {
        ok $m->{api_key};
        ok $m->{api_secret};
      } else {
        ok $m->{jwt};
        ok 1;
      }
      is $m->{channel}, 'sms';
      ok $m->{client_ref};
      is $m->{to}, $current->o ('a3');
      is $m->{from}, $current->o ('t2');
      is $m->{text}, $current->o ('t3');
    } $current->c;
    return $current->wait_for_messages ($current->o ('a4'));
  })->then (sub {
    my $messages = $_[0];
    test {
      my $m = $messages->[0];
      if (defined $m->{api_key}) {
        ok $m->{api_key};
        ok $m->{api_secret};
      } else {
        ok $m->{jwt};
        ok 1;
      }
      is $m->{channel}, 'sms';
      ok $m->{client_ref};
      is $m->{to}, $current->o ('a4');
      is $m->{from}, $current->o ('t2');
      is $m->{text}, $current->o ('t3');
    } $current->c;
    return promised_wait_until {
      return $current->json (['message', 'status.json'], {
        request_set_id => $current->o ('rs1')->{request_set_id},
      })->then (sub {
        my $result = $_[0];
        return $result->{json}->{items}->[0]->{status_6_count} >= 4;
      });
    } timeout => 124;
  })->then (sub {
    return $current->json (['message', 'status.json'], {
      request_set_id => $current->o ('rs1')->{request_set_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $item = $result->{json}->{items}->[0];
      ok $item->{updated};
      is $item->{status_2_count}, 0;
      is $item->{status_3_count}, 0;
      is $item->{status_4_count}, 0;
      is $item->{status_5_count}, 0;
      is $item->{status_6_count}, 4;
      is $item->{status_7_count}, 0;
      is $item->{status_8_count}, 0;
      is $item->{status_9_count}, 0;
      is $item->{data}->{channel}, 'vonage';
      is $item->{data}->{destination}->{to}, $current->o ('t1');
      is $item->{data}->{destination}->{count}, 4;
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
      ok $v->{data}->{timestamp};
      ok $v->{data}->{expires} > $v->{data}->{timestamp};
      is $v->{data}->{channel}, 'vonage';
      is $v->{data}->{size_for_cost}, 1;
      like $result->{res}->body_bytes, qr{"request_set_id":"};
      is $v->{data}->{request_set_id}, $current->o ('rs1')->{request_set_id};
      is $v->{data}->{destination}->{to}, $current->o ('t1');
      is $v->{data}->{destination}->{count}, 4;
    } $current->c, name => 's & v';
  });
} n => 54, name => 'cc', timeout => 201;

Test {
  my $current = shift;
  return $current->create (
    [s1 => nobj => {}],
    [s10 => nobj => {}],
    [s11 => nobj => {}],
    [s20 => nobj => {}],
    [s21 => nobj => {}],
    [s22 => nobj => {}],
  )->then (sub {
    return $current->json (['message', 'setroutes.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      operator_nobj_key => $current->o ('s10')->{nobj_key},
      verb_nobj_key => $current->o ('s11')->{nobj_key},
      channel => 'vonage',
      table => (perl2json_chars {
        $current->generate_text (t1 => {}) => {
          addr => $current->generate_message_addr (a1 => {}),
          cc_addrs => [
            $current->generate_message_addr (a2 => {}),
            $current->generate_message_addr (a3 => {}),
            $current->generate_message_addr (a4 => {}),
          ],
        },
      }),
    });
  })->then (sub {
    return $current->json (['message', 'send.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      to => $current->o ('t1'),
      from_name => $current->generate_key (t20 => {}),
      body => $current->generate_text (t30 => {}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s21')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
      addr_key => rand, # no match
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{request_set_id};
      like $result->{res}->body_bytes, qr{"request_set_id":"};
      $current->set_o (rs0 => $result->{json});
    } $current->c;
    return $current->json (['message', 'send.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      to => $current->o ('t1'),
      from_name => $current->generate_key (t2 => {}),
      body => $current->generate_text (t3 => {}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s21')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
      addr_key => sha1_hex (encode_web_utf8 ($current->o ('a4'))),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{request_set_id};
      like $result->{res}->body_bytes, qr{"request_set_id":"};
      $current->set_o (rs1 => $result->{json});
    } $current->c;
    return $current->wait_for_messages ($current->o ('a4'));
  })->then (sub {
    my $messages = $_[0];
    test {
      my $m = $messages->[0];
      if (defined $m->{api_key}) {
        ok $m->{api_key};
        ok $m->{api_secret};
      } else {
        ok $m->{jwt};
        ok 1;
      }
      is $m->{channel}, 'sms';
      ok $m->{client_ref};
      is $m->{to}, $current->o ('a4');
      is $m->{from}, $current->o ('t2');
      is $m->{text}, $current->o ('t3');
    } $current->c;
    return promised_wait_until {
      return $current->json (['message', 'status.json'], {
        request_set_id => $current->o ('rs1')->{request_set_id},
      })->then (sub {
        my $result = $_[0];
        return $result->{json}->{items}->[0]->{status_6_count} >= 1;
      });
    } timeout => 323;
  })->then (sub {
    return $current->json (['message', 'status.json'], {
      request_set_id => $current->o ('rs1')->{request_set_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $item = $result->{json}->{items}->[0];
      ok $item->{updated};
      is $item->{status_2_count}, 0;
      is $item->{status_3_count}, 0;
      is $item->{status_4_count}, 0;
      is $item->{status_5_count}, 0;
      is $item->{status_6_count}, 1;
      is $item->{status_7_count}, 0;
      is $item->{status_8_count}, 0;
      is $item->{status_9_count}, 0;
      is $item->{data}->{channel}, 'vonage';
      is $item->{data}->{destination}->{to}, $current->o ('t1');
      is $item->{data}->{destination}->{count}, 1;
    } $current->c;
    return $current->json (['nobj', 'logs.json'], {
      verb_nobj_key => $current->o ('s21')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      {
        my $v = $result->{json}->{items}->[1];
        is $v->{operator_nobj_key}, $current->o ('s20')->{nobj_key};
        is $v->{target_nobj_key}, $current->o ('s1')->{nobj_key};
        is $v->{verb_nobj_key}, $current->o ('s21')->{nobj_key};
        ok $v->{data}->{timestamp};
        ok $v->{data}->{expires} > $v->{data}->{timestamp};
        is $v->{data}->{channel}, 'vonage';
        is $v->{data}->{size_for_cost}, 1;
        like $result->{res}->body_bytes, qr{"request_set_id":"};
        is $v->{data}->{request_set_id}, $current->o ('rs0')->{request_set_id};
        is $v->{data}->{destination}->{to}, $current->o ('t1');
        is $v->{data}->{destination}->{count}, 0;
      }
      {
        my $v = $result->{json}->{items}->[0];
        is $v->{operator_nobj_key}, $current->o ('s20')->{nobj_key};
        is $v->{target_nobj_key}, $current->o ('s1')->{nobj_key};
        is $v->{verb_nobj_key}, $current->o ('s21')->{nobj_key};
        ok $v->{data}->{timestamp};
        ok $v->{data}->{expires} > $v->{data}->{timestamp};
        is $v->{data}->{channel}, 'vonage';
        is $v->{data}->{size_for_cost}, 1;
        like $result->{res}->body_bytes, qr{"request_set_id":"};
        is $v->{data}->{request_set_id}, $current->o ('rs1')->{request_set_id};
        is $v->{data}->{destination}->{to}, $current->o ('t1');
        is $v->{data}->{destination}->{count}, 1;
      }
    } $current->c, name => 's & v';
    return $current->get_message_count ($current->o ('a1'));
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 0;
    } $current->c;
    return $current->get_message_count ($current->o ('a2'));
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 0;
    } $current->c;
    return $current->get_message_count ($current->o ('a3'));
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 0;
    } $current->c;
  });
} n => 49, name => 'addr_key', timeout => 403;

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
