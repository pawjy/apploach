package CurrentTest;
use strict;
use warnings;
use JSON::PS;
use Promise;
use Promised::Flow;
use Web::Encoding;
use Web::URL;
use Web::Transport::ENVProxyManager;
use Web::Transport::BasicClient;
use Test::More;
use Test::X1;

use TestError;

push our @CARP_NOT, qw(TestError);

sub c ($) {
  return $_[0]->{c};
} # c

sub bearer ($) {
  return $_[0]->{server_data}->{app_bearer};
} # bearer

sub url ($$) {
  my ($self, $rel) = @_;
  return Web::URL->parse_string ($rel, $self->{server_data}->{app_client_url});
} # url

sub client ($) {
  my ($self) = @_;
  $self->{client} ||= Web::Transport::BasicClient->new_from_url ($self->url ('/'), {
    proxy_manager => Web::Transport::ENVProxyManager->new_from_envs ($self->{server_data}->{local_envs}),
  });
} # client

sub o ($$) {
  my ($self, $name) = @_;
  return $self->{o}->{$name} // die "No object |$name|";
} # o

sub set_o ($$$) {
  my ($self, $name, $value) = @_;
  $self->{o}->{$name} = $value;
} # set_o

sub generate_id ($$$) {
  my ($self, $name, $opts) = @_;
  $self->set_o ($name => 1 + int rand 1000000000);
} # generate_id

sub generate_key ($$$) {
  my ($self, $name, $opts) = @_;
  my $v = '';
  my $min = $opts->{min_length} // 10;
  my $max = $opts->{max_length} // 100;
  my $length = $min + int rand ($max - $min);
  $v .= pack 'C', [0x20..0x7E]->[rand 95] for 1..$length;
  $self->set_o ($name => $v);
} # generate_key

sub generate_text ($$$) {
  my ($self, $name, $opts) = @_;
  my $v = rand;
  $v .= chr int rand 0x10FFFF for 1..rand 10;
  $self->set_o ($name => decode_web_utf8 encode_web_utf8 $v);
} # generate_text

sub _expand_reqs ($$$) {
  my ($self, $req, $tests) = @_;
  $tests = [map {
    my $test = $_;
    my $path = $test->{path} || $req->[0];
    my $params = {%{$test->{params} || $req->[1]}};
    for my $name (keys %{$test->{p} or {}}) {
      $params->{$name} = $test->{p}->{$name};
    }
    my $bearer = exists $test->{bearer} ? $test->{bearer} : $self->bearer;
    $test->{_req} = {path => [
      $test->{app_id} // $self->o ('app'), @$path,
    ], method => 'POST', params => $params, bearer => $bearer};
    $test;
  } map {
    if (ref $_ eq 'HASH') {
      $_;
    } elsif (ref $_ eq 'ARRAY') {
      (@{({
        json => sub {
          my $n = $_[1];
          [
            {p => {$n => undef}, reason => "Bad JSON parameter |$n|"},
            {p => {$n => '"a"'}, reason => "Bad JSON parameter |$n|"},
            {p => {$n => '["a"]'}, reason => "Bad JSON parameter |$n|"},
          ];
        },
      }->{$_->[0]} or die TestError->new ("Bad error test |$_->[0]|"))->(@$_)});
    } else {
      (@{+{
        app_id => [
          {app_id => $self->generate_id (rand, {}),
           name => 'Bad application ID'},
        ],
        new_target => [
          {p => {target_key => undef}, reason => 'Bad |target_key|',
           name => 'Bad |target_key| (undef)'},
          {p => {target_key => ''}, reason => 'Bad |target_key|',
           name => 'Bad |target_key| (empty)'},
          {p => {
             target_key => $self->generate_key (rand, {
               min_length => 4096, max_length => 4096,
             }),
           }, reason => 'Bad |target_key|',
           name => 'Bad |target_key| (long)'},
        ],
        get_target => [
          {p => {target_key => ''}, name => 'empty target_key'},
          {p => {target_key => $self->generate_key (rand, {})},
           name => 'wrong target_key'},
          {p => {target_key => $self->generate_key (rand, {min => 4096, max => 4096})}, reason => 'Bad |target_key|'},
        ],
        status => [
          {p => {author_status => undef}, reason => 'Bad |author_status|'},
          {p => {author_status => 0}, reason => 'Bad |author_status|'},
          {p => {author_status => 1}, reason => 'Bad |author_status|'},
          {p => {author_status => 'abc'}, reason => 'Bad |author_status|'},
          {p => {author_status => 255}, reason => 'Bad |author_status|'},
          {p => {author_status => -1}, reason => 'Bad |author_status|'},
          {p => {target_owner_status => undef}, reason => 'Bad |target_owner_status|'},
          {p => {target_owner_status => 0}, reason => 'Bad |target_owner_status|'},
          {p => {admin_status => undef}, reason => 'Bad |admin_status|'},
          {p => {admin_status => 0}, reason => 'Bad |admin_status|'},
          {p => {admin_status => 1}, reason => 'Bad |admin_status|'},
        ],
      }->{$_} or die TestError->new ("Bad error test |$_|")});
    }
  } @$tests];
  return $tests;
} # _expand_reqs

sub json ($$$;%) {
  my ($self, $path, $params, %args) = @_;
  my $tests = $self->_expand_reqs ([$path, $params, %args], [{}]);
  return $self->client->request (%{$tests->[0]->{_req}})->then (sub {
    my $res = $_[0];
    die TestError->new ("|@$path| returns an error |@{[$res->status]} @{[$res->status_text]}|")
        if $res->status != 200;
    die TestError->new ("|@$path| does not return a JSON (|@{[$res->header ('content-type') // '']}|)")
        unless ($res->header ('content-type') // '') eq 'application/json;charset=utf-8';
    return {
      res => $res,
      json => json_bytes2perl $res->body_bytes,
    };
  });
} # json

sub are_errors ($$$;$) {
  my ($self, $req, $tests, $name) = @_;
  $tests = $self->_expand_reqs ($req, [
    {bearer => undef, status => 401, name => 'No bearer'},
    {bearer => rand, status => 401, name => 'Bad bearer'},
    @$tests,
  ]);
  my $has_error = 0;
  my $i = 0;
  return Promise->resolve->then (sub {
    return promised_for {
      my $test = shift;
      return $self->client->request (%{$test->{_req}})->then (sub {
        my $res = $_[0];
        if (defined $test->{status} and $test->{status} == 401 and
            not defined $test->{reason}) {
          return if $res->status == $test->{status};

          $has_error = 1;
          test {
            is $res->status, $test->{status}, 'status';
          } $self->c;
          return;
        }
        
        if ($res->status == ($test->{status} // 400) and
            ($res->header ('content-type') // '') eq 'application/json;charset=utf-8') {
          my $json = json_bytes2perl $res->body_bytes;
          if ($json->{reason} eq $test->{reason}) {
            return;
          }
        }
        
        $has_error = 1;
        test {
          is $res->status, $test->{status} // 400;
          is $res->header ('content-type'), 'application/json;charset=utf-8';
          my $json = json_bytes2perl $res->body_bytes;
          is $json->{reason}, $test->{reason};
        } $self->c, name => [$name, $i, $test->{name}];
      })->then (sub { $i++ });
    } $tests;
  })->then (sub {
    unless ($has_error) {
      test {
        ok 1, 'no error';
      } $self->c, name => $name;
    }
  });
} # are_errors

sub are_empty ($$$;$) {
  my ($self, $req, $tests, $name) = @_;
  $tests = $self->_expand_reqs ($req, $tests);
  my $has_error = 0;
  my $i = 0;
  return Promise->resolve->then (sub {
    return promised_for {
      my $test = shift;
      return $self->client->request (%{$test->{_req}})->then (sub {
        my $res = $_[0];
        if ($res->status == 200 and
            ($res->header ('content-type') // '') eq 'application/json;charset=utf-8') {
          my $json = json_bytes2perl $res->body_bytes;
          if (ref $json eq 'HASH' and
              defined $json->{items} and
              @{$json->{items}} == 0) {
            return;
          }
        }
        
        $has_error = 1;
        test {
          is $res->status, 200, 'status';
          is $res->header ('content-type'), 'application/json;charset=utf-8';
          my $json = json_bytes2perl $res->body_bytes;
          is ref $json, 'HASH';
          is ref $json->{items}, 'ARRAY';
          is 0+@{$json->{items} or []}, 0, '|items| length';
        } $self->c, name => [$name, $i, $test->{name}];
      })->then (sub { $i++ });
    } $tests;
  })->then (sub {
    unless ($has_error) {
      test {
        ok 1, 'no error';
      } $self->c, name => $name;
    }
  });
} # are_empty

sub close ($) {
  my $self = $_[0];
  return Promise->all ([
    defined $self->{client} ? $self->{client}->close : undef,
  ]);
} # close

sub create ($;@) {
  my $self = shift;
  return promised_for {
    my ($name, $type, $opts) = @{$_[0]};
    my $method = 'create_' . $type;
    return $self->$method ($name => $opts);
  } [@_];
} # create

sub create_account ($$$) {
  my ($self, $name, $opts) = @_;
  $self->set_o ($name => {account_id => $self->generate_id (rand, {})});
  return Promise->resolve;
} # create_account

sub create_target ($$$) {
  my ($self, $name, $opts) = @_;
  $self->set_o ($name => {target_key => $self->generate_key (rand, {})});
  return Promise->resolve;
} # create_target

sub create_comment ($$$) {
  my ($self, $name, $opts) = @_;
  return $self->json (['comment', 'post.json'], {
    target_key => (defined $opts->{target} ? $self->o ($opts->{target})->{target_key} : $self->generate_key (rand, {})),
    author_account_id => (defined $opts->{author} ? $self->o ($opts->{author})->{account_id} : undef),
    data => perl2json_chars ($opts->{data} or {}),
    internal_data => perl2json_chars ($opts->{internal_data} or {}),
    author_status => $opts->{author_status} // 2,
    target_owner_status => $opts->{target_owner_status} // 2,
    admin_status => $opts->{admin_status} // 2,
  })->then (sub {
    my $result = $_[0];
    $self->set_o ($name => $result->{json});
  });
} # create_comment

1;

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
