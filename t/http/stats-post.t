use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [i1 => nobj => {}],
  )->then (sub {
    return $current->are_errors (
      [['stats', 'post.json'], {
        item_nobj_key => $current->o ('i1')->{nobj_key},
        day => 346344521,
        value_all => 1553,
      }],
      [
        ['new_nobj', 'item'],
        {p => {day => undef}, reason => 'Bad |day|'},
        {p => {value_all => undef}, reason => 'Bad |value_all|'},
      ],
    );
  })->then (sub {
    return $current->json (['stats', 'post.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
      day => 3463445455,
      value_all => 3543.553,
    });
  })->then (sub {
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is_deeply $result->{json}->{items}, [{
        day => 3463430400,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 3543.553,
          value_1 => 3543.553,
          value_7 => 3543.553,
          value_30 => 3543.553,
        }},
      }];
    } $current->c, name => 'only data';
    return $current->json (['stats', 'post.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
      day => 3478445455,
      value_all => -355.3,
    });
  })->then (sub {
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is_deeply $result->{json}->{items}, [{
        day => 3463430400,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 3543.553,
          value_1 => 3543.553,
          value_7 => 3543.553,
          value_30 => 3543.553,
        }},
      }, {
        day => 3478377600,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => -355.3,
          value_1 => -355.3 - 3543.553,
          value_7 => -355.3 - 3543.553,
          value_30 => -355.3 - 3543.553,
        }},
      }];
    } $current->c, name => 'next data';
    return $current->json (['stats', 'post.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
      day => 14784446,
      value_all => 551.004,
    });
  })->then (sub {
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is_deeply $result->{json}->{items}, [{
        day => 14774400,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 551.004,
          value_1 => 551.004,
          value_7 => 551.004,
          value_30 => 551.004,
        }},
      }, {
        day => 3463430400,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 3543.553,
          value_1 => 3543.553 - 551.004,
          value_7 => 3543.553 - 551.004,
          value_30 => 3543.553 - 551.004,
        }},
      }, {
        day => 3478377600,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => -355.3,
          value_1 => -355.3 - 3543.553,
          value_7 => -355.3 - 3543.553,
          value_30 => -355.3 - 3543.553,
        }},
      }];
    } $current->c, name => 'prev data';
    return $current->json (['stats', 'post.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
      day => 24712431,
      value_all => 1051.004,
    });
  })->then (sub {
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is_deeply $result->{json}->{items}, [{
        day => 14774400,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 551.004,
          value_1 => 551.004,
          value_7 => 551.004,
          value_30 => 551.004,
        }},
      }, {
        day => 24710400,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 1051.004,
          value_1 => 1051.004 - 551.004,
          value_7 => 1051.004 - 551.004,
          value_30 => 1051.004 - 551.004,
        }},
      }, {
        day => 3463430400,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 3543.553,
          value_1 => 3543.553 - 1051.004,
          value_7 => 3543.553 - 1051.004,
          value_30 => 3543.553 - 1051.004,
        }},
      }, {
        day => 3478377600,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => -355.3,
          value_1 => -355.3 - 3543.553,
          value_7 => -355.3 - 3543.553,
          value_30 => -355.3 - 3543.553,
        }},
      }];
    } $current->c, name => 'between data';
  });
} n => 5, name => '/stats/post.json (value_all based)';

Test {
  my $current = shift;
  return $current->create (
    [i1 => nobj => {}],
  )->then (sub {
    return $current->json (['stats', 'post.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
      day => 3463445455,
      value_1 => 3543.553,
    });
  })->then (sub {
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is_deeply $result->{json}->{items}, [{
        day => 3463430400,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 0,
          value_1 => 3543.553,
          value_7 => 3543.553,
          value_30 => 3543.553,
        }},
      }];
    } $current->c, name => 'only data';
    return $current->json (['stats', 'post.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
      day => 3478445455,
      value_1 => -355.3,
    });
  })->then (sub {
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is_deeply $result->{json}->{items}, [{
        day => 3463430400,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 0,
          value_1 => 3543.553,
          value_7 => 3543.553,
          value_30 => 3543.553,
        }},
      }, {
        day => 3478377600,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 0,
          value_1 => -355.3,
          value_7 => -355.3,
          value_30 => -355.3,
        }},
      }];
    } $current->c, name => 'next data';
    return $current->json (['stats', 'post.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
      day => 14784446,
      value_1 => 551.004,
    });
  })->then (sub {
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is_deeply $result->{json}->{items}, [{
        day => 14774400,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 0,
          value_1 => 551.004,
          value_7 => 551.004,
          value_30 => 551.004,
        }},
      }, {
        day => 3463430400,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 0,
          value_1 => 3543.553,
          value_7 => 3543.553,
          value_30 => 3543.553,
        }},
      }, {
        day => 3478377600,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 0,
          value_1 => -355.3,
          value_7 => -355.3,
          value_30 => -355.3,
        }},
      }];
    } $current->c, name => 'prev data';
    return $current->json (['stats', 'post.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
      day => 24712431,
      value_1 => 1051.004,
    });
  })->then (sub {
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is_deeply $result->{json}->{items}, [{
        day => 14774400,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 0,
          value_1 => 551.004,
          value_7 => 551.004,
          value_30 => 551.004,
        }},
      }, {
        day => 24710400,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 0,
          value_1 => 1051.004,
          value_7 => 1051.004,
          value_30 => 1051.004,
        }},
      }, {
        day => 3463430400,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 0,
          value_1 => 3543.553,
          value_7 => 3543.553,
          value_30 => 3543.553,
        }},
      }, {
        day => 3478377600,
        items => {$current->o ('i1')->{nobj_key} => {
          value_all => 0,
          value_1 => -355.3,
          value_7 => -355.3,
          value_30 => -355.3,
        }},
      }];
    } $current->c, name => 'between data';
  });
} n => 4, name => '/stats/post.json (value_all based)';

Test {
  my $current = shift;
  my @data = map { int (rand 100000) } 0..7;
  return $current->create (
    [i1 => nobj => {}],
  )->then (sub {
    return promised_for {
      my $day = shift;
      return $current->json (['stats', 'post.json'], {
        item_nobj_key => $current->o ('i1')->{nobj_key},
        day => 24710400 + $day * 24*60*60,
        value_all => $data[$day],
      });
    } [0..7];
  })->then (sub {
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{items}->[0]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, $data[0];
      is $result->{json}->{items}->[1]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, $data[1];
      is $result->{json}->{items}->[2]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, $data[2];
      is $result->{json}->{items}->[3]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, $data[3];
      is $result->{json}->{items}->[4]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, $data[4];
      is $result->{json}->{items}->[5]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, $data[5];
      is $result->{json}->{items}->[6]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, $data[6];
      is $result->{json}->{items}->[7]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, $data[7] - $data[0];
    } $current->c;
  });
} n => 8, name => 'value_7 (value_all based)';

sub sum (@) { my $x = 0; $x += $_ for @_; return $x }

Test {
  my $current = shift;
  my @data = map { int (rand 100000) } 0..7;
  return $current->create (
    [i1 => nobj => {}],
  )->then (sub {
    return promised_for {
      my $day = shift;
      return $current->json (['stats', 'post.json'], {
        item_nobj_key => $current->o ('i1')->{nobj_key},
        day => 24710400 + $day * 24*60*60,
        value_1 => $data[$day],
      });
    } [0..7];
  })->then (sub {
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{items}->[0]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, sum @data[0];
      is $result->{json}->{items}->[1]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, sum @data[0..1];
      is $result->{json}->{items}->[2]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, sum @data[0..2];
      is $result->{json}->{items}->[3]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, sum @data[0..3];
      is $result->{json}->{items}->[4]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, sum @data[0..4];
      is $result->{json}->{items}->[5]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, sum @data[0..5];
      is $result->{json}->{items}->[6]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, sum @data[0..6];
      is $result->{json}->{items}->[7]->{items}->{$current->o ('i1')->{nobj_key}}->{value_7}, sum @data[1..7];
    } $current->c;
  });
} n => 8, name => 'value_7 (value_1 based)';

Test {
  my $current = shift;
  my @data = map { int (rand 100000) } 0..33;
  return $current->create (
    [i1 => nobj => {}],
  )->then (sub {
    return promised_for {
      my $day = shift;
      return $current->json (['stats', 'post.json'], {
        item_nobj_key => $current->o ('i1')->{nobj_key},
        day => 24710400 + $day * 24*60*60,
        value_all => $data[$day],
      });
    } [0..33];
  })->then (sub {
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{items}->[0]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, $data[0];
      is $result->{json}->{items}->[1]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, $data[1];
      is $result->{json}->{items}->[2]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, $data[2];
      is $result->{json}->{items}->[3]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, $data[3];
      is $result->{json}->{items}->[4]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, $data[4];
      is $result->{json}->{items}->[5]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, $data[5];
      is $result->{json}->{items}->[6]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, $data[6];
      is $result->{json}->{items}->[28]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, $data[28];
      is $result->{json}->{items}->[29]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, $data[29];
      is $result->{json}->{items}->[30]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, $data[30] - $data[0];
      is $result->{json}->{items}->[31]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, $data[31] - $data[1];
      is $result->{json}->{items}->[33]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, $data[33] - $data[3];
    } $current->c;
  });
} n => 12, name => 'value_30 (value_all based)';

Test {
  my $current = shift;
  my @data = map { int (rand 100000) } 0..33;
  return $current->create (
    [i1 => nobj => {}],
  )->then (sub {
    return promised_for {
      my $day = shift;
      return $current->json (['stats', 'post.json'], {
        item_nobj_key => $current->o ('i1')->{nobj_key},
        day => 24710400 + $day * 24*60*60,
        value_1 => $data[$day],
      });
    } [0..33];
  })->then (sub {
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{items}->[0]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, sum @data[0];
      is $result->{json}->{items}->[1]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, sum @data[0..1];
      is $result->{json}->{items}->[2]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, sum @data[0..2];
      is $result->{json}->{items}->[3]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, sum @data[0..3];
      is $result->{json}->{items}->[4]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, sum @data[0..4];
      is $result->{json}->{items}->[5]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, sum @data[0..5];
      is $result->{json}->{items}->[6]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, sum @data[0..6];
      is $result->{json}->{items}->[28]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, sum @data[0..28];
      is $result->{json}->{items}->[29]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, sum @data[0..29];
      is $result->{json}->{items}->[30]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, sum @data[1..30];
      is $result->{json}->{items}->[31]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, sum @data[2..31];
      is $result->{json}->{items}->[33]->{items}->{$current->o ('i1')->{nobj_key}}->{value_30}, sum @data[4..33];
    } $current->c;
  });
} n => 12, name => 'value_30 (value_1 based)';

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
