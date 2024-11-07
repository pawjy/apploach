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
    return promised_wait_until {
      return $current->json (['message', 'status.json'], {
        request_set_id => $current->o ('rs1')->{request_set_id},
      })->then (sub {
        my $result = $_[0];
        return $result->{json}->{items}->[0]->{status_6_count};
      });
    } timeout => 320;
  })->then (sub {
    return $current->json (['message', 'status.json'], {
      request_set_id => $current->o ('rs1')->{request_set_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
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
      is $item->{request_set_id}, $current->o ('rs1')->{request_set_id};
      is $item->{size_for_cost}, 1;
      like $result->{res}->body_bytes, qr{"request_set_id":"};
    } $current->c;
    return $current->are_errors (
      [['message', 'status.json'], {
        request_set_id => $current->o ('rs1')->{request_set_id},
      }],
      [
        {params => {}, status => 400},
        {params => {station_nobj_key => rand}, status => 400},
      ],
    );
  })->then (sub {
    return $current->json (['message', 'status.json'], {
      request_set_id => 125155344,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c;
  });
} n => 17, name => 'success', timeout => 421;

Test {
  my $current = shift;
  return $current->create (
    [s1 => nobj => {}],
    [s2 => nobj => {}],
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
      body => $current->generate_text (t3 => {prefix => "CFAILURE"}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s21')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{request_set_id};
      $current->set_o (rs1 => $result->{json});
    } $current->c;
    return promised_wait_until {
      return $current->json (['message', 'status.json'], {
        request_set_id => $current->o ('rs1')->{request_set_id},
      })->then (sub {
        my $result = $_[0];
        return $result->{json}->{items}->[0]->{status_7_count};
      });
    } timeout => 106;
  })->then (sub {
    return $current->json (['message', 'status.json'], {
      request_set_id => $current->o ('rs1')->{request_set_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $item = $result->{json}->{items}->[0];
      ok $item->{updated};
      is $item->{status_2_count}, 0;
      is $item->{status_3_count}, 0;
      is $item->{status_4_count}, 0;
      is $item->{status_5_count}, 0;
      is $item->{status_6_count}, 0;
      is $item->{status_7_count}, 1;
      is $item->{status_8_count}, 0;
      is $item->{status_9_count}, 0;
    } $current->c;
    return $current->json (['message', 'setroutes.json'], {
      station_nobj_key => $current->o ('s2')->{nobj_key},
      channel => 'vonage',
      table => (perl2json_chars {
      }),
      operator_nobj_key => $current->o ('s10')->{nobj_key},
      verb_nobj_key => $current->o ('s11')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['message', 'status.json'], {
      station_nobj_key => $current->o ('s2')->{nobj_key},
      request_set_id => $current->o ('rs1')->{request_set_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c;
  });
} n => 12, name => 'callback reports failure';

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
      body => $current->generate_key (t3 => {prefix => "RFAILURE"}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s21')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{request_set_id};
      $current->set_o (rs1 => $result->{json});
    } $current->c;
    return promised_wait_until {
      return $current->json (['message', 'status.json'], {
        request_set_id => $current->o ('rs1')->{request_set_id},
      })->then (sub {
        my $result = $_[0];
        return $result->{json}->{items}->[0]->{status_5_count};
      });
    } timeout => 101;
  })->then (sub {
    return $current->json (['message', 'status.json'], {
      request_set_id => $current->o ('rs1')->{request_set_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
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
} n => 11, name => 'response failure';

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
        $current->generate_text (to2 => {}) => {
          addr => $current->generate_message_addr (a2 => {}),
        },
      }),
    });
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
    $current->set_o (rs1 => $result->{json});
    return $current->json (['message', 'send.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      to => $current->o ('to2'),
      from_name => $current->generate_key (t4 => {}),
      body => $current->generate_key (t5 => {}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s21')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    $current->set_o (rs2 => $result->{json});
    return promised_wait_until {
      return $current->json (['message', 'status.json'], {
        request_set_id => $current->o ('rs1')->{request_set_id},
      })->then (sub {
        my $result = $_[0];
        return $result->{json}->{items}->[0]->{status_6_count};
      });
    } timeout => 326;
  })->then (sub {
    return promised_wait_until {
      return $current->json (['message', 'status.json'], {
        request_set_id => $current->o ('rs2')->{request_set_id},
      })->then (sub {
        my $result = $_[0];
        return $result->{json}->{items}->[0]->{status_6_count};
      });
    } timeout => 325;
  })->then (sub {
    return $current->json (['message', 'status.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      {
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
      }
      {
        my $item = $result->{json}->{items}->[1];
        ok $item->{updated};
        is $item->{status_2_count}, 0;
        is $item->{status_3_count}, 0;
        is $item->{status_4_count}, 0;
        is $item->{status_5_count}, 0;
        is $item->{status_6_count}, 1;
        is $item->{status_7_count}, 0;
        is $item->{status_8_count}, 0;
        is $item->{status_9_count}, 0;
      }
    } $current->c;
  });
} n => 19, name => 'pages 1', timeout => 410;

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
    return promised_for {
      my $key = shift;
      return $current->json (['message', 'send.json'], {
        station_nobj_key => $current->o ('s1')->{nobj_key},
        to => $current->o ('t1'),
        from_name => "x",
        body => "y",
        operator_nobj_key => $current->o ('s20')->{nobj_key},
        verb_nobj_key => $current->o ('s21')->{nobj_key},
        status_verb_nobj_key => $current->o ('s21')->{nobj_key},
      })->then (sub {
        my $result = $_[0];
        $current->set_o ($key => $result->{json});
      });
    } [qw(rs1 rs2 rs3 rs4 rs5)];
  })->then (sub {
    return $current->pages_ok ([['message', 'status.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
    }] => ['rs1', 'rs2', 'rs3', 'rs4', 'rs5'], 'request_set_id');
  });
} n => 1, name => 'pager paging', timeout => 211;

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
