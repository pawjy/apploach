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
  )->then (sub {
    return $current->are_errors (
      [['notification', 'topic', 'subscribe.json'], {
        topic_nobj_key => $current->o ('t1')->{nobj_key},
        topic_index_nobj_key => $current->o ('t2')->{nobj_key},
        channel_nobj_key => $current->o ('c1')->{nobj_key},
        subscriber_nobj_key => $current->o ('u1')->{nobj_key},
        status => 20,
        data => {foo => 56},
      }],
      [
        ['new_nobj', 'topic'],
        ['new_nobj', 'topic_index'],
        ['new_nobj', 'channel'],
        ['new_nobj', 'subscriber'],
        ['json', 'data'],
        {p => {status => 0}, reason => 'Bad |status|'},
        {p => {status => 1}, reason => 'Bad |status|'},
        {p => {status => 256}, reason => 'Bad |status|'},
        {p => {status => "abx"}, reason => 'Bad |status|'},
      ],
    );
  })->then (sub {
    return $current->json (['notification', 'topic', 'subscribe.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      topic_index_nobj_key => $current->o ('t2')->{nobj_key},
      channel_nobj_key => $current->o ('c1')->{nobj_key},
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      status => 6,
      data => {foo => 54},
    });
  })->then (sub {
    return $current->json (['notification', 'topic', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $item = $result->{json}->{items}->[0];
      is $item->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
      is $item->{channel_nobj_key}, $current->o ('c1')->{nobj_key};
      is $item->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $item->{data}->{foo}, 54;
      is $item->{status}, 6;
      ok $item->{created};
      ok $item->{updated};
    } $current->c, name => 'new subscription';
    $current->set_o (sub1 => $result->{json}->{items}->[0]);
    return $current->json (['notification', 'topic', 'subscribe.json'], {
      topic_nobj_key => $current->o ('t1')->{nobj_key},
      topic_index_nobj_key => $current->o ('t2')->{nobj_key},
      channel_nobj_key => $current->o ('c1')->{nobj_key},
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      status => 12,
      data => {bar => 1.54},
    });
  })->then (sub {
    return $current->json (['notification', 'topic', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $item = $result->{json}->{items}->[0];
      is $item->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
      is $item->{channel_nobj_key}, $current->o ('c1')->{nobj_key};
      is $item->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $item->{data}->{foo}, undef;
      is $item->{data}->{bar}, 1.54;
      is $item->{status}, 12;
      is $item->{created}, $current->o ('sub1')->{created};
      ok $item->{updated} > $current->o ('sub1')->{updated};
    } $current->c, name => 'updated';
  });
} n => 18, name => 'subscribe';

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
