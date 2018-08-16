use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
  )->then (sub {
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is ref $result->{json}->{tags}, 'HASH';
      is 0+keys %{$result->{json}->{tags}}, 0;
    } $current->c;
  });
} n => 2, name => 'no name';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
  )->then (sub {
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => [
        $current->generate_text (tag1 => {}),
        '',
      ],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{tags}}, 2;
      is $result->{json}->{tags}->{''}->{tag_name}, '';
      is $result->{json}->{tags}->{''}->{canon_tag_name}, '';
      is $result->{json}->{tags}->{''}->{nobj_key}, 'apploach-tag-['.$current->o ('t1')->{nobj_key}.']-';
      is $result->{json}->{tags}->{''}->{count}, 0;
      is $result->{json}->{tags}->{''}->{timestamp}, 0;
      is $result->{json}->{tags}->{''}->{author_status}, 0;
      is $result->{json}->{tags}->{''}->{owner_status}, 0;
      is $result->{json}->{tags}->{''}->{admin_status}, 0;
      is $result->{json}->{tags}->{$current->o ('tag1')}->{tag_name}, $current->o ('tag1');
      is $result->{json}->{tags}->{$current->o ('tag1')}->{canon_tag_name}, $current->o ('tag1');
      like $result->{json}->{tags}->{$current->o ('tag1')}->{nobj_key},
          qr{^apploach-tag-\[\Q@{[$current->o ('t1')->{nobj_key}]}\E\]-.+};
      is $result->{json}->{tags}->{$current->o ('tag1')}->{count}, 0;
      is $result->{json}->{tags}->{$current->o ('tag1')}->{timestamp}, 0;
      is $result->{json}->{tags}->{$current->o ('tag1')}->{author_status}, 0;
      is $result->{json}->{tags}->{$current->o ('tag1')}->{owner_status}, 0;
      is $result->{json}->{tags}->{$current->o ('tag1')}->{admin_status}, 0;
    } $current->c;
  });
} n => 17, name => 'empty';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [tag1 => tag => {context => 't1',
                     tag_name => $current->generate_text (name1 => {}),
                     author_status => 6,
                     owner_status => 12,
                     admin_status => 40}],
  )->then (sub {
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => $current->o ('name1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{tags}}, 1;
      is $result->{json}->{tags}->{$current->o ('name1')}->{tag_name}, $current->o ('name1');
      is $result->{json}->{tags}->{$current->o ('name1')}->{canon_tag_name}, $current->o ('name1');
      like $result->{json}->{tags}->{$current->o ('name1')}->{nobj_key},
          qr{^apploach-tag-\[\Q@{[$current->o ('t1')->{nobj_key}]}\E\]-.+};
      is $result->{json}->{tags}->{$current->o ('name1')}->{count}, 0;
      ok $result->{json}->{tags}->{$current->o ('name1')}->{timestamp};
      is $result->{json}->{tags}->{$current->o ('name1')}->{author_status}, 6;
      is $result->{json}->{tags}->{$current->o ('name1')}->{owner_status}, 12;
      is $result->{json}->{tags}->{$current->o ('name1')}->{admin_status}, 40;
    } $current->c;
  })->then (sub {
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t2')->{nobj_key},
      tag_name => $current->o ('name1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{tags}}, 1;
      is $result->{json}->{tags}->{$current->o ('name1')}->{tag_name}, $current->o ('name1');
      is $result->{json}->{tags}->{$current->o ('name1')}->{canon_tag_name}, $current->o ('name1');
      like $result->{json}->{tags}->{$current->o ('name1')}->{nobj_key},
          qr{^apploach-tag-\[\Q@{[$current->o ('t2')->{nobj_key}]}\E\]-.+};
      is $result->{json}->{tags}->{$current->o ('name1')}->{count}, 0;
      is $result->{json}->{tags}->{$current->o ('name1')}->{timestamp}, 0;
      is $result->{json}->{tags}->{$current->o ('name1')}->{author_status}, 0;
      is $result->{json}->{tags}->{$current->o ('name1')}->{owner_status}, 0;
      is $result->{json}->{tags}->{$current->o ('name1')}->{admin_status}, 0;
    } $current->c;
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => $current->o ('name1'),
    }, app_id => $current->generate_id (id1 => {}));
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{tags}}, 1;
      is $result->{json}->{tags}->{$current->o ('name1')}->{tag_name}, $current->o ('name1');
      is $result->{json}->{tags}->{$current->o ('name1')}->{canon_tag_name}, $current->o ('name1');
      like $result->{json}->{tags}->{$current->o ('name1')}->{nobj_key},
          qr{^apploach-tag-\[\Q@{[$current->o ('t1')->{nobj_key}]}\E\]-.+};
      is $result->{json}->{tags}->{$current->o ('name1')}->{count}, 0;
      is $result->{json}->{tags}->{$current->o ('name1')}->{timestamp}, 0;
      is $result->{json}->{tags}->{$current->o ('name1')}->{author_status}, 0;
      is $result->{json}->{tags}->{$current->o ('name1')}->{owner_status}, 0;
      is $result->{json}->{tags}->{$current->o ('name1')}->{admin_status}, 0;
    } $current->c;
  });
} n => 27, name => 'has props';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [tag1 => tag => {context => 't1',
                     tag_name => $current->generate_text ('name1' => {}),
                     string_data => {
                       abc => 3534,
                       xya => undef,
                       "\x{901}" => '',
                     }}],
  )->then (sub {
    my $result = $_[0];
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => $current->o ('name1'),
      sd => ['abc', 'xya', "\x{901}", 'bar', "abc", 0, ''],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $tag = $result->{json}->{tags}->{$current->o ('name1')};
      is $tag->{string_data}->{abc}, 3534;
      is $tag->{string_data}->{xya}, undef;
      is $tag->{string_data}->{"\x{901}"}, '';
      is $tag->{string_data}->{bar}, undef;
      is $tag->{string_data}->{'0'}, undef;
      is $tag->{string_data}->{''}, undef;
    } $current->c;
  });
} n => 6, name => 'string_data';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [tag1 => tag => {context => 't1',
                     tag_name => $current->generate_text ('name1' => {}),
                     string_data => {
                       abc => 3534,
                       xya => undef,
                       "\x{901}" => '',
                     }}],
    [tag2 => tag => {context => 't1',
                     tag_name => $current->generate_text ('name2' => {}),
                     string_data => {
                       abc => 53,
                       bar => 'foo',
                     },
                     redirect => {
                       to => $current->o ('name1'),
                     }}],
  )->then (sub {
    my $result = $_[0];
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => $current->o ('name2'),
      sd => ['abc', 'xya', "\x{901}", 'foo', "bar", 0, ''],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $tag1 = $result->{json}->{tags}->{$current->o ('name1')};
      my $tag2 = $result->{json}->{tags}->{$current->o ('name2')};
      is $tag1->{tag_name}, $current->o ('name1');
      is $tag1->{canon_tag_name}, $current->o ('name1');
      like $tag1->{nobj_key},
          qr{^apploach-tag-\[\Q@{[$current->o ('t1')->{nobj_key}]}\E\]-.+};
      is $tag1->{author_status}, 0;
      is $tag1->{owner_status}, 0;
      is $tag1->{admin_status}, 0;
      is $tag1->{count}, 0;
      ok $tag1->{timestamp}, 0;
      is $tag1->{string_data}->{abc}, 3534;
      is $tag1->{string_data}->{xya}, undef;
      is $tag1->{string_data}->{"\x{901}"}, '';
      is $tag1->{string_data}->{bar}, undef;
      is $tag1->{string_data}->{'0'}, undef;
      is $tag1->{string_data}->{''}, undef;
      is $tag2->{tag_name}, $current->o ('name2');
      is $tag2->{canon_tag_name}, $current->o ('name1');
      like $tag2->{nobj_key},
          qr{^apploach-tag-\[\Q@{[$current->o ('t1')->{nobj_key}]}\E\]-.+};
      is $tag2->{author_status}, 0;
      is $tag2->{owner_status}, 0;
      is $tag2->{admin_status}, 0;
      is $tag2->{count}, 0;
      ok $tag2->{timestamp}, 0;
      is $tag2->{string_data}->{abc}, 53;
      is $tag2->{string_data}->{xya}, undef;
      is $tag2->{string_data}->{"\x{901}"}, undef;
      is $tag2->{string_data}->{bar}, 'foo';
      is $tag2->{string_data}->{'0'}, undef;
      is $tag2->{string_data}->{''}, undef;
    } $current->c;
  });
} n => 28, name => 'redirect';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [tag1 => tag => {context => 't1',
                     tag_name => $current->generate_text ('name1' => {}),
                     string_data => {
                       abc => 3534,
                       xya => undef,
                       "\x{901}" => '',
                     },
                     redirect => {
                       to => $current->o ('name1'),
                     }}],
  )->then (sub {
    my $result = $_[0];
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      tag_name => $current->o ('name1'),
      sd => ['abc', 'xya', "\x{901}", 'foo', "bar", 0, ''],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $tag1 = $result->{json}->{tags}->{$current->o ('name1')};
      is $tag1->{tag_name}, $current->o ('name1');
      is $tag1->{canon_tag_name}, $current->o ('name1');
      like $tag1->{nobj_key},
          qr{^apploach-tag-\[\Q@{[$current->o ('t1')->{nobj_key}]}\E\]-.+};
      is $tag1->{author_status}, 0;
      is $tag1->{owner_status}, 0;
      is $tag1->{admin_status}, 0;
      is $tag1->{count}, 0;
      ok $tag1->{timestamp}, 0;
      is $tag1->{string_data}->{abc}, 3534;
      is $tag1->{string_data}->{xya}, undef;
      is $tag1->{string_data}->{"\x{901}"}, '';
      is $tag1->{string_data}->{bar}, undef;
      is $tag1->{string_data}->{'0'}, undef;
      is $tag1->{string_data}->{''}, undef;
    } $current->c;
  });
} n => 14, name => 'self redirect';

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
