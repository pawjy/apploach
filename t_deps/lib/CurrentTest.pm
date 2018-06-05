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

push our @CARP_NOT, qw(TestError Web::Transport::BasicClient);

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
  return $self->{o}->{$name} // die new TestError ("No object |$name|");
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
  my ($req_path, $req_params, %req_opts) = @$req;
  $tests = [map {
    my $test = $_;
    my $path = $test->{path} || $req_path;
    my $params = {%{$test->{params} || $req_params}};
    for my $name (keys %{$test->{p} or {}}) {
      $params->{$name} = $test->{p}->{$name};
    }
    for my $name (keys %$params) {
      $params->{$name} = perl2json_chars $params->{$name}
          if defined $params->{$name} and
             ref $params->{$name} eq 'HASH';
    }
    my $bearer = (exists $test->{bearer} and not defined $test->{bearer}) ? undef : (
      $test->{bearer} // $req_opts{bearer} // $self->bearer
    );
    $test->{_req} = {path => [
      $test->{app_id} //
      (defined $test->{app} ? $self->o ($test->{app}) : undef) //
      $req_opts{app_id} //
      $self->o ('app_id'),
      @$path,
    ], method => 'POST', params => $params, bearer => $bearer};
    $test;
  } map {
    if (ref $_ eq 'HASH') {
      $_;
    } elsif (ref $_ eq 'ARRAY') {
      (@{({
        json => sub {
          my $n = $_[1];
          return [
            {p => {$n => undef}, reason => "Bad JSON parameter |$n|"},
            {p => {$n => '"a"'}, reason => "Bad JSON parameter |$n|"},
            {p => {$n => '["a"]'}, reason => "Bad JSON parameter |$n|"},
          ];
        },
        new_nobj => sub {
          my $n = $_[1];
          return [
            {p => {$n.'_nobj_key' => undef}, reason => 'Bad |'.$n.'_nobj_key|',
             name => 'Bad |'.$n.'_nobj_key| (undef)'},
            {p => {$n.'_nobj_key' => ''}, reason => 'Bad |'.$n.'_nobj_key|',
             name => 'Bad |'.$n.'_nobj_key| (empty)'},
            {p => {
               $n.'_nobj_key' => $self->generate_key (rand, {
                 min_length => 4096, max_length => 4096,
               }),
             }, reason => 'Bad |'.$n.'_nobj_key|',
             name => 'Bad |'.$n.'_nobj_key| (long)'},
          ];
        },
        get_nobj => sub {
          my $n = $_[1];
          return [
            {p => {$n.'_nobj_key' => ''}, name => 'empty nobj_key'},
            {p => {$n.'_nobj_key' => $self->generate_key (rand, {})},
             name => 'wrong nobj_key'},
            {p => {$n.'_nobj_key' => $self->generate_key (rand, {
               min => 4096, max => 4096,
             })}, reason => 'Bad |'.$n.'_nobj_key|'},
          ];
        },
      }->{$_->[0]} or die TestError->new ("Bad error test |$_->[0]|"))->(@$_)});
    } else {
      (@{+{
        app_id => [
          {app_id => $self->generate_id (rand, {}),
           name => 'Bad application ID'},
        ],
        status => [
          {p => {author_status => undef}, reason => 'Bad |author_status|'},
          {p => {author_status => 0}, reason => 'Bad |author_status|'},
          {p => {author_status => 1}, reason => 'Bad |author_status|'},
          {p => {author_status => 'abc'}, reason => 'Bad |author_status|'},
          {p => {author_status => 255}, reason => 'Bad |author_status|'},
          {p => {author_status => -1}, reason => 'Bad |author_status|'},
          {p => {owner_status => undef}, reason => 'Bad |owner_status|'},
          {p => {owner_status => 0}, reason => 'Bad |owner_status|'},
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
          } $self->c, name => [$name, $i, $test->{name}];
          return;
        }
        
        test {
          if ($res->status == ($test->{status} // 400) and
              ($res->header ('content-type') // '') eq 'application/json;charset=utf-8') {
            my $json = json_bytes2perl $res->body_bytes;
            if ($json->{reason} eq $test->{reason}) {
              return;
            } else {
              $has_error = 1;
              is $res->status, $test->{status} // 400;
              is $res->header ('content-type'), 'application/json;charset=utf-8';
              is $json->{reason}, $test->{reason};
            }
          } else {
            $has_error = 1;
            is $res->status, $test->{status} // 400;
            is $res->header ('content-type'), 'application/json;charset=utf-8';
          }
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

sub pages_ok ($$$$;$) {
  my $self = $_[0];
  my ($path, $params, %args) = @{$_[1]};
  my $items = [@{$_[2]}];
  my $field = $_[3];
  my $name = $_[4];
  my $count = int (@$items / 2) + 3;
  my $page = 1;
  my $ref;
  my $has_error = 0;
  return promised_cleanup {
    return if $has_error;
    note "no error (@{[$page-1]} pages)";
    return $self->are_errors (
      [$path, $params, %args],
      [
        {p => {ref => rand}, reason => 'Bad |ref|'},
        {p => {ref => '+5353,350000'}, reason => 'Bad |ref| offset'},
        {p => {limit => 40000}, reason => 'Bad |limit|'},
      ],
      $name,
    );
  } promised_wait_until {
    return $self->json ($path, {%$params, limit => 2, ref => $ref}, %args)->then (sub {
      my $result = $_[0];
      my $expected_length = (@$items > 2 ? 2 : 0+@$items);
      my $actual_length = 0+@{$result->{json}->{items}};
      if ($expected_length == $actual_length) {
        if ($expected_length >= 1) {
          unless ($result->{json}->{items}->[0]->{$field} eq $self->o ($items->[-1])->{$field}) {
            test {
              is $result->{json}->{items}->[0]->{$field},
                 $self->o ($items->[-1])->{$field}, "page $page, first item";
            } $self->c, name => $name;
            $count = 0;
            $has_error = 1;
          }
        }
        if ($expected_length >= 2) {
          unless ($result->{json}->{items}->[1]->{$field} eq $self->o ($items->[-2])->{$field}) {
            test {
              is $result->{json}->{items}->[1]->{$field},
                 $self->o ($items->[-2])->{$field}, "page $page, second item";
            } $self->c, name => $name;
            $count = 0;
            $has_error = 1;
          }
        }
        pop @$items;
        pop @$items;
      } else {
        test {
          is $actual_length, $expected_length, "page $page length";
        } $self->c, name => $name;
        $count = 0;
        $has_error = 1;
      }
      if (@$items) {
        unless ($result->{json}->{has_next} and
                defined $result->{json}->{next_ref}) {
          test {
            ok $result->{json}->{has_next}, 'has_next';
            ok $result->{json}->{next_ref}, 'next_ref';
          } $self->c, name => $name;
          $count = 0;
          $has_error = 1;
        }
      } else {
        if ($result->{json}->{has_next}) {
          test {
            ok ! $result->{json}->{has_next}, 'no has_next';
          } $self->c, name => $name;
          $count = 0;
          $has_error = 1;
        }
      }
      $ref = $result->{json}->{next_ref};
    })->then (sub {
      $page++;
      return not $count >= $page;
    });
  };
} # pages_ok

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

sub create_app ($$$) {
  my ($self, $name, $opts) = @_;
  $self->set_o ($name => {app_id => $self->generate_id (rand, {})});
  return Promise->resolve;
} # create_app

sub create_account ($$$) {
  my ($self, $name, $opts) = @_;
  $self->set_o ($name => {nobj_key => $self->generate_key (rand, {})});
  return Promise->resolve;
} # create_account

sub create_nobj ($$$) {
  my ($self, $name, $opts) = @_;
  $self->set_o ($name => {nobj_key => $self->generate_key (rand, {})});
  return Promise->resolve;
} # create_nobj

sub _nobj ($$$) {
  my ($self, $prefix, $opts) = @_;
  return ($prefix.'_nobj_key' => (
    defined $opts->{$prefix} ? $self->o ($opts->{$prefix})->{nobj_key} : $self->generate_key (rand, {})
  ));
} # _nobj

sub create_comment ($$$) {
  my ($self, $name, $opts) = @_;
  return $self->json (['comment', 'post.json'], {
    ($self->_nobj ('thread', $opts)),
    ($self->_nobj ('author', $opts)),
    data => perl2json_chars ($opts->{data} or {}),
    internal_data => perl2json_chars ($opts->{internal_data} or {}),
    author_status => $opts->{author_status} // 2,
    owner_status => $opts->{owner_status} // 2,
    admin_status => $opts->{admin_status} // 2,
  }, app => $opts->{app})->then (sub {
    my $result = $_[0];
    $result->{json}->{nobj_key} = 'apploach-comment-'.$result->{json}->{comment_id};
    $self->set_o ($name => $result->{json});
  });
} # create_comment

sub create_star ($$$) {
  my ($self, $name, $opts) = @_;
  return $self->json (['star', 'add.json'], {
    ($self->_nobj ('starred', $opts)),
    ($self->_nobj ('starred_author', $opts)),
    ($self->_nobj ('starred_index', $opts)),
    ($self->_nobj ('author', $opts)),
    ($self->_nobj ('item', $opts)),
    delta => $opts->{count} // 1,
  }, app => $opts->{app})->then (sub {
    my $result = $_[0];
    $result->{json} = {%{$result->{json}}, ($self->_nobj ('author', $opts))};
    $self->set_o ($name => $result->{json});
  });
} # create_star

sub create_follow ($$$) {
  my ($self, $name, $opts) = @_;
  return $self->json (['follow', 'set.json'], {
    ($self->_nobj ('subject', $opts)),
    ($self->_nobj ('object', $opts)),
    ($self->_nobj ('verb', $opts)),
    value => $opts->{value} // 1,
  }, app => $opts->{app})->then (sub {
    my $result = $_[0];
    $result->{json} = {%{$result->{json}}, ($self->_nobj ('verb', $opts))};
    $self->set_o ($name => $result->{json});
  });
} # create_follow

sub create_log ($$$) {
  my ($self, $name, $opts) = @_;
  return $self->json (['nobj', $opts->{status_info} ? 'setstatusinfo.json' : 'addlog.json'], {
    ($self->_nobj ('operator', $opts)),
    ($self->_nobj ('target', $opts)),
    ($self->_nobj ('verb', $opts)),
    data => $opts->{data} // {},
  }, app => $opts->{app})->then (sub {
    my $result = $_[0];
    $self->set_o ($name => $result->{json});
  });
} # create_log

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
