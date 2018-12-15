use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [u1 => nobj => {}],
    [sub1 => topic_subscription => {topic => 't1', subscriber => 'u1'}],
    [ev1 => nevent => {topic => 't1'}],
  )->then (sub {
    return $current->are_errors (
      [['notification', 'nevent', 'listtouch.json'], {
        subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      }],
      [
        ['new_nobj', 'subscriber'],
      ],
    );
  })->then (sub {
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{last_checked}, 0;
    } $current->c, name => 'initial';
    return $current->json (['notification', 'nevent', 'listtouch.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{last_checked};
    } $current->c;
    return $current->create (
      [ev1 => nevent => {topic => 't1'}],
    );
  })->then (sub {
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{last_checked} < $result->{json}->{items}->[0]->{timestamp};
    } $current->c;
  });
} n => 4, name => 'touch';

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
