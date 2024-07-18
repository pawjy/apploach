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
    my $result = $_[0];
    test {
      ok $result->{json}->{expires} > time + 24*60*60;
    } $current->c;
    return $current->are_errors (
      [['message', 'setroutes.json'], {
        station_nobj_key => $current->o ('s1')->{nobj_key},
        operator_nobj_key => $current->o ('s10')->{nobj_key},
        verb_nobj_key => $current->o ('s11')->{nobj_key},
        channel => 'vonage',
        table => (perl2json_chars {
          $current->o ('t1') => {
            addr => $current->o ('a1'),
          },
        }),
      }],
      [
        ['new_nobj', 'station'],
        ['new_nobj', 'operator'],
        ['new_nobj', 'verb'],
        ['json', 'table'],
        {p => {channel => rand}, status => 400},
        {p => {table => (perl2json_chars [])}, status => 400},
        {p => {table => (perl2json_chars [{
          hoge => rand,
        }])}, status => 400},
        {p => {table => (perl2json_chars [{
          hoge => [],
        }])}, status => 400},
        {p => {table => (perl2json_chars [{
          hoge => undef,
        }])}, status => 400},
        {p => {table => (perl2json_chars [{
          hoge => {cc_addrs => rand},
        }])}, status => 400},
        {p => {table => (perl2json_chars [{
          hoge => {cc_addrs => {}},
        }])}, status => 400},
        {p => {table => (perl2json_chars [{
          hoge => {cc_addrs => ["a", "b", undef]},
        }])}, status => 400},
      ],
    );
  })->then (sub {
    return $current->json (['message', 'send.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      to => $current->o ('t1'),
      from_name => $current->generate_key (t2 => {}),
      body => $current->generate_key (t3 => {}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s21')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{request_set_id};
      like $result->{res}->body_bytes, qr{"request_set_id":"};
    } $current->c;
    return $current->wait_for_messages ($current->o ('a1'));
  })->then (sub {
    my $messages = $_[0];
    test {
      my $m = $messages->[0];
      is $m->{to}, $current->o ('a1');
      is $m->{from}, $current->o ('t2');
      is $m->{text}, $current->o ('t3');
    } $current->c;
  });
} n => 7, name => 'sent';

Test {
  my $current = shift;
  return $current->create (
    [s1 => nobj => {}],
    [s10 => nobj => {}],
    [s11 => nobj => {}],
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
      expires => $current->generate_time (time1 => {future => 1}),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{expires}, $current->o ('time1');
    } $current->c;
  });
} n => 1, name => 'expires specified';

Test {
  my $current = shift;
  return $current->create (
    [s1 => nobj => {}],
    [s10 => nobj => {}],
    [s11 => nobj => {}],
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
      expires => $current->generate_time (time1 => {past => 1}),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{expires} > time + 24*60*60;
    } $current->c;
    return $current->json (['nobj', 'logs.json'], {
      verb_nobj_key => $current->o ('s11')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{operator_nobj_key}, $current->o ('s10')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('s1')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('s11')->{nobj_key};
      ok $v->{data}->{timestamp};
      ok $v->{data}->{expires} > $v->{data}->{timestamp};
      is $v->{data}->{channel}, 'vonage';
      is 0+keys %{$v->{data}->{table_summary}}, 1;
      is 0+keys %{$v->{data}->{table_summary}->{$current->o ('t1')}}, 2;
      ok $v->{data}->{table_summary}->{$current->o ('t1')}->{has_addr};
    } $current->c, name => 's & v';
  });
} n => 11, name => 'past expires specified';

Test {
  my $current = shift;
  return $current->create (
    [s1 => nobj => {}],
    [s10 => nobj => {}],
    [s11 => nobj => {}],
    [s20 => nobj => {}],
    [s21 => nobj => {}],
    [s22 => nobj => {}],
    [s32 => nobj => {}],
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
    return $current->json (['message', 'setroutes.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      operator_nobj_key => $current->o ('s10')->{nobj_key},
      verb_nobj_key => $current->o ('s32')->{nobj_key},
      channel => 'vonage',
      table => (perl2json_chars {
        $current->o ('t1') => {
          addr => $current->generate_message_addr (a2 => {}),
        },
      }),
      expires => $current->generate_time (time2 => {future => 1}),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{expires}, $current->o ('time2');
    } $current->c;
    return $current->json (['message', 'send.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      to => $current->o ('t1'),
      from_name => $current->generate_key (t2 => {}),
      body => $current->generate_key (t3 => {}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s22')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
    });
  })->then (sub {
    return $current->wait_for_messages ($current->o ('a2'));
  })->then (sub {
    my $messages = $_[0];
    test {
      my $m = $messages->[0];
      is $m->{to}, $current->o ('a2');
    } $current->c;
    return $current->json (['nobj', 'logs.json'], {
      verb_nobj_key => $current->o ('s32')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{operator_nobj_key}, $current->o ('s10')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('s1')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('s32')->{nobj_key};
      ok $v->{data}->{timestamp};
      is $v->{data}->{expires}, $current->o ('time2');
      is $v->{data}->{channel}, 'vonage';
      is 0+keys %{$v->{data}->{table_summary}}, 1;
      is 0+keys %{$v->{data}->{table_summary}->{$current->o ('t1')}}, 2;
      ok $v->{data}->{table_summary}->{$current->o ('t1')}->{has_addr};
      is $v->{data}->{table_summary}->{$current->o ('t1')}->{cc_addr_count}, 0;
    } $current->c, name => 's & v';
  });
} n => 13, name => 'table changed';

Test {
  my $current = shift;
  return $current->create (
    [s1 => nobj => {}],
    [s10 => nobj => {}],
    [s11 => nobj => {}],
    [s20 => nobj => {}],
    [s21 => nobj => {}],
    [s22 => nobj => {}],
    [s32 => nobj => {}],
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
    return $current->json (['message', 'setroutes.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      operator_nobj_key => $current->o ('s10')->{nobj_key},
      verb_nobj_key => $current->o ('s32')->{nobj_key},
      channel => 'vonage',
      no_new_table => 1,
      expires => $current->generate_time (time2 => {future => 1}),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{expires}, $current->o ('time2');
    } $current->c;
    return $current->are_errors (
      [['message', 'setroutes.json'], {
        station_nobj_key => $current->o ('s1')->{nobj_key},
        operator_nobj_key => $current->o ('s10')->{nobj_key},
        verb_nobj_key => $current->o ('s32')->{nobj_key},
        channel => 'vonage',
        no_new_table => 1,
        table => (perl2json_chars {}),
        expires => $current->generate_time (time3 => {future => 1}),
      }],
      [
        {status => 400},
      ],
    );
  })->then (sub {
    return $current->json (['message', 'send.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      to => $current->o ('t1'),
      from_name => $current->generate_key (t2 => {}),
      body => $current->generate_key (t3 => {}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s22')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
    });
  })->then (sub {
    return $current->wait_for_messages ($current->o ('a1'));
  })->then (sub {
    my $messages = $_[0];
    test {
      my $m = $messages->[0];
      is $m->{to}, $current->o ('a1');
    } $current->c;
    return $current->json (['nobj', 'logs.json'], {
      verb_nobj_key => $current->o ('s32')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{operator_nobj_key}, $current->o ('s10')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('s1')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('s32')->{nobj_key};
      ok $v->{data}->{timestamp};
      is $v->{data}->{expires}, $current->o ('time2');
      is $v->{data}->{channel}, 'vonage';
      is $v->{data}->{table_summary}, undef;
    } $current->c, name => 's & v';
  });
} n => 11, name => 'table non-changed';

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
