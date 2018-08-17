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
    return $current->are_errors (
      [['tag', 'publish.json'], {
        context_nobj_key => $current->o ('t1')->{nobj_key},
        tag => $current->generate_text (rand, {}),
        item_nobj_key => $current->o ('i1')->{nobj_key},
      }],
      [
        ['new_nobj', 'context'],
        ['new_nobj', 'item'],
      ],
    );
  })->then (sub {
    return $current->json (['tag', 'publish.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag => [
        $current->generate_text ('name1' => {}),
        $current->generate_text ('name2' => {}),
      ],
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
    return $current->json (['tag', 'items.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => $current->o ('name2'),
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
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => [$current->o ('name1'), $current->o ('name2')],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{tags}}, 2;
      my $item = $result->{json}->{tags}->{$current->o ('name1')};
      is $item->{count}, 1;
      is $item->{author_status}, 0;
      is $item->{owner_status}, 0;
      is $item->{admin_status}, 0;
      ok $item->{timestamp};
      my $item2 = $result->{json}->{tags}->{$current->o ('name2')};
      is $item2->{count}, 1;
      is $item2->{author_status}, 0;
      is $item2->{owner_status}, 0;
      is $item2->{admin_status}, 0;
      ok $item2->{timestamp};
    } $current->c;
  });
} n => 20, name => 'implied tags';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [i1 => nobj => {}],
    [tag1 => tag => {context => 't1',
                     tag_name => $current->generate_text (name1 => {}),
                     author_status => 5,
                     owner_status => 6,
                     admin_status => 7,
                     redirect => {
                       to => $current->generate_text (name2 => {}),
                     }}],
  )->then (sub {
    return $current->json (['tag', 'publish.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag => [
        $current->o ('name1'),
      ],
      item_nobj_key => $current->o ('i1')->{nobj_key},
      score => 5000,
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
      is $item->{score}, 5000;
    } $current->c;
    return $current->json (['tag', 'items.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => $current->o ('name2'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $item = $result->{json}->{items}->[0];
      is $item->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      ok $item->{timestamp};
      is $item->{score}, 5000;
    } $current->c;
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => [$current->o ('name1'), $current->o ('name2')],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{tags}}, 2;
      my $item = $result->{json}->{tags}->{$current->o ('name1')};
      is $item->{count}, 1;
      is $item->{author_status}, 5;
      is $item->{owner_status}, 6;
      is $item->{admin_status}, 7;
      ok $item->{timestamp};
      my $item2 = $result->{json}->{tags}->{$current->o ('name2')};
      is $item2->{count}, 0;
      is $item2->{author_status}, 0;
      is $item2->{owner_status}, 0;
      is $item2->{admin_status}, 0;
      ok $item2->{timestamp};
    } $current->c;
  });
} n => 19, name => 'redirected tags';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [i1 => nobj => {}],
    [tag1 => tag => {context => 't1',
                     tag_name => "\x{FF56}",
                     author_status => 5,
                     owner_status => 6,
                     admin_status => 7}],
  )->then (sub {
    return $current->json (['tag', 'publish.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag => "\x{FF56}",
      item_nobj_key => $current->o ('i1')->{nobj_key},
      score => 5000,
    });
  })->then (sub {
    return $current->json (['tag', 'items.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => "\x{FF56}",
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $item = $result->{json}->{items}->[0];
      is $item->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      ok $item->{timestamp};
      is $item->{score}, 5000;
    } $current->c;
    return $current->json (['tag', 'items.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => "\x76",
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $item = $result->{json}->{items}->[0];
      is $item->{item_nobj_key}, $current->o ('i1')->{nobj_key};
      ok $item->{timestamp};
      is $item->{score}, 5000;
    } $current->c;
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => ["\x{FF56}", "\x76"],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{tags}}, 2;
      my $item = $result->{json}->{tags}->{"\x{FF56}"};
      is $item->{count}, 1;
      is $item->{author_status}, 5;
      is $item->{owner_status}, 6;
      is $item->{admin_status}, 7;
      ok $item->{timestamp};
      my $item2 = $result->{json}->{tags}->{"\x76"};
      is $item2->{count}, 0;
      is $item2->{author_status}, 0;
      is $item2->{owner_status}, 0;
      is $item2->{admin_status}, 0;
      ok $item2->{timestamp};
    } $current->c;
  });
} n => 19, name => 'normalized tags';

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
