package Application;
use strict;
use warnings;
use Time::HiRes qw(time);
use JSON::PS;
use Digest::SHA qw(sha1_hex);
use Dongry::Type;
use Dongry::Type::JSONPS;
use Promise;
use Dongry::Database;

use Target;

## Configurations.  The path to the configuration JSON file must be
## specified to the |APP_CONFIG| environment variable.  The JSON file
## must contain an object with following name/value pairs:
##
##   |bearer|: The bearer (API key).  Its value must be a key.
##
##   |dsn|: The DSN of the MySQL database.

## HTTP requests.
##
##   Request method.  You can use both |GET| and |POST|.  It's a good
##   practice to use |GET| for getting and |POST| for anything other,
##   as usual.
##
##   Bearer.  You have to set the |Authorization| request header to
##   |Bearer| followed by a SPACE followed by the configuration's
##   bearer.
##
##   Parameters.  Parameters can be specified in query and body in the
##   |application/x-www-form-url-encoded| format.
##
##   Path.  The path's first segment must be the application ID.  The
##   path's second segment must be the object type.
##
##   As this is an internal server, it has no CSRF protection,
##   |Origin:| and |Referer:| validation, request URL's authority
##   verification, CORS support, and HSTS support.

## HTTP responses.  If there is no error, a JSON object is returned in
## |200| responses with name/value pairs specific to end points.
## Likewise, many (but not all) errors are returned in |400| JSON
## object responses with following name/value pair:
##
##   |reason| : String : A short string describing the error.

## Data types.
##
## ID.  A non-zero 64-bit unsigned integer.
##
## Application ID.  The ID which identifies the application.  The
## application defines the scope of the objects.
##
## Account ID.  The ID of an account in the scope of the application.
##
## Key.  A non-empty ASCII string whose length is less than 4096.
##
## Status.  A 8-bit unsigned integer representing the object's status
## (e.g. "open", "closed", "public", "private", "banned", and so on).
## The value |0| represents status is not specified or not applicable;
## this value should not be used.  Semantics of the other values are
## application-specific, though |1| should be used for "open" or
## "public".
##
## Timestamp.  A unix time, represented as a floating-point number.

sub new ($%) {
  my $class = shift;
  # app
  # path
  # app_id
  # type
  return bless {@_}, $class;
} # new

sub json ($$) {
  my ($self, $data) = @_;
  $self->{app}->http->set_response_header
      ('content-type', 'application/json;charset=utf-8');
  $self->{app}->http->send_response_body_as_ref (\perl2json_bytes $data);
  $self->{app}->http->close_response_body;
} # json

sub throw ($$) {
  my ($self, $data) = @_;
  $self->{app}->http->set_status (400, reason_phrase => $data->{reason});
  $self->json ($data);
  return $self->{app}->throw;
} # throw

sub json_object_param ($$) {
  my ($self, $name) = @_;
  my $v = $self->{app}->bare_param ($name);
  return $self->throw ({reason => 'Bad JSON parameter |'.$name.'|'})
      unless defined $v;
  my $w = json_bytes2perl $v;
  return $w if defined $w and ref $w eq 'HASH';
  return $self->throw ({reason => 'Bad JSON parameter |'.$name.'|'});
} # json_object_param

sub app_id_columns ($) {
  return (app_id => $_[0]->{app_id});
} # app_id_columns

sub status_columns ($) {
  my $self = $_[0];
  my $app = $self->{app};
  return (
    author_status => $app->bare_param ('author_status') // $self->throw ({reason => 'Bad |author_status|'}),
    target_owner_status => $app->bare_param ('target_owner_status') // $self->throw ({reason => 'Bad |target_owner_status|'}),
    admin_status => $app->bare_param ('admin_status') // $self->throw ({reason => 'Bad |admin_status|'}),
  );
} # status_columns

sub db ($) {
  my $self = $_[0];
  return $self->{db} ||= Dongry::Database->new (
    sources => {
      master => {
        dsn => Dongry::Type->serialize ('text', $self->{config}->{dsn}),
        writable => 1, anyevent => 1,
      },
    },
  );
} # db

sub ids ($$) {
  my ($self, $n) = @_;
  return Promise->resolve ([]) unless $n;
  my $v = join ',', map { sprintf 'uuid_short() as `%d`', $_ } 0..($n-1);
  return $self->db->execute ('select '.$v, undef, source_name => 'master')->then (sub {
    my $w = $_[0]->first;
    my $r = [];
    for (keys %$w) {
      $r->[$_] = $w->{$_};
    }
    return $r;
  });
} # ids

## Target.
##
## A target identifies the "context" in which an object alives.  It is
## identified by the application by a key which is unique within the
## scope of the application.  Parameters:
##
##   |target_key| : Key : The target.
##
## For example, implementing a blog's comment feature, the target key
## can be a string containing the blog's unique ID.
sub new_target ($) {
  my $self = $_[0];

  my $target_key = $self->{app}->bare_param ('target_key');
  return $self->throw ({reason => 'Bad |target_key|'})
      if not defined $target_key or 4095 < length $target_key;
  my $target_key_sha = sha1_hex $target_key;
  
  return $self->db->select ('target', {
    ($self->app_id_columns),
    target_key_sha => $target_key_sha,
    target_key => $target_key,
  }, fields => ['target_id'], limit => 1, source_name => 'master')->then (sub {
    my $v = $_[0]->first;
    return $v->{target_id} if defined $v;

    return $self->ids (1)->then (sub {
      my $id = $_[0]->[0];
      return $self->db->insert ('target', [{
        ($self->app_id_columns),
        target_id => $id,
        target_key => $target_key,
        target_key_sha => $target_key_sha,
        timestamp => time,
      }], source_name => 'master', duplicate => 'ignore');
    })->then (sub {
      return $self->db->select ('target', {
        ($self->app_id_columns),
        target_key_sha => $target_key_sha,
        target_key => $target_key,
      }, fields => ['target_id'], limit => 1, source_name => 'master');
    })->then (sub {
      my $v = $_[0]->first;
      return $v->{target_id} if defined $v;
      die "Can't generate |target_id| for |$target_key|";
    });
  })->then (sub {
    return Target->new (target_id => $_[0]);
  });
} # new_target

sub target ($) {
  my $self = $_[0];

  my $target_key = $self->{app}->bare_param ('target_key');
  return undef if not defined $target_key or 4095 < length $target_key;
  my $target_key_sha = sha1_hex $target_key;
  
  return $self->db->select ('target', {
    ($self->app_id_columns),
    target_key_sha => $target_key_sha,
    target_key => $target_key,
  }, fields => ['target_id'], limit => 1, source_name => 'master')->then (sub {
    my $v = $_[0]->first;
    return Target->new (target_id => $v->{target_id}) if defined $v;
    return undef;
  });
} # target

## Statuses.  A pair of status values.  Parameters:
##
##   |author_status| : Status : The status by the author.
##
##   |target_owner_status| : Status : The status by the owner of the
##   target, if any.
##
##   |admin_status| : Status : The status by the administrator of the
##   application.

sub run ($) {
  my $self = $_[0];

  if ($self->{type} eq 'comment') {
    if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'list.json') {
      # /{app_id}/comment/list.json

      return Promise->all ([
        $self->target,
      ])->then (sub {
        my ($target) = @{$_[0]}; # or undef

        my $where = {
          ($self->app_id_columns),
          (defined $target ? ($target->to_columns) : ()),
        };
        
        my $comment_id = $self->{app}->bare_param ('comment_id');
        if (defined $comment_id) {
          $where->{comment_id} = $comment_id;
        } else {
          return $self->throw
              ({reason => 'Either target or |comment_id| is required'})
              unless defined $target;
        }

        # XXX status filter
        # XXX paging
        return $self->db->select ('comment', $where, fields => [
          'comment_id',
          'author_account_id',
          'data',
          ($self->{app}->bare_param ('with_internal_data') ? ('internal_data') : ()),
          'author_status', 'target_owner_status', 'admin_status',
        ], source_name => 'master')->then (sub {
          my $items = $_[0]->all->to_a;
          for my $item (@$items) {
            $item->{comment_id} .= '';
            $item->{author_account_id} .= '';
            $item->{data} = Dongry::Type->parse ('json', $item->{data});
            $item->{internal_data} = Dongry::Type->parse ('json', $item->{internal_data})
                if defined $item->{internal_data};
          }
          return $self->json ({items => $items});
        });
      });
    } elsif (@{$self->{path}} == 1 and $self->{path}->[0] eq 'post.json') {
      ## /{app_id}/comments/post.json - Add a new comment.
      ##
      ## Parameters.
      ##
      ##   Target : The comment's thread.
      ##
      ##   Statuses : The comment's status values.
      ##
      ##   |author_account_id| : Account ID or 0 : The comment's
      ##   author.  Optional (default = 0).
      ##
      ##   |data| : JSON object : The comment's main data.  Its
      ##   |timestamp| is replaced by the comment's timestamp
      ##   (i.e. when the server added the comment).
      ##
      ##   |internal_data| : JSON object : The comment's additional
      ##   data, intended for storing private data such as author's IP
      ##   address.
      ##
      ## Responses.
      ##
      ##   |comment_id| : ID : The comment's ID.
      ##
      ##   |timestamp| : Timestamp : The comment's timestamp.

      return Promise->all ([
        $self->new_target,
        $self->ids (1),
      ])->then (sub {
        my ($target, $ids) = @{$_[0]};
        my $data = $self->json_object_param ('data');
        my $time = time;
        $data->{timestamp} = $time;
        return $self->db->insert ('comment', [{
          ($self->app_id_columns),
          ($target->to_columns),
          comment_id => $ids->[0],
          author_account_id => $self->{app}->bare_param ('author_account_id') // 0,
          data => Dongry::Type->serialize ('json', $data),
          internal_data => Dongry::Type->serialize ('json', $self->json_object_param ('internal_data')),
          ($self->status_columns),
          timestamp => $time,
        }])->then (sub {
          return $self->json ({
            comment_id => ''.$ids->[0],
            timestamp => $time,
          });
        });
        # XXX kick notifications
      });
    }

    # XXX edit.json
  }
  
  return $self->{app}->throw_error (404);
} # run

sub close ($) {
  my $self = $_[0];
  return Promise->all ([
    defined $self->{db} ? $self->{db}->disconnect : undef,
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
