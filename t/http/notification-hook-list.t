use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [c1 => nobj => {}],
    [u1 => nobj => {}],
    [sub1 => hook => {
      type => 'c1', subscriber => 'u1',
      url => $current->generate_url (e1 => {}),
      status => 6, data => {foo => 54},
    }],
  )->then (sub {
    return $current->are_errors (
      [['notification', 'hook', 'list.json'], {
        subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      }],
      [
        {params => {}, reason => 'Bad subscriber'},
      ],
    );
  })->then (sub {
    return $current->are_empty (
      [['notification', 'hook', 'list.json'], {
        subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      }],
      [
        'app_id',
        ['get_nobj', 'subscriber'],
      ],
    );
  })->then (sub {
    return $current->json (['notification', 'hook', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $item = $result->{json}->{items}->[0];
      is $item->{type_nobj_key}, $current->o ('c1')->{nobj_key};
      is $item->{subscriber_nobj_key}, $current->o ('u1')->{nobj_key};
      is $item->{url}, $current->o ('e1');
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
    [u1 => nobj => {}],
    [u2 => nobj => {}],
    [u3 => nobj => {}],
    [sub1 => hook => {
      type => 't1', subscriber => 'u1',
    }],
    [sub2 => hook => {
      type => 't3', subscriber => 'u1',
    }],
    [sub3 => hook => {
      type => 't1', subscriber => 'u1',
    }],
    [sub4 => hook => {
      type => 't1', subscriber => 'u2',
    }],
    [sub4 => hook => {
      type => 't5', subscriber => 'u1',
    }],
  )->then (sub {
    return $current->are_empty (
      [['notification', 'hook', 'list.json'], {
        subscriber_nobj_key => $current->o ('u1')->{nobj_key},
        type_nobj_key => $current->o ('t1')->{nobj_key},
      }],
      [
        'app_id',
        ['get_nobj', 'type'],
        {p => {
          type_nobj_key => $current->o ('u1')->{nobj_key},
        }, name => 'found but empty'},
        {p => {
          type_nobj_key => rand,
        }, name => 'not found'},
        {p => {
          subscriber_nobj_key => $current->o ('u3')->{nobj_key},
        }},
      ],
    );
  })->then (sub {
    return $current->json (['notification', 'hook', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      type_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $item1 = $result->{json}->{items}->[0];
      is $item1->{type_nobj_key}, $current->o ('t1')->{nobj_key};
      my $item2 = $result->{json}->{items}->[1];
      is $item2->{type_nobj_key}, $current->o ('t1')->{nobj_key};
    } $current->c;
  })->then (sub {
    return $current->json (['notification', 'hook', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      type_nobj_key => [$current->o ('t1')->{nobj_key},
                        $current->o ('t3')->{nobj_key}],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 3;
      my $item1 = $result->{json}->{items}->[0];
      is $item1->{type_nobj_key}, $current->o ('t1')->{nobj_key};
      my $item2 = $result->{json}->{items}->[1];
      is $item2->{type_nobj_key}, $current->o ('t3')->{nobj_key};
      my $item3 = $result->{json}->{items}->[2];
      is $item3->{type_nobj_key}, $current->o ('t1')->{nobj_key};
    } $current->c;
  });
} n => 8, name => 'type';

Test {
  my $current = shift;
  return $current->create (
    [u1 => nobj => {}],
    [c1 => hook => {subscriber => 'u1'}],
    [c2 => hook => {subscriber => 'u1'}],
    [c3 => hook => {subscriber => 'u1'}],
    [c4 => hook => {subscriber => 'u1'}],
    [c5 => hook => {subscriber => 'u1'}],
  )->then (sub {
    return $current->pages_ok ([['notification', 'hook', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    }] => ['c1', 'c2', 'c3', 'c4', 'c5'], 'url');
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
