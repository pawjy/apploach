use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [i1 => nobj => {}],
  )->then (sub {
    return $current->json (['tag', 'publish.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag => $current->generate_text ('name1' => {}),
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['tag', 'items.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => $current->o ('name1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $item = $result->{json}->{items}->[0];
      is $item->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      ok $item->{timestamp};
      is $item->{score}, 0;
    } $current->c;
  });
} n => 4, name => 'implied tag items';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [i1 => nobj => {}],
    [i2 => nobj => {}],
    [tag1 => tag => {context => 't1',
                     tag_name => $current->generate_text (name1 => {}),
                     redirect => {
                       to => $current->generate_text (name2 => {}),
                     }}],
  )->then (sub {
    return $current->json (['tag', 'publish.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag => $current->o ('name1'),
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['tag', 'publish.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag => $current->o ('name2'),
      item_nobj_key => $current->o ('i2')->{nobj_key},
    });
  })->then (sub {
    return $current->are_empty (
      [['tag', 'items.json'], {
        context_nobj_key => $current->o ('t1')->{nobj_key},
        tag_name => $current->o ('name1'),
      }],
      [
        ['get_nobj', 'context'],
        'app_id',
        {params => {
          context_nobj_key => $current->o ('t1')->{nobj_key},
        }, name => 'no |tag_name|'},
      ],
    );
  })->then (sub {
    return $current->json (['tag', 'items.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => $current->o ('name1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $item1 = $result->{json}->{items}->[1];
      is $item1->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      my $item2 = $result->{json}->{items}->[0];
      is $item2->{item_nobj_key}, $current->o ('i2')->{nobj_key};
    } $current->c;
    return $current->json (['tag', 'items.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => $current->o ('name2'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $item1 = $result->{json}->{items}->[1];
      is $item1->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      my $item2 = $result->{json}->{items}->[0];
      is $item2->{item_nobj_key}, $current->o ('i2')->{nobj_key};
    } $current->c;
  });
} n => 7, name => 'redirected tag items';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [i5 => nobj => {}],
    [i4 => nobj => {}],
    [i3 => nobj => {}],
    [i2 => nobj => {}],
    [i1 => nobj => {}],
  )->then (sub {
    $current->generate_text (name1 => {});
    return promised_for {
      my $tag = shift;
      return $current->json (['tag', 'publish.json'], {
        context_nobj_key => $current->o ('t1')->{nobj_key},
        tag => $current->o ('name1'),
        item_nobj_key => $current->o ($tag)->{nobj_key},
      });
    } ['i1', 'i4', 'i5', 'i2', 'i3'];
  })->then (sub {
    return $current->pages_ok ([['tag', 'items.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => $current->o ('name1'),
    }] => ['i1', 'i4', 'i5', 'i2', 'i3'], 'item_nobj_key');
  })->then (sub {
    return promised_for {
      my $tag = shift;
      return $current->json (['nobj', 'touch.json'], {
        target_nobj_key => $current->o ($tag)->{nobj_key},
      });
    } ['i3', 'i2', 'i4', 'i5', 'i1'];
  })->then (sub {
    return $current->pages_ok ([['tag', 'items.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => $current->o ('name1'),
    }] => ['i3', 'i2', 'i4', 'i5', 'i1'], 'item_nobj_key');
  });
} n => 2, name => 'pages';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [i5 => nobj => {}],
    [i4 => nobj => {}],
    [i3 => nobj => {}],
    [i2 => nobj => {}],
    [i1 => nobj => {}],
  )->then (sub {
    $current->generate_text (name1 => {});
    my $i = 0;
    return promised_for {
      my $tag = shift;
      return $current->json (['tag', 'publish.json'], {
        context_nobj_key => $current->o ('t1')->{nobj_key},
        tag => $current->o ('name1'),
        item_nobj_key => $current->o ($tag)->{nobj_key},
        score => $i++,
      });
    } ['i1', 'i4', 'i5', 'i2', 'i3'];
  })->then (sub {
    return promised_for {
      my $tag = shift;
      return $current->json (['nobj', 'touch.json'], {
        target_nobj_key => $current->o ($tag)->{nobj_key},
      });
    } ['i3', 'i2', 'i4', 'i5', 'i1'];
  })->then (sub {
    return $current->json (['tag', 'items.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => $current->o ('name1'),
      score => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 5;
      my $item1 = $result->{json}->{items}->[0];
      is $item1->{item_nobj_key}, $current->o ('i3')->{nobj_key};
      my $item2 = $result->{json}->{items}->[1];
      is $item2->{item_nobj_key}, $current->o ('i2')->{nobj_key};
      my $item3 = $result->{json}->{items}->[2];
      is $item3->{item_nobj_key}, $current->o ('i5')->{nobj_key};
      my $item4 = $result->{json}->{items}->[3];
      is $item4->{item_nobj_key}, $current->o ('i4')->{nobj_key};
      my $item5 = $result->{json}->{items}->[4];
      is $item5->{item_nobj_key}, $current->o ('i1')->{nobj_key};
    } $current->c;
  });
} n => 6, name => 'score';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [i1 => nobj => {}],
    [i2 => nobj => {}],
  )->then (sub {
    return $current->json (['tag', 'publish.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag => [
        $current->generate_text ('name1' => {}),
        $current->generate_text ('name2' => {}),
      ],
      item_nobj_key => $current->o ('i1')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['tag', 'publish.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag => $current->o ('name2'),
      item_nobj_key => $current->o ('i2')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['tag', 'items.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => [
        $current->o ('name1'),
        $current->o ('name2'),
        $current->generate_text ('name3' => {}),
      ],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $item1 = $result->{json}->{items}->[0];
      is $item1->{item_nobj_key}, $current->o ('i2')->{nobj_key};
      ok $item1->{timestamp};
      my $item2 = $result->{json}->{items}->[1];
      is $item2->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      ok $item2->{timestamp};
    } $current->c;
  });
} n => 5, name => 'multiple tag_name parameters';

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
