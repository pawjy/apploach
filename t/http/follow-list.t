use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [a1 => account => {}],
    [a2 => account => {}],
    [t1 => nobj => {}],
    [f1 => follow => {subject => 'a1', object => 'a2', verb => 't1', value => 4}],
  )->then (sub {
    return $current->are_empty (
      [['follow', 'list.json'], {
        subject_nobj_key => $current->o ('a1')->{nobj_key},
        object_nobj_key => $current->o ('a2')->{nobj_key},
        verb_nobj_key => $current->o ('t1')->{nobj_key},
      }],
      [
        'app_id',
        ['get_nobj', 'subject'],
        ['get_nobj', 'object'],
        ['get_nobj', 'verb'],
      ],
    );
  })->then (sub {
    return $current->json (['follow', 'list.json'], {
      subject_nobj_key => $current->o ('a1')->{nobj_key},
      object_nobj_key => $current->o ('a2')->{nobj_key},
      verb_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{subject_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{object_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{value}, 4;
      is $v->{timestamp}, undef;
    } $current->c, name => 's & o & v';
  })->then (sub {
    return $current->json (['follow', 'list.json'], {
      subject_nobj_key => $current->o ('a1')->{nobj_key},
      object_nobj_key => $current->o ('a2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{subject_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{object_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{value}, 4;
      is $v->{timestamp}, undef;
    } $current->c, name => 's & o';
  })->then (sub {
    return $current->json (['follow', 'list.json'], {
      subject_nobj_key => $current->o ('a1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{subject_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{object_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{value}, 4;
      is $v->{timestamp}, undef;
    } $current->c, name => 's';
    return $current->json (['follow', 'list.json'], {
      object_nobj_key => $current->o ('a2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{subject_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{object_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{value}, 4;
      is $v->{timestamp}, undef;
    } $current->c, name => 'o';
    return $current->json (['follow', 'list.json'], {
      subject_nobj_key => $current->o ('a1')->{nobj_key},
      verb_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{subject_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{object_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{value}, 4;
      is $v->{timestamp}, undef;
    } $current->c, name => 's & v';
  });
} n => 31, name => 'follow list';

Test {
  my $current = shift;
  return $current->create (
    [a1 => account => {}],
    [a2 => account => {}],
    [a3 => account => {}],
    [a4 => account => {}],
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [f1 => follow => {subject => 'a1', object => 'a2', verb => 't1', value => 4}],
    [f2 => follow => {subject => 'a1', object => 'a3', verb => 't1', value => 5}],
    [f3 => follow => {subject => 'a4', object => 'a2', verb => 't1', value => 6}],
    [f4 => follow => {subject => 'a1', object => 'a2', verb => 't2', value => 7}],
  )->then (sub {
    return $current->json (['follow', 'list.json'], {
      subject_nobj_key => $current->o ('a1')->{nobj_key},
      object_nobj_key => $current->o ('a2')->{nobj_key},
      verb_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{subject_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{object_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{value}, 4;
      is $v->{timestamp}, undef;
    } $current->c, name => 's & o & v';
    return $current->json (['follow', 'list.json'], {
      subject_nobj_key => $current->o ('a1')->{nobj_key},
      verb_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $v = $result->{json}->{items}->[1];
      is $v->{subject_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{object_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{value}, 4;
      my $v2 = $result->{json}->{items}->[0];
      is $v2->{subject_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v2->{object_nobj_key}, $current->o ('a3')->{nobj_key};
      is $v2->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v2->{value}, 5;
    } $current->c, name => 's & v';
    return $current->json (['follow', 'list.json'], {
      subject_nobj_key => $current->o ('a1')->{nobj_key},
      object_nobj_key => $current->o ('a2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $v = $result->{json}->{items}->[1];
      is $v->{subject_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{object_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{value}, 4;
      my $v2 = $result->{json}->{items}->[0];
      is $v2->{subject_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v2->{object_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v2->{verb_nobj_key}, $current->o ('t2')->{nobj_key};
      is $v2->{value}, 7;
    } $current->c, name => 's & o';
  });
} n => 24, name => 'follow list';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [t3 => nobj => {}],
    [t4 => nobj => {}],
    [t5 => nobj => {}],
    [a1 => account => {}],
    [a2 => account => {}],
    [f1 => follow => {subject => 'a1', object => 'a2', verb => 't1'}],
    [f2 => follow => {subject => 'a1', object => 'a2', verb => 't2'}],
    [f3 => follow => {subject => 'a1', object => 'a2', verb => 't3'}],
    [f4 => follow => {subject => 'a1', object => 'a2', verb => 't4'}],
    [f5 => follow => {subject => 'a1', object => 'a2', verb => 't5'}],
  )->then (sub {
    return $current->pages_ok ([['follow', 'list.json'], {
      subject_nobj_key => $current->o ('a1')->{nobj_key},
      object_nobj_key => $current->o ('a2')->{nobj_key},
    }] => ['f1', 'f2', 'f3', 'f4', 'f5'], 'verb_nobj_key');
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
