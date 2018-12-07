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
      topic => 't1', topic_index => 't2', channel => 'c1', subscriber => 'u1',
      status => 6, data => {foo => 54},
    }],
  )->then (sub {
    return $current->are_errors (
      [['notification', 'topic', 'list.json'], {
        subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      }],
      [
        {params => {}, reason => 'Bad subscriber'},
      ],
    );
  })->then (sub {
    return $current->are_empty (
      [['notification', 'topic', 'list.json'], {
        subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      }],
      [
        'app_id',
        ['get_nobj', 'subscriber'],
      ],
    );
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
    } $current->c;
  });
} n => 10, name => 'subscription';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [t3 => nobj => {}],
    [t5 => nobj => {}],
    [c1 => nobj => {}],
    [c2 => nobj => {}],
    [u1 => nobj => {}],
    [u2 => nobj => {}],
    [u3 => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 't1', topic_index => 't2', channel => 'c1', subscriber => 'u1',
    }],
    [sub2 => topic_subscription => {
      topic => 't3', topic_index => 't2', channel => 'c1', subscriber => 'u1',
    }],
    [sub3 => topic_subscription => {
      topic => 't1', topic_index => 't2', channel => 'c2', subscriber => 'u1',
    }],
    [sub4 => topic_subscription => {
      topic => 't1', topic_index => 't2', channel => 'c2', subscriber => 'u2',
    }],
    [sub4 => topic_subscription => {
      topic => 't5', topic_index => 't2', channel => 'c2', subscriber => 'u1',
    }],
  )->then (sub {
    return $current->are_empty (
      [['notification', 'topic', 'list.json'], {
        subscriber_nobj_key => $current->o ('u1')->{nobj_key},
        topic_nobj_key => $current->o ('t1')->{nobj_key},
      }],
      [
        'app_id',
        ['get_nobj', 'topic'],
        {p => {
          topic_nobj_key => $current->o ('c1')->{nobj_key},
        }, name => 'found but empty'},
        {p => {
          topic_nobj_key => rand,
        }, name => 'not found'},
        {p => {
          topic_index_nobj_key => $current->o ('u3')->{nobj_key},
        }},
        {p => {
          subscriber_nobj_key => $current->o ('u3')->{nobj_key},
        }},
      ],
    );
  })->then (sub {
    return $current->json (['notification', 'topic', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      topic_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $item1 = $result->{json}->{items}->[0];
      is $item1->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
      my $item2 = $result->{json}->{items}->[1];
      is $item2->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
    } $current->c;
  })->then (sub {
    return $current->json (['notification', 'topic', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      topic_nobj_key => [$current->o ('t1')->{nobj_key},
                         $current->o ('t3')->{nobj_key}],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 3;
      my $item1 = $result->{json}->{items}->[0];
      is $item1->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
      my $item2 = $result->{json}->{items}->[1];
      is $item2->{topic_nobj_key}, $current->o ('t3')->{nobj_key};
      my $item3 = $result->{json}->{items}->[2];
      is $item3->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
    } $current->c;
  });
} n => 8, name => 'topic';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [t3 => nobj => {}],
    [c1 => nobj => {}],
    [c2 => nobj => {}],
    [u1 => nobj => {}],
    [u2 => nobj => {}],
    [u3 => nobj => {}],
    [a1 => nobj => {}],
    [a2 => nobj => {}],
    [a3 => nobj => {}],
    [a4 => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 'a1', topic_index => 't1', channel => 'c1', subscriber => 'u1',
    }],
    [sub2 => topic_subscription => {
      topic => 'a2', topic_index => 't3', channel => 'c1', subscriber => 'u1',
    }],
    [sub3 => topic_subscription => {
      topic => 'a3', topic_index => 't1', channel => 'c2', subscriber => 'u1',
    }],
    [sub4 => topic_subscription => {
      topic => 'a4', topic_index => 't1', channel => 'c2', subscriber => 'u2',
    }],
  )->then (sub {
    return $current->are_empty (
      [['notification', 'topic', 'list.json'], {
        subscriber_nobj_key => $current->o ('u1')->{nobj_key},
        topic_index_nobj_key => $current->o ('t1')->{nobj_key},
      }],
      [
        'app_id',
        ['get_nobj', 'topic_index'],
        {p => {
          topic_index_nobj_key => $current->o ('c1')->{nobj_key},
        }, name => 'found but empty'},
        {p => {
          topic_index_nobj_key => rand,
        }, name => 'not found'},
        {p => {
          topic_nobj_key => $current->o ('u3')->{nobj_key},
        }},
        {p => {
          subscriber_nobj_key => $current->o ('u3')->{nobj_key},
        }},
      ],
    );
  })->then (sub {
    return $current->json (['notification', 'topic', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      topic_index_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $item1 = $result->{json}->{items}->[0];
      is $item1->{topic_nobj_key}, $current->o ('a3')->{nobj_key};
      my $item2 = $result->{json}->{items}->[1];
      is $item2->{topic_nobj_key}, $current->o ('a1')->{nobj_key};
    } $current->c;
  });
} n => 4, name => 'topic_index';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [t3 => nobj => {}],
    [t4 => nobj => {}],
    [c1 => nobj => {}],
    [c2 => nobj => {}],
    [c3 => nobj => {}],
    [u1 => nobj => {}],
    [u2 => nobj => {}],
    [u3 => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 't1', topic_index => 't2', channel => 'c1', subscriber => 'u1',
    }],
    [sub2 => topic_subscription => {
      topic => 't2', topic_index => 't2', channel => 'c3', subscriber => 'u1',
    }],
    [sub3 => topic_subscription => {
      topic => 't3', topic_index => 't2', channel => 'c1', subscriber => 'u1',
    }],
    [sub4 => topic_subscription => {
      topic => 't4', topic_index => 't2', channel => 'c1', subscriber => 'u2',
    }],
    [sub5 => topic_subscription => {
      topic => 't3', topic_index => 't2', channel => 'c2', subscriber => 'u1',
    }],
  )->then (sub {
    return $current->are_empty (
      [['notification', 'topic', 'list.json'], {
        subscriber_nobj_key => $current->o ('u1')->{nobj_key},
        channel_nobj_key => $current->o ('c1')->{nobj_key},
      }],
      [
        'app_id',
        ['get_nobj', 'channel'],
        {p => {
          channel_nobj_key => $current->o ('t4')->{nobj_key},
        }, name => 'found but empty'},
        {p => {
          channel_nobj_key => rand,
        }, name => 'not found'},
        {p => {
          topic_nobj_key => $current->o ('u3')->{nobj_key},
        }},
        {p => {
          topic_index_nobj_key => $current->o ('u3')->{nobj_key},
        }},
        {p => {
          subscriber_nobj_key => $current->o ('u3')->{nobj_key},
        }},
      ],
    );
  })->then (sub {
    return $current->json (['notification', 'topic', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $item1 = $result->{json}->{items}->[0];
      is $item1->{topic_nobj_key}, $current->o ('t3')->{nobj_key};
      my $item2 = $result->{json}->{items}->[1];
      is $item2->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
    } $current->c;
  })->then (sub {
    return $current->json (['notification', 'topic', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      channel_nobj_key => [$current->o ('c1')->{nobj_key},
                           $current->o ('c3')->{nobj_key}],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 3;
      my $item1 = $result->{json}->{items}->[0];
      is $item1->{topic_nobj_key}, $current->o ('t3')->{nobj_key};
      my $item2 = $result->{json}->{items}->[1];
      is $item2->{topic_nobj_key}, $current->o ('t2')->{nobj_key};
      my $item3 = $result->{json}->{items}->[2];
      is $item3->{topic_nobj_key}, $current->o ('t1')->{nobj_key};
    } $current->c;
  });
} n => 8, name => 'channel';

Test {
  my $current = shift;
  return $current->create (
    [u1 => nobj => {}],
    [c1 => topic_subscription => {subscriber => 'u1'}],
    [c2 => topic_subscription => {subscriber => 'u1'}],
    [c3 => topic_subscription => {subscriber => 'u1'}],
    [c4 => topic_subscription => {subscriber => 'u1'}],
    [c5 => topic_subscription => {subscriber => 'u1'}],
  )->then (sub {
    return $current->pages_ok ([['notification', 'topic', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    }] => ['c1', 'c2', 'c3', 'c4', 'c5'], 'revision_id');
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
