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
      [['fetch', 'enqueue.json'], {
        options => {
          url => $current->generate_push_url ('e1' => {}),
        },
      }],
      [
        ['json', 'options'],
        {p => {options => {url => 'foo/bar'}}, reason => 'Bad |url|'},
        {p => {options => {url => 'about:blank'}}, reason => 'Bad |url|'},
        {p => {options => {url => 'javascript:bar'}}, reason => 'Bad |url|'},
        {p => {options => {url => 'ftp://bar.baz/'}}, reason => 'Bad |url|'},
        {p => {options => {url => 'https://bar.baz/',
                           method => 'get'}}, reason => 'Bad |method|'},
        {p => {options => {url => 'https://bar.baz/',
                           method => 'OPTIONS'}}, reason => 'Bad |method|'},
      ],
    );
  })->then (sub {
    return $current->json (['fetch', 'enqueue.json'], {
      options => {
        url => $current->generate_push_url ('e2' => {}),
      },
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{job_id};
      like $result->{res}->body_bytes, qr{"job_id":"};
    } $current->c;
  })->then (sub {
    my $url = Web::URL->parse_string ($current->o ('e2'));
    return $current->wait_for_count ($url, 1);
  })->then (sub {
    my $json = $_[0];
    test {
      is $json->{get_count}, 1;
      is $json->{post_count}, 0;
    } $current->c;
  })->then (sub {
    my $url = Web::URL->parse_string ($current->o ('e1'));
    return $current->wait_for_count ($url, 0);
  })->then (sub {
    my $json = $_[0];
    test {
      is $json->{count}, 0, 'error requests should not insert fetches';
    } $current->c;
  });
} n => 6, name => 'enqueue';

Test {
  my $current = shift;
  return $current->create (
  )->then (sub {
    return $current->json (['fetch', 'enqueue.json'], {
      options => {
        url => $current->generate_push_url ('e2' => {}),
        method => 'POST',
      },
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{job_id};
      like $result->{res}->body_bytes, qr{"job_id":"};
    } $current->c;
  })->then (sub {
    my $url = Web::URL->parse_string ($current->o ('e2'));
    return $current->wait_for_count ($url, 1);
  })->then (sub {
    my $json = $_[0];
    test {
      is $json->{get_count}, 0;
      is $json->{post_count}, 1;
    } $current->c;
  });
} n => 4, name => 'POST';

Test {
  my $current = shift;
  return $current->create (
  )->then (sub {
    return $current->json (['fetch', 'enqueue.json'], {
      options => {
        url => $current->generate_push_url ('e1' => {}),
        method => 'POST',
      },
      after => time + 3000,
    });
  })->then (sub {
    return $current->json (['fetch', 'enqueue.json'], {
      options => {
        url => $current->generate_push_url ('e2' => {}),
        method => 'POST',
      },
      after => time - 3000,
    });
  })->then (sub {
    my $url = Web::URL->parse_string ($current->o ('e1'));
    return $current->wait_for_count ($url, 0);
  })->then (sub {
    my $json = $_[0];
    test {
      is $json->{count}, 0, 'future fetch';
    } $current->c;
    my $url = Web::URL->parse_string ($current->o ('e2'));
    return $current->wait_for_count ($url, 1);
  })->then (sub {
    my $json = $_[0];
    test {
      is $json->{count}, 1, 'past';
    } $current->c;
  });
} n => 2, name => 'time after';

RUN;

=head1 LICENSE

Copyright 2022 Wakaba <wakaba@suikawiki.org>.

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
