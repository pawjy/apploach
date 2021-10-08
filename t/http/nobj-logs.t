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
    [f1 => log => {operator => 'a1', target => 'a2', verb => 't1',
                   data => {abc => $current->generate_text (v1 => {})}}],
  )->then (sub {
    return $current->are_empty (
      [['nobj', 'logs.json'], {
        operator_nobj_key => $current->o ('a1')->{nobj_key},
        target_nobj_key => $current->o ('a2')->{nobj_key},
        verb_nobj_key => $current->o ('t1')->{nobj_key},
      }],
      [
        'app_id',
        ['get_nobj', 'operator'],
        ['get_nobj', 'target'],
        ['get_nobj', 'verb'],
        {params => {log_id => $current->generate_id (rand, {})}},
      ],
    );
  })->then (sub {
    return $current->json (['nobj', 'logs.json'], {
      log_id => $current->o ('f1')->{log_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{log_id}, $current->o ('f1')->{log_id};
      is $v->{data}->{timestamp}, $current->o ('f1')->{timestamp};
      is $v->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{data}->{abc}, $current->o ('v1');
      is $v->{timestamp}, undef;
    } $current->c, name => 'log_id';
  })->then (sub {
    return $current->json (['nobj', 'logs.json'], {
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      target_nobj_key => $current->o ('a2')->{nobj_key},
      verb_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{log_id}, $current->o ('f1')->{log_id};
      is $v->{data}->{timestamp}, $current->o ('f1')->{timestamp};
      is $v->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{data}->{abc}, $current->o ('v1');
      is $v->{timestamp}, undef;
    } $current->c, name => 's & o & v';
  })->then (sub {
    return $current->json (['nobj', 'logs.json'], {
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      target_nobj_key => $current->o ('a2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{data}->{abc}, $current->o ('v1');
      is $v->{timestamp}, undef;
    } $current->c, name => 's & o';
  })->then (sub {
    return $current->json (['nobj', 'logs.json'], {
      operator_nobj_key => $current->o ('a1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{data}->{abc}, $current->o ('v1');
      is $v->{timestamp}, undef;
    } $current->c, name => 's';
    return $current->json (['nobj', 'logs.json'], {
      target_nobj_key => $current->o ('a2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{data}->{abc}, $current->o ('v1');
      is $v->{timestamp}, undef;
    } $current->c, name => 'o';
    return $current->json (['nobj', 'logs.json'], {
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      verb_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{data}->{abc}, $current->o ('v1');
      is $v->{timestamp}, undef;
    } $current->c, name => 's & v';
    return $current->json (['nobj', 'logs.json'], {
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      verb_nobj_key => $current->o ('t1')->{nobj_key},
      without_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{data}, undef;
      is $v->{timestamp}, undef;
    } $current->c, name => 'without_data';
  });
} n => 47, name => 'log list';

Test {
  my $current = shift;
  return $current->create (
    [a1 => account => {}],
    [a2 => account => {}],
    [a3 => account => {}],
    [a4 => account => {}],
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [f1 => log => {operator => 'a1', target => 'a2', verb => 't1', data => {value => 4}}],
    [f2 => log => {operator => 'a1', target => 'a3', verb => 't1', data => {value => 5}}],
    [f3 => log => {operator => 'a4', target => 'a2', verb => 't1', data => {value => 6}}],
    [f4 => log => {operator => 'a1', target => 'a2', verb => 't2', data => {value => 7}}],
  )->then (sub {
    return $current->json (['nobj', 'logs.json'], {
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      target_nobj_key => $current->o ('a2')->{nobj_key},
      verb_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{data}->{value}, 4;
      is $v->{timestamp}, undef;
    } $current->c, name => 's & o & v';
    return $current->json (['nobj', 'logs.json'], {
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      verb_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $v = $result->{json}->{items}->[1];
      is $v->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{data}->{value}, 4;
      my $v2 = $result->{json}->{items}->[0];
      is $v2->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v2->{target_nobj_key}, $current->o ('a3')->{nobj_key};
      is $v2->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v2->{data}->{value}, 5;
    } $current->c, name => 's & v';
    return $current->json (['nobj', 'logs.json'], {
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      target_nobj_key => $current->o ('a2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $v = $result->{json}->{items}->[1];
      is $v->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v->{target_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v->{verb_nobj_key}, $current->o ('t1')->{nobj_key};
      is $v->{data}->{value}, 4;
      my $v2 = $result->{json}->{items}->[0];
      is $v2->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $v2->{target_nobj_key}, $current->o ('a2')->{nobj_key};
      is $v2->{verb_nobj_key}, $current->o ('t2')->{nobj_key};
      is $v2->{data}->{value}, 7;
    } $current->c, name => 's & o';
  });
} n => 24, name => 'log list';

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
    [f1 => log => {operator => 'a1', target => 'a2', verb => 't1'}],
    [f2 => log => {operator => 'a1', target => 'a2', verb => 't2'}],
    [f3 => log => {operator => 'a1', target => 'a2', verb => 't3'}],
    [f4 => log => {operator => 'a1', target => 'a2', verb => 't4'}],
    [f5 => log => {operator => 'a1', target => 'a2', verb => 't5'}],
  )->then (sub {
    return $current->pages_ok ([['nobj', 'logs.json'], {
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      target_nobj_key => $current->o ('a2')->{nobj_key},
    }] => ['f1', 'f2', 'f3', 'f4', 'f5'], 'log_id');
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
