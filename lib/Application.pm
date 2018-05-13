package Application;
use strict;
use warnings;
use Time::HiRes qw(time);
use JSON::PS;
use Digest::SHA qw(sha1_hex);
use Dongry::Type;
use Dongry::Type::JSONPS;
use Promise;
use Promised::Flow;
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
## Likewise, many (but not all) errors are returned as Error
## Responses.
##
## Created object responses.  HTTP responses representing some of
## properties of the created object.
##
## List responses.  HTTP responses containing zero or more objects
## with following name/value pair:
##
##   |objects| : JSON array : Objects.
##
## Error responses.  HTTP |400| responses whose JSON object responses
## with following name/value pair:
##
##   |reason| : String : A short string describing the error.

## Data types.
##
## Boolean.  A Perl boolean.
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
## Status.  An integer representing the object's status (e.g. "open",
## "closed", "public", "private", "banned", and so on).  It must be in
## the range [2, 254].
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

sub id_param ($$) {
  my ($self, $name) = @_;
  my $v = $self->{app}->bare_param ($name.'_id');
  return 0+$v if defined $v and $v =~ /\A[1-9][0-9]*\z/;
  return $self->throw ({reason => 'Bad ID parameter |'.$name.'_id|'});
} # id_param

sub optional_account_id_param ($$) {
  my ($self, $name) = @_;
  my $v = $self->{app}->bare_param ($name.'_account_id');
  return 0 unless defined $v;
  return 0+$v if $v =~ /\A[1-9][0-9]*\z/;
  return $self->throw ({reason => 'Bad ID parameter |'.$name.'_account_id|'});
} # optional_account_id_param

sub json_object_param ($$) {
  my ($self, $name) = @_;
  my $v = $self->{app}->bare_param ($name);
  return $self->throw ({reason => 'Bad JSON parameter |'.$name.'|'})
      unless defined $v;
  my $w = json_bytes2perl $v;
  return $w if defined $w and ref $w eq 'HASH';
  return $self->throw ({reason => 'Bad JSON parameter |'.$name.'|'});
} # json_object_param

sub optional_json_object_param ($$) {
  my ($self, $name) = @_;
  my $v = $self->{app}->bare_param ($name);
  return undef unless defined $v;
  my $w = json_bytes2perl $v;
  return $w if defined $w and ref $w eq 'HASH';
  return $self->throw ({reason => 'Bad JSON parameter |'.$name.'|'});
} # optional_json_object_param

sub app_id_columns ($) {
  return (app_id => $_[0]->{app_id});
} # app_id_columns

sub status_columns ($) {
  my $self = $_[0];
  my $w = {};
  for (qw(author_status target_owner_status admin_status)) {
    my $v = $self->{app}->bare_param ($_) // '';
    return $self->throw ({reason => "Bad |$_|"})
        unless $v =~ /\A[1-9][0-9]*\z/ and 1 < $v and $v < 255;
    $w->{$_} = 0+$v;
  }
  return %$w;
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

sub _opt_id ($) {
  if ($_[0]) {
    return ''.$_[0];
  } else {
    return undef;
  }
} # _opt_id

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
##
## Targets.
##
## Zero or more targets.  Parameters
##
##   |target_key| : Key : A target.  Zero or more parameters can be
##   specified.
sub new_target_list ($$) {
  my ($self, $params) = @_;
  my @key = map { $self->{app}->bare_param ($_) } @$params;
  return $self->_target (\@key)->then (sub {
    my $targets = $_[0];
    return promised_map {
      my $param = $params->[$_[0]];
      my $target_key = $key[$_[0]];
      my $target = $targets->[$_[0]];

      return $self->throw ({reason => 'Bad |'.$param.'|'})
          if $target->no_target or $target->invalid_key;
      return $target unless $target->not_found;

      # not found
      my $target_key_sha = sha1_hex $target_key;
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
        if (defined $v) {
          my $t = Target->new (target_id => $v->{target_id},
                               target_key => $target_key);
          $self->{target_id_to_object}->{$v->{target_id}} = $t;
          $self->{target_key_to_object}->{$target_key} = $t;
          return $t;
        }
        die "Can't generate |target_id| for |$target_key|";
      });
    } [0..$#key];
  });
} # new_target_list

sub new_target ($) {
  my ($self) = @_;
  return $self->new_target_list (['target_key'])->then (sub {
    return $_[0]->[0];
  });
} # new_target

sub target ($) {
  my $self = $_[0];
  my $target_key = $self->{app}->bare_param ('target_key');
  return $self->_target ([$target_key])->then (sub { return $_[0]->[0] });
} # target

sub target_list ($) {
  my $self = $_[0];
  return $self->_target ($self->{app}->bare_param_list ('target_key'));
} # target_list

sub _target ($$) {
  my ($self, $target_keys) = @_;
  my @key;
  my $results = [map {
    my $target_key = $_;
    if (not defined $target_key) {
      Target->new (no_target => 1);
    } elsif (not length $target_key or 4095 < length $target_key) {
      Target->new (not_found => 1, invalid_key => 1,
                   target_key => $target_key);
    } elsif (defined $self->{target_key_to_object}->{$target_key}) {
      $self->{target_key_to_object}->{$target_key};
    } else {
      my $target_key_sha = sha1_hex $target_key;
      push @key, [$target_key, $target_key_sha];
      $target_key;
    }
  } @$target_keys];
  return Promise->resolve->then (sub {
    return unless @key;
    return $self->db->select ('target', {
      ($self->app_id_columns),
      target_key_sha => {-in => [map { $_->[1] } @key]},
      target_key => {-in => [map { $_->[0] } @key]},
    }, fields => ['target_id', 'target_key'], source_name => 'master')->then (sub {
      for (@{$_[0]->all}) {
        my $t = Target->new (target_id => $_->{target_id},
                             target_key => $_->{target_key});
        $self->{target_key_to_object}->{$_->{target_key}} = $t;
        $self->{target_id_to_object}->{$_->{target_id}} = $t;
      }
    });
  })->then (sub {
    $results = [map {
      if (ref $_ eq 'Target') {
        $_;
      } else {
        if ($self->{target_key_to_object}->{$_}) {
          $self->{target_key_to_object}->{$_};
        } else {
          Target->new (not_found => 1, target_key => $_);
        }
      }
    } @$results];
    return $results;
  });
} # _target

sub target_list_by_ids ($$) {
  my ($self, $ids) = @_;
  return Promise->resolve->then (sub {
    my @id;
    my $results = [map {
      if (defined $self->{target_id_to_object}->{$_}) {
        $self->{target_id_to_object}->{$_};
      } else {
        push @id, $_;
        $_;
      }
    } @$ids];
    return $results unless @id;
    return $self->db->select ('target', {
      ($self->app_id_columns),
      target_id => {-in => \@id},
    }, fields => ['target_id', 'target_key'], source_name => 'master')->then (sub {
      for (@{$_[0]->all}) {
        my $t = Target->new (target_id => $_->{target_id},
                             target_key => $_->{target_key});
        $self->{target_key_to_object}->{$_->{target_key}} = $t;
        $self->{target_id_to_object}->{$_->{target_id}} = $t;
      }
      return [map {
        if (ref $_ eq 'Target') {
          $_;
        } else {
          $self->{target_id_to_object}->{$_} // die "Target |$_| not found";
        }
      } @$ids];
    });
  })->then (sub {
    return {map { $_->target_id => $_ } @{$_[0]}};
  });
} # target_list_by_ids

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
      ## /{app_id}/comment/list.json - Get comments.
      ##
      ## Parameters.
      ##
      ##   Target : The thread of comments.
      ##
      ##   |comment_id| : ID : The comment's ID.  Either Target or
      ##   |comment_id|, or both, is required.  If Target is
      ##   specified, returned comments are limited to those for the
      ##   Target.  If |comment_id| is specified, it is further
      ##   limited to one with that |comment_id|.
      ##
      ##   |with_internal_data| : Boolean : Whether |internal_data|
      ##   should be returned or not.
      ##
      ## List response of comments.
      ##
      ##   |comment_id| : ID : The comment's ID.
      ##
      ##   |author_account_id| : ID : The comment's ID.
      ##
      ##   |data| : JSON object : The comment's data.
      ##
      ##   |internal_data| : JSON object: The comment's internal data.
      ##   Only when |with_internal_data| is true.
      ##
      ##   Statuses.

      return Promise->all ([
        $self->target,
      ])->then (sub {
        my ($target) = @{$_[0]};
        return [] if $target->not_found;
        
        my $where = {
          ($self->app_id_columns),
          ($target->no_target ? () : ($target->to_columns)),
        };

        my $comment_id = $self->{app}->bare_param ('comment_id');
        if (defined $comment_id) {
          $where->{comment_id} = $comment_id;
        } else {
          return $self->throw
              ({reason => 'Either target or |comment_id| is required'})
              if $target->no_target;
        }

        # XXX status filter
        # XXX paging
        return $self->db->select ('comment', $where, fields => [
          'comment_id',
          'author_account_id',
          'data',
          ($self->{app}->bare_param ('with_internal_data') ? ('internal_data') : ()),
          'author_status', 'target_owner_status', 'admin_status',
        ], source_name => 'master', order => ['timestamp', 'desc'])->then (sub {
          return $_[0]->all->to_a;
        });
      })->then (sub {
        my $items = $_[0];
        for my $item (@$items) {
          $item->{comment_id} .= '';
          $item->{author_account_id} .= '';
          $item->{data} = Dongry::Type->parse ('json', $item->{data});
          $item->{internal_data} = Dongry::Type->parse ('json', $item->{internal_data})
              if defined $item->{internal_data};
          # XXX target
        }
        return $self->json ({items => $items});
      });
    } elsif (@{$self->{path}} == 1 and $self->{path}->[0] eq 'post.json') {
      ## /{app_id}/comment/post.json - Add a new comment.
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
      ## Created object response.
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
          author_account_id => $self->optional_account_id_param ('author'),
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
    } elsif (@{$self->{path}} == 1 and $self->{path}->[0] eq 'edit.json') {
      ## /{app_id}/comment/edit.json - Edit a comment.
      ##
      ## Parameters.
      ##
      ##   |comment_id| : ID : The comment's ID.
      ##
      ##   |data_delta| : JSON object : New comment's data.  Unchanged
      ##   name/value pairs can be omitted.  Removed names should be
      ##   set to |null| values.  Optional if nothing to change.
      ##
      ##   |internal_data_delta| : JSON object : New comment's
      ##   internal data.  Unchanged name/value pairs can be omitted.
      ##   Removed names should be set to |null| values.  Optional if
      ##   nothing to change.
      ##
      ##   Statuses : The comment's statuses.  Optional if nothing to
      ##   change.
      ##
      ## Response.  No additional data.

      return $self->db->transaction->then (sub {
        my $tr = $_[0];
        return Promise->resolve->then (sub {
          return $tr->select ('comment', {
            ($self->app_id_columns),
            comment_id => $self->id_param ('comment'),
          }, fields => [
            'comment_id', 'data', 'internal_data',
            'author_status', 'target_owner_status', 'admin_status',
          ], lock => 'update');
        })->then (sub {
          my $current = $_[0]->first;
          return $self->throw ({reason => 'Object not found'})
              unless defined $current;

          # XXX author validation
          # XXX operator
          
          my $updates = {};
          for my $name (qw(data internal_data)) {
            my $delta = $self->optional_json_object_param ($name.'_delta');
            next unless defined $delta;
            next unless keys %$delta;
            $updates->{$name} = Dongry::Type->parse ('json', $current->{$name});
            my $changed = 0;
            for (keys %$delta) {
              if (defined $delta->{$_}) {
                if (not defined $updates->{$name}->{$_} or
                    $updates->{$name}->{$_} ne $delta->{$_}) {
                  $updates->{$name}->{$_} = $delta->{$_};
                  $changed = 1;
                  if ($_ eq 'timestamp') {
                    $updates->{timestamp} = 0+$updates->{$name}->{$_};
                  }
                }
              } else {
                if (defined $updates->{$name}->{$_}) {
                  delete $updates->{$name}->{$_};
                  $changed = 1;
                  if ($_ eq 'timestamp') {
                    $updates->{timestamp} = 0;
                  }
                }
              }
            }
            delete $updates->{$name} unless $changed;
          } # $name
          for (qw(author_status target_owner_status admin_status)) {
            my $v = $self->{app}->bare_param ($_);
            next unless defined $v;
            return $self->throw ({reason => "Bad |$_|"})
                unless $v =~ /\A[1-9][0-9]*\z/ and 1 < $v and $v < 255;
            $updates->{$_} = 0+$v if $current->{$_} != $v;
          } # status

          for (qw(data internal_data)) {
            $updates->{$_} = Dongry::Type->serialize ('json', $updates->{$_})
                if defined $updates->{$_};
          }
          
          unless (keys %$updates) {
            $self->json ({});
            return $self->{app}->throw;
          }

          return $tr->update ('comment', $updates, where => {
            ($self->app_id_columns),
            comment_id => $current->{comment_id},
          });

          # XXX status change history
          # XXX notifications
        })->then (sub {
          return $tr->commit->then (sub { undef $tr });
        })->finally (sub {
          return $tr->rollback if defined $tr;
        }); # transaction
      })->then (sub {
        return $self->json ({});
      });
    }
  } # comment

  if ($self->{type} eq 'star') {
    if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'add.json') {
      ## /{app_id}/star/add.json - Add a star.
      ##
      ## Parameters.
      ##
      ##   Target : The star's target.
      ##
      ##   |target_author_account_id| : Account ID : The star's
      ##   target's author.  Optional if no author (anonymous or
      ##   unknown or unspecified).  The target's author cannot be
      ##   changed.
      ##
      ##   |author_account_id| : Account ID : The star's author.
      ##   Optional if no author (anonymous).
      ##
      ## Response.  No additional data.
      return Promise->all ([
        $self->new_target_list (['item_target_key', 'target_key']),
      ])->then (sub {
        my ($item_target, $target) = @{$_[0]->[0]};
        
        my $delta = 0+($self->{app}->bare_param ('delta') || 0); # can be negative
        return unless $delta;

        my $time = time;
        return $self->db->insert ('star', [{
          ($self->app_id_columns),
          ($target->to_columns),
          target_author_account_id => $self->optional_account_id_param ('target_author'),
          author_account_id => $self->optional_account_id_param ('author'),
          count => $delta > 0 ? $delta : 0,
          ($item_target->to_columns ('item')),
          created => $time,
          updated => $time,
        }], duplicate => {
          count => $self->db->bare_sql_fragment (sprintf 'greatest(cast(`count` as signed) + %d, 0)', $delta),
          updated => $self->db->bare_sql_fragment ('VALUES(updated)'),
        }, source_name => 'master');
      })->then (sub {
        return $self->json ({});
      });
    } elsif (@{$self->{path}} == 1 and $self->{path}->[0] eq 'get.json') {
      ## /{app_id}/star/get.json - Get stars of targets.
      ##
      ## Parameters.
      ##
      ##   Targets.
      ##
      ## Response.
      ##
      ##   |stars| : Object.
      ##
      ##     {|target_key| : Key : A target} : Array.
      ##
      ##       |author_account_id| : Account ID : The star's author.
      ##
      ##       |item_target_key| : Key : The star's item target.
      ##
      ##       |count| : Integer : The number of stars.
      return Promise->all ([
        $self->target_list,
      ])->then (sub {
        my $targets = $_[0]->[0];

        my @target_id;
        for (@$targets) {
          push @target_id, $_->target_id unless $_->is_error;
        }
        return {} unless @target_id;
        
        return $self->db->select ('star', {
          ($self->app_id_columns),
          target_id => {-in => \@target_id},
          count => {'>', 0},
        }, fields => [
          'target_id',
          'item_target_id', 'count', 'author_account_id',
        ], order => ['created', 'ASC'], source_name => 'master')->then (sub {
          my $stars = {};
          my @star;
          my @item_target_id;
          for (@{$_[0]->all}) {
            push @item_target_id, $_->{item_target_id};
            my $star = {
              author_account_id => _opt_id $_->{author_account_id},
              count => $_->{count},
              item_target_id => $_->{item_target_id},
            };
            push @star, $star;
            push @{$stars->{$_->{target_id}} ||= []}, $star;
          }
          return $self->target_list_by_ids (\@item_target_id)->then (sub {
            my $map = $_[0];
            for (@star) {
              my $v = $map->{delete $_->{item_target_id}};
              $_->{item_target_key} = $v->target_key if defined $v;
            }
            return $stars;
          });
        });
      })->then (sub {
        my $id_to_stars = $_[0];
        my $stars = {};
        return $self->target_list_by_ids ([keys %$id_to_stars])->then (sub {
          my $map = $_[0];
          for my $id (keys %$id_to_stars) {
            $stars->{$map->{$id}->target_key} = $id_to_stars->{$id};
          }
          return $self->json ({stars => $stars});
        });
      });
      

      #XXX
      # list.json?target_author_account_id=...
      # list.json?author_account_id=...

      # XXX target parent
      # XXX author replacer
      
    }
  } # star
  
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
