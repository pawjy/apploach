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
    [ev1 => nevent => {
      topic => 't1', data => {abv => 774},
    }],
  )->then (sub {
    return $current->are_empty (
      [['notification', 'nevent', 'lockqueued.json'], {
        channel_nobj_key => $current->o ('c1')->{nobj_key},
      }],
      [
        'app_id',
        ['get_nobj', 'channel'],
        {p => {channel_nobj_key => $current->o ('t2')->{nobj_key}}},
      ],
    );
  })->then (sub {
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
    } $current->c;
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c;
  });
} n => 11, name => 'lock';

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
    [ev1 => nevent => {topic => 't1'}],
    [ev2 => nevent => {topic => 't1'}],
    [ev3 => nevent => {topic => 't1'}],
    [ev4 => nevent => {topic => 't1'}],
    [ev5 => nevent => {topic => 't1'}],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
      limit => 2,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev1')->{nevent_id};
      my $ev2 = $result->{json}->{items}->[1];
      is $ev2->{nevent_id}, $current->o ('ev2')->{nevent_id};
    } $current->c;
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
      limit => 2,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev3')->{nevent_id};
      my $ev2 = $result->{json}->{items}->[1];
      is $ev2->{nevent_id}, $current->o ('ev4')->{nevent_id};
    } $current->c;
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
      limit => 2,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $ev1 = $result->{json}->{items}->[0];
      is $ev1->{nevent_id}, $current->o ('ev5')->{nevent_id};
    } $current->c;
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c;
  });
} n => 9, name => 'limit';

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
