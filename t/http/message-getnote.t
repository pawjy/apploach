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
    return $current->are_errors (
      [['message', 'getnote.json'], {
        station_nobj_key => $current->o ('s1')->{nobj_key},
        to => $current->o ('t1'),
      }],
      [
        ['get_nobj', 'station'],
      ],
    );
  })->then (sub {
    return $current->json (['message', 'getnote.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      to => $current->o ('t1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{destination}->{addr}, $current->o ('a1');
      is 0+@{$result->{json}->{destination}->{cc_addrs}}, 0;
      is 0+keys %{$result->{json}->{notes}}, 0;
    } $current->c, name => 'found';
    return $current->json (['message', 'getnote.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      to => rand,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{destination}->{to_addr}, undef;
      is 0+@{$result->{json}->{destination}->{cc_addrs}}, 0;
      is 0+keys %{$result->{json}->{notes}}, 0;
    } $current->c, name => 'not found';
  });
} n => 7;

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
          ],
        },
        $current->generate_text (t2 => {}) => {
          addr => $current->generate_message_addr (a4 => {}),
        },
      }),
      notes => (perl2json_chars {
        $current->o ('t2') => {
          foo => $current->generate_message_addr (a5 => {}),
        },
        $current->generate_text (t3 => {}) => {
          bar => $current->generate_message_addr (a6 => {}),
        },
      }),
    });
  })->then (sub {
    return $current->json (['message', 'getnote.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      to => $current->o ('t1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{destination}->{addr}, $current->o ('a1');
      is 0+@{$result->{json}->{destination}->{cc_addrs}}, 2;
      is $result->{json}->{destination}->{cc_addrs}->[0], $current->o ('a2');
      is $result->{json}->{destination}->{cc_addrs}->[1], $current->o ('a3');
      is 0+keys %{$result->{json}->{note}}, 0;
    } $current->c, name => 'found';
    return $current->json (['message', 'getnote.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      to => $current->o ('t2'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{destination}->{addr}, $current->o ('a4');
      is 0+@{$result->{json}->{destination}->{cc_addrs}}, 0;
      is $result->{json}->{note}->{foo}, $current->o ('a5');
    } $current->c, name => 'found both';
    return $current->json (['message', 'getnote.json'], {
      station_nobj_key => $current->o ('s1')->{nobj_key},
      to => $current->o ('t3'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{destination}->{addr}, undef;
      is 0+@{$result->{json}->{destination}->{cc_addrs}}, 0;
      is $result->{json}->{note}->{bar}, $current->o ('a6');
    } $current->c, name => 'notes only';
  });
} n => 11;

RUN;

=head1 LICENSE

Copyright 2025 Wakaba <wakaba@suikawiki.org>.

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
