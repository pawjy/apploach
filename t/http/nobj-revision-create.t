use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [a1 => nobj => {}],
    [a2 => nobj => {}],
  )->then (sub {
    return $current->are_errors (
      [['nobj', 'revision', 'create.json'], {
        target_nobj_key => $current->o ('t1')->{nobj_key},
        author_nobj_key => $current->o ('a1')->{nobj_key},
        operator_nobj_key => $current->o ('a2')->{nobj_key},
        summary_data => {x => 8},
        data => {y => 9},
        revision_data => {z => 10},
        author_status => 4,
        owner_status => 5,
        admin_status => 6,
      }],
      [
        ['new_nobj', 'target'],
        ['new_nobj', 'author'],
        ['new_nobj', 'operator'],
        ['json', 'summary_data'],
        ['json', 'data'],
        ['json', 'revision_data'],
        'status',
      ]
    );
  })->then (sub {
    return $current->json (['nobj', 'revision', 'create.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
      author_nobj_key => $current->o ('a1')->{nobj_key},
      operator_nobj_key => $current->o ('a2')->{nobj_key},
      summary_data => {x => 8},
      data => {y => 9},
      revision_data => {z => 10},
      author_status => 4,
      owner_status => 5,
      admin_status => 6,
    });
  })->then (sub {
    $current->set_o (rev1 => $_[0]->{json});
    test {
      ok $current->o ('rev1')->{timestamp};
    } $current->c;
    return $current->json (['nobj', 'revision', 'list.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
      with_summary_data => 1,
      with_data => 1,
      with_revision_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $rev = $result->{json}->{items}->[0];
      is $rev->{revision_id}, $current->o ('rev1')->{revision_id};
      like $result->{res}->body_bytes, qr{"revision_id"\s*:\s*"};
      is $rev->{timestamp}, $current->o ('rev1')->{timestamp};
      is $rev->{target_nobj_key}, $current->o ('t1')->{nobj_key};
      is $rev->{author_nobj_key}, $current->o ('a1')->{nobj_key};
      is $rev->{operator_nobj_key}, $current->o ('a2')->{nobj_key};
      is $rev->{summary_data}->{x}, 8;
      is $rev->{data}->{y}, 9;
      is $rev->{revision_data}->{z}, 10;
      is $rev->{author_status}, 4;
      is $rev->{owner_status}, 5;
      is $rev->{admin_status}, 6;
    } $current->c;
  });
} n => 15, name => 'create';

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
