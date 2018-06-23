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
    [c1 => nobj => {account => 'a1'}],
  )->then (sub {
    return $current->json (['nobj', 'attachform.json'], {
      target_nobj_key => $current->o ('c1')->{nobj_key},
      path_prefix => '/abc/DEF24t224',
      mime_type => 'application/octet-stream',
      byte_length => length ($current->generate_key ('k1' => {})),
    });
  })->then (sub {
    my $result = $_[0];
    $current->set_o (file1 => $result->{json}->{file});
    my $url = Web::URL->parse_string ($result->{json}->{form_url});
    return $current->client_for ($url)->request (
      url => $url,
      method => 'POST',
      params => $result->{json}->{form_data},
      files => {
        file => {body_ref => \($current->o ('k1')), mime_filename => rand},
      },
    );
  })->then (sub {
    my $res = $_[0];
    die $res unless $res->is_success;
    return $current->json (['nobj', 'setattachmentopenness.json'], {
      target_nobj_key => $current->o ('c1')->{nobj_key},
      open => 0,
    }); # unchanged
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{items}}, 0;
      ok ! $result->{json}->{items}->{$current->o ('file1')->{file_url}}->{changed}, 'unchanged';
    } $current->c;
    my $url = Web::URL->parse_string ($current->o ('file1')->{file_url});
    return $current->client_for ($url)->request (url => $url);
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->status, 403, 'unsigned URL';
    } $current->c;
    my $url = Web::URL->parse_string ($current->o ('file1')->{signed_url});
    return $current->client_for ($url)->request (
      url => $url,
    );
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->status, 200;
      is $res->header ('content-type'), 'application/octet-stream';
      is $res->body_bytes, $current->o ('k1');
    } $current->c, name => 'signed URL';
    return $current->json (['nobj', 'setattachmentopenness.json'], {
      target_nobj_key => $current->o ('c1')->{nobj_key},
      open => 1,
    }); # changed
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}->{items}}, 1;
      ok $result->{json}->{items}->{$current->o ('file1')->{file_url}}->{changed};
    } $current->c;
    my $url = Web::URL->parse_string ($current->o ('file1')->{file_url});
    return $current->client_for ($url)->request (url => $url);
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->status, 200;
      is $res->header ('content-type'), 'application/octet-stream';
      is $res->body_bytes, $current->o ('k1');
    } $current->c, name => 'unsigned URL';
    my $url = Web::URL->parse_string ($current->o ('file1')->{signed_url});
    return $current->client_for ($url)->request (
      url => $url,
    );
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->status, 200;
      is $res->header ('content-type'), 'application/octet-stream';
      is $res->body_bytes, $current->o ('k1');
    } $current->c, name => 'signed URL';
  });
  # XXX this test is incomplete.
} n => 10, name => 'change open status';

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
