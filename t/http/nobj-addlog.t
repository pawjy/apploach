use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [a1 => account => {}],
    [v1 => nobj => {}],
    [t1 => nobj => {}],
  )->then (sub {
    return $current->are_errors (
      [['nobj', 'addlog.json'], {
        target_nobj_key => $current->o ('t1')->{nobj_key},
        verb_nobj_key => $current->o ('v1')->{nobj_key},
        operator_nobj_key => $current->o ('a1')->{nobj_key},
        data => {foo => $current->generate_text ('g1' => {})},
      }],
      [
        ['new_nobj', 'target'],
        ['new_nobj', 'verb'],
        ['new_nobj', 'operator'],
        ['json', 'data'],
      ],
    );
  })->then (sub {
    return $current->json (['nobj', 'addlog.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
      verb_nobj_key => $current->o ('v1')->{nobj_key},
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      data => {foo => $current->o ('g1')},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{log_id};
      ok $result->{json}->{timestamp};
      like $result->{res}->body_bytes, qr{"log_id"\s*:\s*"};
      $current->set_o (l1 => $result->{json});
    } $current->c;
    return $current->json (['nobj', 'logs.json'], {
      log_id => $current->o ('l1')->{log_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $log = $result->{json}->{items}->[0];
      is $log->{log_id}, $current->o ('l1')->{log_id};
      is $log->{timestamp}, undef;
      is $log->{data}->{timestamp}, $current->o ('l1')->{timestamp};
      is $log->{data}->{foo}, $current->o ('g1');
      is $log->{target_nobj_key}, $current->o ('t1')->{nobj_key};
      is $log->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $log->{verb_nobj_key}, $current->o ('v1')->{nobj_key};
    } $current->c;
  });
} n => 12, name => 'addlog';

Test {
  my $current = shift;
  $current->generate_text ('g1' => {});
  return $current->create (
    [a1 => account => {}],
    [v1 => nobj => {}],
    [t1 => nobj => {}],
  )->then (sub {
    return $current->json (['nobj', 'addlog.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
      verb_nobj_key => $current->o ('v1')->{nobj_key},
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      data => {foo => $current->o ('g1'), timestamp => 543535},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{log_id};
      is $result->{json}->{timestamp}, 543535;
      $current->set_o (l1 => $result->{json});
    } $current->c;
    return $current->json (['nobj', 'logs.json'], {
      log_id => $current->o ('l1')->{log_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $log = $result->{json}->{items}->[0];
      is $log->{log_id}, $current->o ('l1')->{log_id};
      is $log->{timestamp}, undef;
      is $log->{data}->{timestamp}, 543535;
      is $log->{data}->{foo}, $current->o ('g1');
      is $log->{target_nobj_key}, $current->o ('t1')->{nobj_key};
      is $log->{target_nobj_index_key}, undef;
      is $log->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $log->{verb_nobj_key}, $current->o ('v1')->{nobj_key};
    } $current->c;
  });
} n => 11, name => 'addlog';

Test {
  my $current = shift;
  $current->generate_text ('g1' => {});
  return $current->create (
    [a1 => account => {}],
    [v1 => nobj => {}],
    [t1 => nobj => {}],
  )->then (sub {
    return $current->json (['nobj', 'addlog.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
      verb_nobj_key => $current->o ('v1')->{nobj_key},
      operator_nobj_key => $current->o ('a1')->{nobj_key},
      data => {foo => $current->o ('g1'), timestamp => 543535},
      test_no_target_index => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{log_id};
      is $result->{json}->{timestamp}, 543535;
      $current->set_o (l1 => $result->{json});
    } $current->c;
    return $current->json (['nobj', 'logs.json'], {
      log_id => $current->o ('l1')->{log_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $log = $result->{json}->{items}->[0];
      is $log->{log_id}, $current->o ('l1')->{log_id};
      is $log->{timestamp}, undef;
      is $log->{data}->{timestamp}, 543535;
      is $log->{data}->{foo}, $current->o ('g1');
      is $log->{target_nobj_key}, $current->o ('t1')->{nobj_key};
      is $log->{target_nobj_index_key}, undef;
      is $log->{operator_nobj_key}, $current->o ('a1')->{nobj_key};
      is $log->{verb_nobj_key}, $current->o ('v1')->{nobj_key};
    } $current->c;
  });
} n => 11, name => 'addlog';

RUN;

=head1 LICENSE

Copyright 2018-2021 Wakaba <wakaba@suikawiki.org>.

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
