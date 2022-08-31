use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
  )->then (sub {
    return $current->json (['fetch', 'enqueue.json'], {
      options => {
        url => $current->generate_push_url ('e2' => {}),
      },
      after => time + 3000,
    });
  })->then (sub {
    my $result = $_[0];
    $current->set_o (j1 => $result->{json});
    return $current->are_errors (
      [['fetch', 'cancel.json'], {
        job_id => $current->o ('j1')->{job_id},
      }],
      [
      ],
    );
  })->then (sub {
    return $current->json (['fetch', 'cancel.json'], {
      job_id => $current->o ('j1')->{job_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok defined $result->{json}->{running_since};
    } $current->c;
    my $url = Web::URL->parse_string ($current->o ('e2'));
    return $current->wait_for_count ($url, 0);
  })->then (sub {
    my $json = $_[0];
    test {
      is $json->{count}, 0;
    } $current->c;
    return $current->json (['fetch', 'cancel.json'], {
      job_id => $current->o ('j1')->{job_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{running_since}, undef, 'already canceled';
    } $current->c;
    return $current->json (['fetch', 'cancel.json'], {
      job_id => rand,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{running_since}, undef, 'job not found';
    } $current->c;
  });
} n => 5, name => 'cancel';

Test {
  my $current = shift;
  return $current->create (
  )->then (sub {
    return $current->json (['fetch', 'enqueue.json'], {
      options => {
        url => $current->generate_push_url ('e1' => {}),
      },
      after => time + 10,
    });
  })->then (sub {
    my $result = $_[0];
    $current->set_o (j1 => $result->{json});
    return $current->json (['fetch', 'cancel.json'], {
      job_id => $current->o ('j1')->{job_id},
    }, app_id => 12345);
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{running_since}, undef;
    } $current->c;
  })->then (sub {
    my $url = Web::URL->parse_string ($current->o ('e1'));
    return $current->wait_for_count ($url, 1);
  })->then (sub {
    my $json = $_[0];
    test {
      is $json->{count}, 1, 'different app_id not affected';
    } $current->c;
  });
} n => 2, name => 'app_id';

Test {
  my $current = shift;
  return $current->create (
  )->then (sub {
    return $current->json (['fetch', 'enqueue.json'], {
      options => {
        url => $current->generate_push_url ('e1' => {}),
      },
    });
  })->then (sub {
    my $result = $_[0];
    $current->set_o (j1 => $result->{json});
    my $url = Web::URL->parse_string ($current->o ('e1'));
    return $current->wait_for_count ($url, 1);
  })->then (sub {
    return $current->json (['fetch', 'cancel.json'], {
      job_id => $current->o ('j1')->{job_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{running_since}, undef, 'cancel after completion';
    } $current->c;
  })->then (sub {
    my $url = Web::URL->parse_string ($current->o ('e1'));
    return $current->wait_for_count ($url, 1);
  })->then (sub {
    my $json = $_[0];
    test {
      is $json->{count}, 1;
    } $current->c;
  });
} n => 2, name => 'cancel after completion';

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
