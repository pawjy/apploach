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
    [rev1 => revision => {
      target => 't1', author => 'a1', operator => 'a2',
      summary_data => {x => 8},
      data => {y => 9},
      revision_data => {z => 10},
      author_status => 4,
      owner_status => 5,
      admin_status => 6,
    }],
  )->then (sub {
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
    } $current->c, name => 'with_ all';
    return $current->json (['nobj', 'revision', 'list.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
      with_summary_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $rev = $result->{json}->{items}->[0];
      is $rev->{revision_id}, $current->o ('rev1')->{revision_id};
      is $rev->{timestamp}, $current->o ('rev1')->{timestamp};
      is $rev->{target_nobj_key}, $current->o ('t1')->{nobj_key};
      is $rev->{author_nobj_key}, $current->o ('a1')->{nobj_key};
      is $rev->{operator_nobj_key}, $current->o ('a2')->{nobj_key};
      is $rev->{summary_data}->{x}, 8;
      is $rev->{data}, undef;
      is $rev->{revision_data}, undef;
      is $rev->{author_status}, 4;
      is $rev->{owner_status}, 5;
      is $rev->{admin_status}, 6;
    } $current->c, name => 'with_summary_data only';
    return $current->json (['nobj', 'revision', 'list.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
      with_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $rev = $result->{json}->{items}->[0];
      is $rev->{revision_id}, $current->o ('rev1')->{revision_id};
      is $rev->{timestamp}, $current->o ('rev1')->{timestamp};
      is $rev->{target_nobj_key}, $current->o ('t1')->{nobj_key};
      is $rev->{author_nobj_key}, $current->o ('a1')->{nobj_key};
      is $rev->{operator_nobj_key}, $current->o ('a2')->{nobj_key};
      is $rev->{summary_data}, undef;
      is $rev->{data}->{y}, 9;
      is $rev->{revision_data}, undef;
      is $rev->{author_status}, 4;
      is $rev->{owner_status}, 5;
      is $rev->{admin_status}, 6;
    } $current->c, name => 'with_data only';
    return $current->json (['nobj', 'revision', 'list.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
      with_revision_data => 1,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $rev = $result->{json}->{items}->[0];
      is $rev->{revision_id}, $current->o ('rev1')->{revision_id};
      is $rev->{timestamp}, $current->o ('rev1')->{timestamp};
      is $rev->{target_nobj_key}, $current->o ('t1')->{nobj_key};
      is $rev->{author_nobj_key}, $current->o ('a1')->{nobj_key};
      is $rev->{operator_nobj_key}, $current->o ('a2')->{nobj_key};
      is $rev->{summary_data}, undef;
      is $rev->{data}, undef;
      is $rev->{revision_data}->{z}, 10;
      is $rev->{author_status}, 4;
      is $rev->{owner_status}, 5;
      is $rev->{admin_status}, 6;
    } $current->c, name => 'with_data only';
  });
} n => 46, name => 'revision props';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [a1 => nobj => {}],
    [a2 => nobj => {}],
    [rev1 => revision => {
      target => 't1', author => 'a1', operator => 'a2',
    }],
    [rev2 => revision => {
      target => 't1', author => 'a2', operator => 'a1',
    }],
  )->then (sub {
    return $current->are_errors (
      [['nobj', 'revision', 'list.json'], {}],
      [
        {params => {}, name => 'no params', reason => 'Either target or |revision_id| is required'},
      ],
    );
  })->then (sub {
    return $current->are_empty (
      [['nobj', 'revision', 'list.json'], {
        target_nobj_key => $current->o ('t1')->{nobj_key},
      }],
      [
        'app_id',
        {params => {
          target_nobj_key => $current->o ('a1')->{nobj_key},
        }, name => 'not target 1 (found)'},
        {params => {
          target_nobj_key => rand,
        }, name => 'not target 2 (not found)'},
        ['get_nobj', 'target'],
      ],
    );
  })->then (sub {
    return $current->json (['nobj', 'revision', 'list.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $rev1 = $result->{json}->{items}->[1];
      is $rev1->{revision_id}, $current->o ('rev1')->{revision_id};
      my $rev2 = $result->{json}->{items}->[0];
      is $rev2->{revision_id}, $current->o ('rev2')->{revision_id};
    } $current->c;
  });
} n => 5, name => 'list by target';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [a1 => nobj => {}],
    [a2 => nobj => {}],
    [rev1 => revision => {
      target => 't1', author => 'a1', operator => 'a2',
    }],
  )->then (sub {
    return $current->are_empty (
      [['nobj', 'revision', 'list.json'], {}],
      [
        {params => {
          revision_id => rand,
        }, name => 'Bad |revision_id| 1'},
        {params => {
          revision_id => $current->o ('rev1')->{revision_id} . '33',
        }, name => 'Bad |revision_id| 2'},
        {params => {
          target_nobj_key => $current->o ('a1')->{nobj_key},
          revision_id => $current->o ('rev1')->{revision_id},
        }, name => 'Bad target |revision_id| combination (found)'},
        {params => {
          target_nobj_key => rand,
          revision_id => $current->o ('rev1')->{revision_id},
        }, name => 'Bad target |revision_id| combination (not found)'},
      ],
    );
  })->then (sub {
    return $current->json (['nobj', 'revision', 'list.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
      revision_id => $current->o ('rev1')->{revision_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $rev1 = $result->{json}->{items}->[0];
      is $rev1->{revision_id}, $current->o ('rev1')->{revision_id};
    } $current->c, name => 'target and revision_id';
    return $current->json (['nobj', 'revision', 'list.json'], {
      revision_id => $current->o ('rev1')->{revision_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $rev1 = $result->{json}->{items}->[0];
      is $rev1->{revision_id}, $current->o ('rev1')->{revision_id};
    } $current->c, name => 'revision_id only';
  });
} n => 5, name => 'list by revision_id';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [rev1 => revision => {
      target => 't1',
      author_status => 2,
      owner_status => 4,
      admin_status => 5,
    }],
    [rev2 => revision => {
      target => 't1',
      author_status => 10,
      owner_status => 7,
      admin_status => 2,
    }],
    [rev3 => revision => {
      target => 't1',
      author_status => 7,
      owner_status => 4,
      admin_status => 10,
    }],
  )->then (sub {
    return $current->json (['nobj', 'revision', 'list.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
      admin_status => [5, 10],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 2;
      my $rev1 = $result->{json}->{items}->[0];
      is $rev1->{revision_id}, $current->o ('rev3')->{revision_id};
      my $rev2 = $result->{json}->{items}->[1];
      is $rev2->{revision_id}, $current->o ('rev1')->{revision_id};
    } $current->c;
    return $current->json (['nobj', 'revision', 'list.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
      author_status => 7,
      owner_status => 4,
      admin_status => 10,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $rev1 = $result->{json}->{items}->[0];
      is $rev1->{revision_id}, $current->o ('rev3')->{revision_id};
    } $current->c;
  });
} n => 5, name => 'status filters';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [c1 => revision => {target => 't1'}],
    [c2 => revision => {target => 't1'}],
    [c3 => revision => {target => 't1'}],
    [c4 => revision => {target => 't1'}],
    [c5 => revision => {target => 't1'}],
  )->then (sub {
    return $current->pages_ok ([['nobj', 'revision', 'list.json'], {
      target_nobj_key => $current->o ('t1')->{nobj_key},
    }] => ['c1', 'c2', 'c3', 'c4', 'c5'], 'revision_id');
  });
} n => 1, name => 'pager paging';

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
