use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

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
    return $current->are_empty (
      [['stats', 'list.json'], {
        item_nobj_key => $current->o ('i1')->{nobj_key},
      }],
      [
        'app_id',
        ['get_nobj', 'item'],
        {p => {min => 4222000002, max => 30}},
      ],
    );
  })->then (sub {
    return $current->are_errors (
      [['stats', 'list.json'], {
        item_nobj_key => $current->o ('i1')->{nobj_key},
      }],
      [
        {p => {limit => 422200}, reason => 'Bad |limit|'},
      ],
    );
  })->then (sub {
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 8;
      is $result->{json}->{items}->[0]->{day}, 24710400;
      is $result->{json}->{items}->[0]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, $data[0];
      is $result->{json}->{items}->[1]->{day}, 24710400 + 24*60*60;
      is $result->{json}->{items}->[1]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, $data[1];
      is $result->{json}->{items}->[2]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, $data[2];
      is $result->{json}->{items}->[3]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, $data[3];
      is $result->{json}->{items}->[4]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, $data[4];
      is $result->{json}->{items}->[5]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, $data[5];
      is $result->{json}->{items}->[6]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, $data[6];
      is $result->{json}->{items}->[7]->{day}, 24710400 + 7*24*60*60;
      is $result->{json}->{items}->[7]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, $data[7];
    } $current->c;
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
      min => 24710400 + 24*60*60,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 7;
      is $result->{json}->{items}->[0]->{day}, 24710400 + 24*60*60;
      is $result->{json}->{items}->[6]->{day}, 24710400 + 7*24*60*60;
    } $current->c;
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
      max => 24710400 + 4*24*60*60,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 5;
      is $result->{json}->{items}->[0]->{day}, 24710400 + 0*24*60*60;
      is $result->{json}->{items}->[4]->{day}, 24710400 + 4*24*60*60;
    } $current->c;
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => $current->o ('i1')->{nobj_key},
      min => 24710400 + 24*60*60,
      limit => 3,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 3;
      is $result->{json}->{items}->[0]->{day}, 24710400 + 1*24*60*60;
      is $result->{json}->{items}->[2]->{day}, 24710400 + 3*24*60*60;
    } $current->c;
  });
} n => 23, name => '/stats/list.json';

Test {
  my $current = shift;
  my @data1 = map { int (rand 100000) } 0..7;
  my @data2 = map { int (rand 100000) } 0..7;
  return $current->create (
    [i1 => nobj => {}],
    [i2 => nobj => {}],
  )->then (sub {
    return promised_for {
      my $day = shift;
      return $current->json (['stats', 'post.json'], {
        item_nobj_key => $current->o ('i1')->{nobj_key},
        day => 24710400 + $day * 24*60*60,
        value_all => $data1[$day],
      });
    } [0..5];
  })->then (sub {
    return promised_for {
      my $day = shift;
      return $current->json (['stats', 'post.json'], {
        item_nobj_key => $current->o ('i2')->{nobj_key},
        day => 24710400 + $day * 24*60*60,
        value_all => $data2[$day],
      });
    } [3, 5, 6, 7];
  })->then (sub {
    return $current->json (['stats', 'list.json'], {
      item_nobj_key => [
        $current->o ('i1')->{nobj_key},
        $current->o ('i2')->{nobj_key},
      ],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 8;
      
      is $result->{json}->{items}->[0]->{day}, 24710400;
      is $result->{json}->{items}->[0]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, $data1[0];
      is $result->{json}->{items}->[0]->{items}->{$current->o ('i2')->{nobj_key}}->{value_all}, undef;
      
      is $result->{json}->{items}->[1]->{day}, 24710400 + 1*24*60*60;
      is $result->{json}->{items}->[1]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, $data1[1];
      is $result->{json}->{items}->[1]->{items}->{$current->o ('i2')->{nobj_key}}->{value_all}, undef;
      
      is $result->{json}->{items}->[2]->{day}, 24710400 + 2*24*60*60;
      is $result->{json}->{items}->[2]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, $data1[2];
      is $result->{json}->{items}->[2]->{items}->{$current->o ('i2')->{nobj_key}}->{value_all}, undef;
      
      is $result->{json}->{items}->[3]->{day}, 24710400 + 3*24*60*60;
      is $result->{json}->{items}->[3]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, $data1[3];
      is $result->{json}->{items}->[3]->{items}->{$current->o ('i2')->{nobj_key}}->{value_all}, $data2[3];
      
      is $result->{json}->{items}->[4]->{day}, 24710400 + 4*24*60*60;
      is $result->{json}->{items}->[4]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, $data1[4];
      is $result->{json}->{items}->[4]->{items}->{$current->o ('i2')->{nobj_key}}->{value_all}, undef;
      
      is $result->{json}->{items}->[5]->{day}, 24710400 + 5*24*60*60;
      is $result->{json}->{items}->[5]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, $data1[5];
      is $result->{json}->{items}->[5]->{items}->{$current->o ('i2')->{nobj_key}}->{value_all}, $data2[5];
      
      is $result->{json}->{items}->[6]->{day}, 24710400 + 6*24*60*60;
      is $result->{json}->{items}->[6]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, undef;
      is $result->{json}->{items}->[6]->{items}->{$current->o ('i2')->{nobj_key}}->{value_all}, $data2[6];
      
      is $result->{json}->{items}->[7]->{day}, 24710400 + 7*24*60*60;
      is $result->{json}->{items}->[7]->{items}->{$current->o ('i1')->{nobj_key}}->{value_all}, undef;
      is $result->{json}->{items}->[7]->{items}->{$current->o ('i2')->{nobj_key}}->{value_all}, $data2[7];
    } $current->c;
  });
} n => 25, name => '/stats/list.json';

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
