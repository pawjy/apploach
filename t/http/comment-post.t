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
      is $c->{data}->{modified}, $c->{data}->{timestamp};
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
} n => 16, name => 'post.json';

Test {
  my $current = shift;
  return $current->create (
    [thread1 => nobj => {}],
    [u1 => account => {}],
    [u2 => account => {}],
    [u3 => account => {}],
    [u4 => account => {}],
    ['thread1-posted' => nobj => {}],
    ['thread1-members' => nobj => {}],
  )->then (sub {
    return $current->create (
      [sub02 => topic_subscription => {
        topic => 'thread1-members',
        subscriber => 'u2',
        status => 4, # inherit
        channel_nobj_key => 'apploach-any-channel',
      }],
      [sub03 => topic_subscription => {
        topic => 'thread1-members',
        subscriber => 'u3',
        status => 4, # inherit
        channel_nobj_key => 'apploach-any-channel',
      }],
      [sub04 => topic_subscription => {
        topic => 'thread1-members',
        subscriber => 'u4',
        status => 4, # inherit
        channel_nobj_key => 'apploach-any-channel',
      }],
      [sub2 => topic_subscription => {
        topic_nobj_key => $current->o ('u2')->{nobj_key} . '-any',
        subscriber => 'u2',
      }],
      [sub3 => topic_subscription => {
        topic_nobj_key => $current->o ('u3')->{nobj_key} . '-any',
        subscriber => 'u3',
      }],
      [sub4 => topic_subscription => {
        topic_nobj_key => $current->o ('u3')->{nobj_key} . '-any',
        subscriber => 'u4',
        status => 3, # disabled
      }],
    );
  })->then (sub {
    return $current->json (['comment', 'post.json'], {
      thread_nobj_key => $current->o ('thread1')->{nobj_key},
      data => '{"a":5}',
      internal_data => '{"c":6}',
      author_nobj_key => $current->o ('u1')->{nobj_key},
      author_status => 14,
      owner_status => 2,
      admin_status => 3,
      notification_topic_nobj_key => $current->o ('thread1-posted')->{nobj_key},
      notification_topic_fallback_nobj_key => [
        $current->o ('thread1-members')->{nobj_key},
      ],
      notification_topic_fallback_nobj_key_template => [
        '{subscriber}-any',
      ],
    });
  })->then (sub {
    my $result = $_[0];
    $current->set_o (m1 => $result->{json});
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{data}->{author_nobj_key}, $current->o ('u1')->{nobj_key};
      is $v->{data}->{thread_nobj_key}, $current->o ('thread1')->{nobj_key};
      is $v->{data}->{comment_id}, $current->o ('m1')->{comment_id};
      ok $v->{data}->{timestamp};
    } $current->c;
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u3')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $v = $result->{json}->{items}->[0];
      is $v->{data}->{author_nobj_key}, $current->o ('u1')->{nobj_key};
      is $v->{data}->{thread_nobj_key}, $current->o ('thread1')->{nobj_key};
      is $v->{data}->{comment_id}, $current->o ('m1')->{comment_id};
      ok $v->{data}->{timestamp};
    } $current->c;
    return $current->json (['notification', 'nevent', 'list.json'], {
      subscriber_nobj_key => $current->o ('u4')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c;
  });
} n => 11, name => 'notifications';

Test {
  my $current = shift;
  return $current->create (
    [u1 => account => {}],
  )->then (sub {
    return $current->json (['comment', 'post.json'], {
      thread_nobj_key => $current->o ('u1')->{nobj_key},
      data => {},
      internal_data => {},
      author_nobj_key => $current->o ('u1')->{nobj_key},
      author_status => 14,
      owner_status => 2,
      admin_status => 3,
    });
  })->then (sub {
    my $result = $_[0];
    $current->set_o (m1 => $result->{json});
    return $current->json (['comment', 'list.json'], {
      comment_id => $current->o ('m1')->{comment_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{thread_nobj_key}, $current->o ('u1')->{nobj_key};
      is $c->{author_nobj_key}, $current->o ('u1')->{nobj_key};
    } $current->c;
    return $current->json (['comment', 'list.json'], {
      thread_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{thread_nobj_key}, $current->o ('u1')->{nobj_key};
      is $c->{author_nobj_key}, $current->o ('u1')->{nobj_key};
    } $current->c;
  });
} n => 6, name => 'same nobjs';

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
