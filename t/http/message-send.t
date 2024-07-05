use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [s1 => nobj => {}],
  )->then (sub {
    return $current->json (['message', 'setroutes.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
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
      body => $current->generate_key (t3 => {}),
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
      }],
      [
        ['get_nobj', 'station'],
        {p => {to => rand}, status => 400},
      ],
    );
  })->then (sub {
    return $current->wait_for_messages ($current->o ('a1'));
  })->then (sub {
    my $messages = $_[0];
    test {
      my $m = $messages->[0];
      ok $m->{api_key};
      ok $m->{api_secret};
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
        return $result->{json}->{status_6_count};
      });
    } timeout => 60;
  })->then (sub {
    return $current->json (['message', 'status.json'], {
      request_set_id => $current->o ('rs1')->{request_set_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{updated};
      is $result->{json}->{status_2_count}, 0;
      is $result->{json}->{status_3_count}, 0;
      is $result->{json}->{status_4_count}, 0;
      is $result->{json}->{status_5_count}, 0;
      is $result->{json}->{status_6_count}, 1;
      is $result->{json}->{status_7_count}, 0;
      is $result->{json}->{status_8_count}, 0;
      is $result->{json}->{status_9_count}, 0;
    } $current->c;
  });
} n => 19, name => 'sent';

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
