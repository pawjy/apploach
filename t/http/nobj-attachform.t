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
    return $current->are_errors (
      [['nobj', 'attachform.json'], {
        target_nobj_key => $current->o ('c1')->{nobj_key},
        path_prefix => '/abc/DEF24t224',
        mime_type => 'application/octet-stream',
        byte_length => length ($current->generate_key (k1 => {})),
      }],
      [
        {p => {path_prefix => undef}, reason => 'Bad |path_prefix|'},
        {p => {path_prefix => '/'}, reason => 'Bad |path_prefix|'},
        {p => {path_prefix => '//aaa'}, reason => 'Bad |path_prefix|'},
        {p => {path_prefix => '/0/1/'}, reason => 'Bad |path_prefix|'},
        {p => {path_prefix => '/' . ('X' x 512)}, reason => 'Bad |path_prefix|'},
        {p => {mime_type => undef}, reason => 'Bad MIME type'},
        {p => {byte_length => undef}, reason => 'Bad byte length'},
        {p => {byte_length => 'gaegaee'}, reason => 'Bad byte length'},
        ['new_nobj', 'target'],
      ],
    );
  })->then (sub {
    return $current->json (['nobj', 'attachform.json'], {
      target_nobj_key => $current->o ('c1')->{nobj_key},
      path_prefix => '/abc/DEF24t224',
      mime_type => 'application/octet-stream',
      byte_length => length ($current->o ('k1')),
    });
  })->then (sub {
    my $result = $_[0];
    $current->set_o (file1 => $result->{json}->{file});
    test {
      ok $result->{json}->{form_url};
      ok 0+keys %{$result->{json}->{form_data}};
      like $result->{json}->{file}->{file_url}, qr{/abc/DEF24t224};
      like $result->{json}->{file}->{public_file_url}, qr{/public/abc/DEF24t224};
      is $result->{json}->{file}->{mime_type}, 'application/octet-stream';
      is $result->{json}->{file}->{byte_length}, length $current->o ('k1');
    } $current->c;
    my $url = Web::URL->parse_string ($result->{json}->{form_url});
    return $current->client_for ($url)->request (
      url => $url,
      method => 'POST',
      params => $result->{json}->{form_data},
      files => {
        file => {body_ref => \($current->o ('k1')), mime_filename => rand},
      },
    )->then (sub {
      my $res = $_[0];
      die $res unless $res->is_success;
      $url = Web::URL->parse_string ($result->{json}->{file}->{file_url});
      return $current->client_for ($url)->request (url => $url);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->status, 403, 'unsigned URL';
      } $current->c;
      $url = Web::URL->parse_string ($result->{json}->{file}->{public_file_url});
      return $current->client_for ($url)->request (url => $url);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->status, 404, 'public URL';
      } $current->c;
      $url = Web::URL->parse_string ($result->{json}->{file}->{signed_url});
      return $current->client_for ($url)->request (
        url => $url,
      );
    });
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->status, 200;
      is $res->header ('content-type'), 'application/octet-stream';
      is $res->body_bytes, $current->o ('k1');
    } $current->c, name => 'signed URL';
  });
} n => 12, name => 'attach a file';

Test {
  my $current = shift;
  $current->generate_key (k1 => {});
  return $current->create (
    [a1 => account => {}],
    [a2 => account => {}],
    [c1 => nobj => {account => 'a1'}],
  )->then (sub {
    return $current->json (['nobj', 'attachform.json'], {
      target_nobj_key => $current->o ('c1')->{nobj_key},
      path_prefix => '/abc/DEF24t224',
      mime_type => 'image/jpeg',
      byte_length => length ($current->o ('k1')),
    });
  })->then (sub {
    my $result = $_[0];
    $current->set_o (file1 => $result->{json}->{file});
    test {
      ok $result->{json}->{form_url};
      ok 0+keys %{$result->{json}->{form_data}};
      like $result->{json}->{file}->{file_url}, qr{/abc/DEF24t224.+\.jpeg};
      like $result->{json}->{file}->{public_file_url}, qr{/public/abc/DEF24t224.+\.jpeg};
      is $result->{json}->{file}->{mime_type}, 'image/jpeg';
      is $result->{json}->{file}->{byte_length}, length $current->o ('k1');
    } $current->c;
    my $url = Web::URL->parse_string ($result->{json}->{form_url});
    return $current->client_for ($url)->request (
      url => $url,
      method => 'POST',
      params => $result->{json}->{form_data},
      files => {
        file => {body_ref => \($current->o ('k1')), mime_filename => rand},
      },
    )->then (sub {
      my $res = $_[0];
      die $res unless $res->is_success;
      $url = Web::URL->parse_string ($result->{json}->{file}->{file_url});
      return $current->client_for ($url)->request (url => $url);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->status, 403, 'unsigned URL';
      } $current->c;
      $url = Web::URL->parse_string ($result->{json}->{file}->{public_file_url});
      return $current->client_for ($url)->request (url => $url);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->status, 404, 'public URL';
      } $current->c;
      $url = Web::URL->parse_string ($result->{json}->{file}->{signed_url});
      return $current->client_for ($url)->request (
        url => $url,
      );
    });
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->status, 200;
      is $res->header ('content-type'), 'image/jpeg';
      is $res->body_bytes, $current->o ('k1');
    } $current->c, name => 'signed URL';
  });
} n => 11, name => 'attach a file .jpeg';

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
