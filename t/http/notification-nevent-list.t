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
    [u2 => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
    [ev1 => nevent => {
      topic => 't1',
      data => {abv => 774},
    }],
  )->then (sub {
    return $current->are_errors (
      [['notification', 'nevent', 'list.json'], {
        subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      }],
      [
        {params => {}, reason => 'Bad subscriber'},
      ],
    );
  })->then (sub {
    return $current->are_empty (
      [['notification', 'nevent', 'list.json'], {
        subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      }],
      [
        ['get_nobj', 'subscriber'],
        {p => {subscriber_nobj_key => $current->o ('u2')->{nobj_key}}},
      ],
    );
  })->then (sub {
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
    } $current->c;
  });
} n => 10, name => 'subscriber an nevent';

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
    [ev1 => nevent => {
      topic => 't1',
      data => {abv => 774},
    }],
  )->then (sub {
    return $current->are_empty (
      [['notification', 'nevent', 'list.json'], {
        subscriber_nobj_key => $current->o ('u1')->{nobj_key},
        nevent_id => $current->o ('ev1')->{nevent_id},
      }],
      [
        {p => {subscriber_nobj_key => 'u2'}},
        {p => {nevent_id => rand}},
        {p => {nevent_id => ''}},
        {p => {nevent_id => '1' . $current->o ('ev1')->{nevent_id}}},
      ],
    );
  })->then (sub {
    return $current->json (['notification', 'nevent', 'list.json'], {
      nevent_id => $current->o ('ev1')->{nevent_id},
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
    } $current->c, name => 'nevent_id only';
    return $current->json (['notification', 'nevent', 'list.json'], {
      nevent_id => $current->o ('ev1')->{nevent_id},
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
    } $current->c, name => 'nevent_id and subscriber';
  });
} n => 17, name => 'nevent_id an nevent';

Test {
  my $current = shift;
  return $current->create (
    [u1 => nobj => {}],
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [sub1 => topic_subscription => {topic => 't1', subscriber => 'u1'}],
    [sub2 => topic_subscription => {topic => 't2', subscriber => 'u1'}],
    [ev1 => nevent => {topic => 't1'}],
    [ev2 => nevent => {topic => 't2'}],
    [ev3 => nevent => {topic => 't1'}],
    [ev4 => nevent => {topic => 't2'}],
    [ev5 => nevent => {topic_fallback => ['t2']}],
  )->then (sub {
    return $current->pages_ok ([['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    }] => ['ev1', 'ev2', 'ev3', 'ev4', 'ev5'], 'nevent_id');
  });
} n => 1, name => 'pager paging';

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
