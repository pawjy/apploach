use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
  )->then (sub {
    return $current->are_errors (
      [['notification', 'send', 'push.json'], {
        url => [$current->generate_push_url ('e1' => {})],
      }],
      [
        {p => {url => 'abo/cd/k'}, reason => 'Bad |url|'},
        {p => {url => 'about:blank'}, reason => 'Bad |url|'},
        {p => {url => 'javascript:'}, reason => 'Bad |url|'},
        {p => {url => 'ftp://foo.test/aa'}, reason => 'Bad |url|'},
      ],
    );
  })->then (sub {
    return $current->json (['notification', 'send', 'push.json'], {
      url => [$current->generate_push_url ('e1' => {})],
    });
  })->then (sub {
    my $url = Web::URL->parse_string ($current->o ('e1'));
    return $current->client_for ($url)->request (url => $url);
  })->then (sub {
    my $res = $_[0];
    die $res unless $res->status == 200;
    test {
      my $json = json_bytes2perl $res->body_bytes;
      is $json->{count}, 1;
    } $current->c;
    return $current->json (['notification', 'send', 'push.json'], {
      url => [$current->generate_push_url ('e2' => {}),
              $current->o ('e1')],
    });
  })->then (sub {
    my $url = Web::URL->parse_string ($current->o ('e1'));
    return $current->client_for ($url)->request (url => $url);
  })->then (sub {
    my $res = $_[0];
    die $res unless $res->status == 200;
    test {
      my $json = json_bytes2perl $res->body_bytes;
      is $json->{count}, 2;
    } $current->c;
  });
} n => 3, name => 'push';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [t2 => nobj => {}],
    [c1 => nobj => {}],
    [u1 => nobj => {}],
    [sub1 => topic_subscription => {
      topic => 't1', channel => 'c1', subscriber => 'u1',
      status => 2, data => {foo => 54},
    }],
    [ev1 => nevent => {
      topic => 't1', data => {abv => 774},
    }],
  )->then (sub {
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    return $current->json (['notification', 'send', 'push.json'], {
      url => [$current->generate_push_url (e1 => {}),
              $current->generate_url (e2 => {})],
      nevent_channel_nobj_key => $current->o ('c1')->{nobj_key},
      nevent_subscriber_nobj_key => $current->o ('u1')->{nobj_key},
      nevent_id => $result->{json}->{nevent_id},
    });
  })->then (sub {
    return $current->json (['notification', 'nevent', 'lockqueued.json'], {
      channel_nobj_key => $current->o ('c1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c;
  });
} n => 1, name => 'push & done';

RUN;

=head1 LICENSE

Copyright 2019 Wakaba <wakaba@suikawiki.org>.

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
