use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [u1 => nobj => {}],
  )->then (sub {
    return $current->are_errors (
      [['tag', 'edit.json'], {
        context_nobj_key => $current->o ('t1')->{nobj_key},
        name => $current->generate_text (x2 => {}),
        operator_nobj_key => $current->o ('u1')->{nobj_key},
      }],
      [
        ['new_nobj', 'context'],
        ['new_nobj', 'operator'],
      ],
    );
  })->then (sub {
    return $current->json (['tag', 'edit.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      name => $current->generate_text (x1 => {}),
      operator_nobj_key => $current->o ('u1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      name => $current->generate_text (x1 => {}),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $tag = $result->{json}->{tags}->{$current->o ('x1')};
      is $tag->{count}, 0;
      is $tag->{timestamp}, 0;
      is $tag->{author_status}, 0;
      is $tag->{owner_status}, 0;
      is $tag->{admin_status}, 0;
    } $current->c;
  });
} n => 6, name => 'nop';

Test {
  my $current = shift;
  return $current->create (
    [t1 => nobj => {}],
    [u1 => nobj => {}],
  )->then (sub {
    return $current->json (['tag', 'edit.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      name => $current->generate_text (x1 => {}),
      operator_nobj_key => $current->o ('u1')->{nobj_key},
      author_status => 4,
    });
  })->then (sub {
    my $result = $_[0];
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      name => $current->o ('x1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $tag = $result->{json}->{tags}->{$current->o ('x1')};
      $current->set_o (tag1 => $tag);
      is $tag->{count}, 0;
      ok $tag->{timestamp};
      is $tag->{author_status}, 4;
      is $tag->{owner_status}, 0;
      is $tag->{admin_status}, 0;
    } $current->c;
    return $current->json (['nobj', 'statusinfo.json'], {
      target_nobj_key => $current->o ('tag1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $s = $result->{json}->{info}->{$current->o ('tag1')->{nobj_key}};
      is $s->{author_data}->{ab}, undef;
      is $s->{owner_data}->{ab}, undef;
      is $s->{admin_data}->{ab}, undef;
      ok $s->{data}->{log_id};
      ok $s->{data}->{timestamp};
      is $s->{data}->{old}->{author_status}, 0;
      is $s->{data}->{old}->{owner_status}, 0;
      is $s->{data}->{old}->{admin_status}, 0;
      is $s->{data}->{new}->{author_status}, 4;
      is $s->{data}->{new}->{owner_status}, 0;
      is $s->{data}->{new}->{admin_status}, 0;
    } $current->c;
    return $current->json (['tag', 'edit.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      name => $current->o ('x1'),
      operator_nobj_key => $current->o ('u1')->{nobj_key},
      owner_status => 2,
      admin_status => 10,
    });
  })->then (sub {
    my $result = $_[0];
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      name => $current->o ('x1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $tag = $result->{json}->{tags}->{$current->o ('x1')};
      is $tag->{count}, 0;
      ok $tag->{timestamp};
      is $tag->{author_status}, 4;
      is $tag->{owner_status}, 2;
      is $tag->{admin_status}, 10;
    } $current->c;
    return $current->json (['nobj', 'statusinfo.json'], {
      target_nobj_key => $current->o ('tag1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $s = $result->{json}->{info}->{$current->o ('tag1')->{nobj_key}};
      is $s->{author_data}->{ab}, undef;
      is $s->{owner_data}->{ab}, undef;
      is $s->{admin_data}->{ab}, undef;
      ok $s->{data}->{log_id};
      ok $s->{data}->{timestamp};
      is $s->{data}->{old}->{author_status}, 4;
      is $s->{data}->{old}->{owner_status}, 0;
      is $s->{data}->{old}->{admin_status}, 0;
      is $s->{data}->{new}->{author_status}, 4;
      is $s->{data}->{new}->{owner_status}, 2;
      is $s->{data}->{new}->{admin_status}, 10;
    } $current->c;
    return $current->json (['tag', 'edit.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      name => $current->o ('x1'),
      operator_nobj_key => $current->o ('u1')->{nobj_key},
      status_info_author_data => '{"ab":53}',
    });
  })->then (sub {
    my $result = $_[0];
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      name => $current->o ('x1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $tag = $result->{json}->{tags}->{$current->o ('x1')};
      is $tag->{count}, 0;
      ok $tag->{timestamp};
      is $tag->{author_status}, 4;
      is $tag->{owner_status}, 2;
      is $tag->{admin_status}, 10;
    } $current->c;
    return $current->json (['nobj', 'statusinfo.json'], {
      target_nobj_key => $current->o ('tag1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $s = $result->{json}->{info}->{$current->o ('tag1')->{nobj_key}};
      is $s->{author_data}->{ab}, 53;
      is $s->{owner_data}->{ab}, undef;
      is $s->{admin_data}->{ab}, undef;
      ok $s->{data}->{log_id};
      ok $s->{data}->{timestamp};
      is $s->{data}->{old}->{author_status}, 4;
      is $s->{data}->{old}->{owner_status}, 2;
      is $s->{data}->{old}->{admin_status}, 10;
      is $s->{data}->{new}->{author_status}, 4;
      is $s->{data}->{new}->{owner_status}, 2;
      is $s->{data}->{new}->{admin_status}, 10;
    } $current->c;
    return $current->json (['tag', 'edit.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      name => $current->o ('x1'),
      operator_nobj_key => $current->o ('u1')->{nobj_key},
      status_info_author_data => '{}',
      status_info_owner_data => '{"ab":13}',
      status_info_admin_data => '{"ab":0.44}',
      admin_status => 30,
    });
  })->then (sub {
    my $result = $_[0];
    return $current->json (['tag', 'list.json'], {
      context_nobj_key => $current->o ('t1')->{nobj_key},
      name => $current->o ('x1'),
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $tag = $result->{json}->{tags}->{$current->o ('x1')};
      is $tag->{count}, 0;
      ok $tag->{timestamp};
      is $tag->{author_status}, 4;
      is $tag->{owner_status}, 2;
      is $tag->{admin_status}, 30;
    } $current->c;
    return $current->json (['nobj', 'statusinfo.json'], {
      target_nobj_key => $current->o ('tag1')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $s = $result->{json}->{info}->{$current->o ('tag1')->{nobj_key}};
      is $s->{author_data}->{ab}, undef;
      is $s->{owner_data}->{ab}, 13;
      is $s->{admin_data}->{ab}, 0.44;
      ok $s->{data}->{log_id};
      ok $s->{data}->{timestamp};
      is $s->{data}->{old}->{author_status}, 4;
      is $s->{data}->{old}->{owner_status}, 2;
      is $s->{data}->{old}->{admin_status}, 10;
      is $s->{data}->{new}->{author_status}, 4;
      is $s->{data}->{new}->{owner_status}, 2;
      is $s->{data}->{new}->{admin_status}, 30;
    } $current->c;
  });
} n => 64, name => 'status changed';

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
