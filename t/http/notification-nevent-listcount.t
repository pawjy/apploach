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
  )->then (sub {
    return $current->json (['notification', 'nevent', 'listcount.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{last_checked}, 0;
      is $result->{json}->{unchecked_count}, 0;
    } $current->c, name => 'initial';
    return $current->create (
      [ev1 => nevent => {topic => 't1'}],
    );
  })->then (sub {
    return $current->json (['notification', 'nevent', 'listcount.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{last_checked}, 0;
      is $result->{json}->{unchecked_count}, 1;
    } $current->c, name => 'event added';
    return $current->json (['notification', 'nevent', 'listtouch.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      timestamp => 634634634,
    });
  })->then (sub {
    return $current->json (['notification', 'nevent', 'listcount.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{last_checked}, 634634634;
      is $result->{json}->{unchecked_count}, 1;
    } $current->c;
    return $current->json (['notification', 'nevent', 'listtouch.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      timestamp => time,
    });
  })->then (sub {
    return $current->json (['notification', 'nevent', 'listcount.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{last_checked};
      is $result->{json}->{unchecked_count}, 0;
    } $current->c;
    return $current->create (
      [ev1 => nevent => {topic => 't1'}],
    );
  })->then (sub {
    return $current->json (['notification', 'nevent', 'listcount.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{last_checked};
      is $result->{json}->{unchecked_count}, 1;
    } $current->c;
    return $current->json (['notification', 'nevent', 'listcount.json'], {
      subscriber_nobj_key => undef,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{last_checked}, 0;
      is $result->{json}->{unchecked_count}, 0;
    } $current->c;
    return $current->json (['notification', 'nevent', 'listcount.json'], {
      subscriber_nobj_key => rand,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{last_checked}, 0;
      is $result->{json}->{unchecked_count}, 0;
    } $current->c;
  });
} n => 14, name => 'unchecked count';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [t3 => nobj => {}],
    [u1 => nobj => {}],
    [sub1 => topic_subscription => {topic => 't1', subscriber => 'u1'}],
    [sub2 => topic_subscription => {topic => 't2', subscriber => 'u1'}],
    [sub3 => topic_subscription => {topic => 't3', subscriber => 'u1'}],
    [ev01 => nevent => {topic => 't1'}],
    [ev02 => nevent => {topic => 't2'}],
    [ev03 => nevent => {topic => 't3'}],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'listtouch.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      timestamp => time,
    });
  })->then (sub {
    return $current->create (
      [ev1 => nevent => {topic => 't1'}],
      [ev2 => nevent => {topic => 't2'}],
      [ev3 => nevent => {topic => 't3'}],
    );
  })->then (sub {
    return $current->json (['notification', 'nevent', 'listcount.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      topic_nobj_key => [$current->o ('t1')->{nobj_key},
                         rand,
                         $current->o ('t2')->{nobj_key}],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{last_checked};
      is $result->{json}->{unchecked_count}, 2;
    } $current->c;
  })->then (sub {
    return $current->json (['notification', 'nevent', 'listcount.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      topic_excluded_nobj_key => [$current->o ('t3')->{nobj_key},
                                  rand,
                                  $current->o ('t2')->{nobj_key}],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{last_checked};
      is $result->{json}->{unchecked_count}, 1;
    } $current->c;
    return $current->json (['notification', 'nevent', 'listcount.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      topic_nobj_key => [rand],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{last_checked};
      is $result->{json}->{unchecked_count}, 0;
    } $current->c;
    return $current->json (['notification', 'nevent', 'listcount.json'], {
      subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      topic_excluded_nobj_key => [rand],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{last_checked};
      is $result->{json}->{unchecked_count}, 3;
    } $current->c;
  });
} n => 8, name => 'unchecked count topic filtered';

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
