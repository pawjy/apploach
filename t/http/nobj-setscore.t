use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [x1 => nobj => {}],
  )->then (sub {
    return $current->json (['nobj', 'setscore.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
      tag_context_nobj_key => $current->o ('x1')->{nobj_key},
      score => 30,
    });
  })->then (sub {
    return $current->json (['nobj', 'setscore.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
      score => 30,
    });
  })->then (sub {
    return $current->json (['nobj', 'setscore.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
      tag_context_nobj_key => $current->o ('x1')->{nobj_key},
      score => 0,
    });
  })->then (sub {
    return $current->json (['nobj', 'setscore.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
      tag_context_nobj_key => rand,
      score => 10,
    });
  })->then (sub {
    return $current->json (['nobj', 'setscore.json'], {
      target_nobj_key => rand,
      tag_context_nobj_key => rand,
      score => 43,
    });
  })->then (sub {
    return $current->json (['nobj', 'setscore.json'], {
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok 1;
    } $current->c;
  });
} n => 1, name => 'noop';

Test {
  my $current = shift;
  return $current->create (
    [i1 => nobj => {}],
    [i2 => nobj => {}],
    [x1 => nobj => {}],
    [x2 => nobj => {}],
    [x3 => nobj => {}],
  )->then (sub {
    return $current->json (['tag', 'publish.json'], {
      context_nobj_key => $current->o ('x1')->{nobj_key},
      tag => [$current->generate_text ('name1' => {}),
              $current->generate_text ('name2' => {})],
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['tag', 'publish.json'], {
      context_nobj_key => $current->o ('x1')->{nobj_key},
      tag => [$current->o ('name1'), $current->o ('name2')],
      item_nobj_key => $current->o ('i2')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['tag', 'publish.json'], {
      context_nobj_key => $current->o ('x2')->{nobj_key},
      tag => [$current->o ('name1')],
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['tag', 'publish.json'], {
      context_nobj_key => $current->o ('x3')->{nobj_key},
      tag => [$current->o ('name1')],
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['nobj', 'setscore.json'], {
      target_nobj_key => $current->o ('i1')->{nobj_key},
      tag_context_nobj_key => [$current->o ('x1')->{nobj_key},
                               rand,
                               $current->o ('x2')->{nobj_key}],
      score => 30,
    });
  })->then (sub {
    return $current->json (['nobj', 'setscore.json'], {
      target_nobj_key => $current->o ('i1')->{nobj_key},
      tag_context_nobj_key => ['', rand],
      score => 130,
    });
  })->then (sub {
    return $current->json (['tag', 'items.json'], {
      context_nobj_key => $current->o ('x1')->{nobj_key},
      tag_name => $current->o ('name1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $item1 = $result->{json}->{items}->[1];
      is $item1->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      is $item1->{score}, 30, 'score updated';
      my $item2 = $result->{json}->{items}->[0];
      is $item2->{item_nobj_key}, $current->o ('i2')->{nobj_key};
      is $item2->{score}, 0, 'score not updated';
    } $current->c;
    return $current->json (['tag', 'items.json'], {
      context_nobj_key => $current->o ('x1')->{nobj_key},
      tag_name => $current->o ('name2'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $item1 = $result->{json}->{items}->[1];
      is $item1->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      is $item1->{score}, 30, 'score updated';
      my $item2 = $result->{json}->{items}->[0];
      is $item2->{item_nobj_key}, $current->o ('i2')->{nobj_key};
      is $item2->{score}, 0, 'score not updated';
    } $current->c;
    return $current->json (['tag', 'items.json'], {
      context_nobj_key => $current->o ('x2')->{nobj_key},
      tag_name => $current->o ('name1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $item1 = $result->{json}->{items}->[0];
      is $item1->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      is $item1->{score}, 30, 'score updated';
    } $current->c;
    return $current->json (['tag', 'items.json'], {
      context_nobj_key => $current->o ('x3')->{nobj_key},
      tag_name => $current->o ('name1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $item1 = $result->{json}->{items}->[0];
      is $item1->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      is $item1->{score}, 0, 'score not updated';
    } $current->c;
  });
} n => 16, name => 'setscore tag item';

RUN;

=head1 LICENSE

Copyright 2018-2019 Wakaba <wakaba@suikawiki.org>.

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
