package CurrentTest;
use strict;
use warnings;
use JSON::PS;
use Promise;
use Promised::Flow;
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
  $v .= [0x00..0xFF]->[256] for ($opts->{min_length} // 1)..($opts->{max_length} // 1024);
  $self->set_o ($name => $v);
} # generate_key

sub json ($$$;%) {
  my ($self, $path, $params, %args) = @_;
  return $self->client->request (path => [
    $self->o ('app'), @$path,
  ], method => 'POST', params => $params, bearer => $self->bearer)->then (sub {
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
  $tests = [map {
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
        target => [{p => {target_key => undef}, reason => 'Bad |target_key|'}],
        status => [
          {p => {author_status => undef}, reason => 'Bad |author_status|'},
          {p => {target_owner_status => undef}, reason => 'Bad |target_owner_status|'},
          {p => {admin_status => undef}, reason => 'Bad |admin_status|'},
        ],
      }->{$_} or die TestError->new ("Bad error test |$_|")});
    }
  } @$tests];
  my $has_error = 0;
  my $i = 0;
  return Promise->resolve->then (sub {
    return promised_for {
      my $test = shift;
      my $path = $test->{path} || $req->[0];
      my $params = {%{$test->{params} || $req->[1]}};
      for my $name (keys %{$test->{p} or {}}) {
        $params->{$name} = $test->{p}->{$name};
      }
      return $self->client->request (path => [
        $self->o ('app'), @$path,
      ], method => 'POST', params => $params, bearer => $self->bearer)->then (sub {
        my $res = $_[0];
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

sub close ($) {
  my $self = $_[0];
  return Promise->all ([
    defined $self->{client} ? $self->{client}->close : undef,
  ]);
} # close

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
