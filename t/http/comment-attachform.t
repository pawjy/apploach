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
    [c1 => comment => {account => 'a1'}],
  )->then (sub {
    return $current->are_errors (
      [['comment', 'attachform.json'], {
        comment_id => $current->o ('c1')->{comment_id},
        mime_type => 'application/octet-stream',
        byte_length => length ($current->generate_key (k1 => {})),
        operator_nobj_key => $current->o ('a2')->{nobj_key},
      }],
      [
        {p => {comment_id => undef}, reason => 'Bad ID parameter |comment_id|'},
        {p => {mime_type => undef}, reason => 'Bad MIME type'},
        {p => {byte_length => undef}, reason => 'Bad byte length'},
        {p => {byte_length => 'gaegaee'}, reason => 'Bad byte length'},
        ['new_nobj', 'operator'],
      ],
    );
  })->then (sub {
    return $current->json (['comment', 'attachform.json'], {
      comment_id => $current->o ('c1')->{comment_id},
      mime_type => 'application/octet-stream',
      byte_length => length ($current->o ('k1')),
      operator_nobj_key => $current->o ('a2')->{nobj_key},
    });
  })->then (sub {
    my $result = $_[0];
    $current->set_o (file1 => $result->{json}->{file});
    test {
      ok $result->{json}->{form_url};
      ok 0+keys %{$result->{json}->{form_data}};
      ok $result->{json}->{file}->{file_url};
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
    } $current->c;
    return $current->json (['comment', 'list.json'], {
      comment_id => $current->o ('c1')->{comment_id},
    });
  })->then (sub {
    my $result = $_[0];
    test {
      my $v = $result->{json}->{items}->[0];
      is 0+@{$v->{data}->{files}}, 1;
      is $v->{data}->{files}->[0]->{file_url}, $current->o ('file1')->{file_url};
      is $v->{data}->{files}->[0]->{mime_type}, $current->o ('file1')->{mime_type};
      is $v->{data}->{files}->[0]->{byte_length}, $current->o ('file1')->{byte_length};
    } $current->c;
  });
} n => 13, name => 'attach a file';

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
