use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [a1 => account => {}],
    [a2 => account => {}],
    [a3 => account => {}],
    [a4 => account => {}],
    [t1 => nobj => {}],
    [s1 => star => {
      starred => 't1',
      starred_author => 'a1',
      count => 45,
    }],
  )->then (sub {
    return $current->are_errors (
      [['nobj', 'changeauthor.json'], {
        subject_nobj_key => $current->o ('t1')->{nobj_key},
        author_nobj_key => $current->o ('a3')->{nobj_key},
      }],
      [
        {p => {subject_nobj_key => undef}, reason => 'Bad |subject_nobj_key|'},
        {p => {author_nobj_key => undef}, reason => 'Bad |author_nobj_key|'},
        {p => {subject_nobj_key => ''}, reason => 'Bad |subject_nobj_key|'},
        {p => {author_nobj_key => ''}, reason => 'Bad |author_nobj_key|'},
      ],
    );
  })->then (sub {
    return $current->json (['nobj', 'changeauthor.json'], {
      subject_nobj_key => $current->o ('t1')->{nobj_key},
      author_nobj_key => $current->o ('a4')->{nobj_key},
    }, app_id => $current->generate_id (app2 => {})); # no effect
  })->then (sub {
    return $current->json (['nobj', 'changeauthor.json'], {
      subject_nobj_key => $current->o ('t1')->{nobj_key},
      author_nobj_key => $current->o ('a2')->{nobj_key},
    });
  })->then (sub {
    return $current->json (['star', 'list.json'], {
      starred_author_nobj_key => $current->o ('a2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $c = $result->{json}->{items}->[0];
      is $c->{count}, 45;
    } $current->c;
    return $current->json (['star', 'list.json'], {
      starred_author_nobj_key => $current->o ('a1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 0;
    } $current->c;
  });
} n => 4, name => 'author changed - star';

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
