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
      verb_nobj_key => $current->o ('s22')->{nobj_key},
      channel => 'vonage',
      table => (perl2json_chars {
        $current->generate_text (to1 => {}) => {
          addr => $current->generate_message_addr (a1 => {}),
        },
        $current->generate_text (to2 => {}) => {
          addr => $current->generate_message_addr (a2 => {}),
        },
      }),
    });
  })->then (sub {
    return $current->json (['message', 'setexcluded.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      operator_nobj_key => $current->o ('s10')->{nobj_key},
      verb_nobj_key => $current->o ('s11')->{nobj_key},
      to => [$current->o ('to1')],
    });
  })->then (sub {
    my $result = $_[0];
    return $current->are_errors (
      [['message', 'setexcluded.json'], {
        station_nobj_key => $current->o ('s1')->{nobj_key},
        operator_nobj_key => $current->o ('s10')->{nobj_key},
        verb_nobj_key => $current->o ('s11')->{nobj_key},
      }],
      [
        ['new_nobj', 'station'],
        ['new_nobj', 'operator'],
        ['new_nobj', 'verb'],
      ],
    );
  })->then (sub {
    return $current->json (['message', 'send.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      broadcast => 1,
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
    } $current->c;
    return $current->wait_for_messages ($current->o ('a2'));
  })->then (sub {
    my $messages = $_[0];
    test {
      my $m = $messages->[0];
      is $m->{to}, $current->o ('a2');
      is $m->{from}, $current->o ('t2');
      is $m->{text}, $current->o ('t3');
    } $current->c;
    return $current->get_message_count ($current->o ('a1'));
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 0;
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
      is $v->{data}->{expires}, undef;
      is $v->{data}->{channel}, undef;
      is $v->{data}->{table_summary}, undef;
      is 0+@{$v->{data}->{tos}}, 1;
    } $current->c, name => 's & v';
    return $current->json (['message', 'setexcluded.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      operator_nobj_key => $current->o ('s10')->{nobj_key},
      verb_nobj_key => $current->o ('s11')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['message', 'send.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      broadcast => 1,
      from_name => $current->generate_key (t5 => {}),
      body => $current->generate_text (t4 => {}),
      operator_nobj_key => $current->o ('s20')->{nobj_key},
      verb_nobj_key => $current->o ('s21')->{nobj_key},
      status_verb_nobj_key => $current->o ('s21')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{request_set_id};
    } $current->c;
    return $current->wait_for_messages ($current->o ('a1'));
  })->then (sub {
    my $messages = $_[0];
    test {
      my $m = $messages->[0];
      is $m->{to}, $current->o ('a1');
      is $m->{from}, $current->o ('t5');
      is $m->{text}, $current->o ('t4');
    } $current->c;
    return $current->get_message_count ($current->o ('a2'));
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 2;
    } $current->c;
    return $current->json (['message', 'setexcluded.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      operator_nobj_key => $current->o ('s10')->{nobj_key},
      verb_nobj_key => $current->o ('s11')->{nobj_key},
      to => [$current->o ('to1')],
    });
  })->then (sub {
    return $current->json (['nobj', 'logs.json'], {
      verb_nobj_key => $current->o ('s11')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 3;
    } $current->c;
    return $current->json (['message', 'setexcluded.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      operator_nobj_key => $current->o ('s10')->{nobj_key},
      verb_nobj_key => $current->o ('s11')->{nobj_key},
      to => [$current->generate_key (to12 => {})],
    });
  })->then (sub {
    return $current->json (['nobj', 'logs.json'], {
      verb_nobj_key => $current->o ('s11')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 4;
    } $current->c;
  });
} n => 22, name => 'exs';

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
