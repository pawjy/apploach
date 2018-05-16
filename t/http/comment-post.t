use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->are_errors (
    [['comment', 'post.json'], {
      thread_nobj_key => $current->generate_key (key1 => {}),
      data => '{"a":5}',
      internal_data => '{"c":6}',
      author_nobj_key => $current->generate_key (uid1 => {}),
      author_status => 14,
      owner_status => 2,
      admin_status => 3,
    }],
    [
      ['new_nobj', 'thread'],
      ['new_nobj', 'author'],
      ['json', 'data'],
      ['json', 'internal_data'],
      'status',
    ],
  )->then (sub {
    return $current->json (['comment', 'post.json'], {
      thread_nobj_key => $current->o ('key1'),
      data => '{"a":5}',
      internal_data => '{"c":6}',
      author_nobj_key => $current->o ('uid1'),
      author_status => 14,
      owner_status => 2,
      admin_status => 3,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{comment_id};
      ok $result->{json}->{timestamp};
      has_json_string $result, 'comment_id';
      $current->set_o (c1 => $result->{json});
    } $current->c;
    return $current->json (['comment', 'list.json'], {
      comment_id => $current->o ('c1')->{comment_id},
      with_internal_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{comment_id}, $current->o ('c1')->{comment_id};
      is $c->{data}->{timestamp}, $current->o ('c1')->{timestamp};
      is $c->{author_nobj_key}, $current->o ('uid1');
      is $c->{thread_nobj_key}, $current->o ('key1');
      is $c->{data}->{a}, 5;
      is $c->{internal_data}->{c}, 6;
      is $c->{author_status}, 14;
      is $c->{owner_status}, 2;
      is $c->{admin_status}, 3;
      has_json_string $result, 'comment_id';
    } $current->c;
  });
} n => 15, name => 'post.json';

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
