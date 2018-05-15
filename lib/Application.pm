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

use NObj;
use Pager;

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
##   |items| : JSON array : Objects.
##
##   |has_next| : Boolean : Whether there is the next page or not.
##
##   |next_ref| : Ref ? : The |ref| string that can be used to obtain
##   the next page.
##
## Pages.  End points with list response accepts page parameters.
##
##   |limit| : Integer : The maximum number of the objects in a list
##   response.
##
##   |ref| : Ref : A string that identifies the page that should be
##   returned.
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

## Status.  An integer representing the object's status (e.g. "open",
## "closed", "public", "private", "banned", and so on).  It must be in
## the range [2, 254].
##
## Statuses.  A pair of status values.  Parameters:
##
##   |author_status| : Status : The status by the author.
##
##   |owner_status| : Status : The status by the owner(s).  The
##   interpretation of "owner" is application-dependent.  For example,
##   a comment's owner can be the comment's thread's author.
##
##   |admin_status| : Status : The status by the administrator(s) of
##   the application.
sub status_columns ($) {
  my $self = $_[0];
  my $w = {};
  for (qw(author_status owner_status admin_status)) {
    my $v = $self->{app}->bare_param ($_) // '';
    return $self->throw ({reason => "Bad |$_|"})
        unless $v =~ /\A[1-9][0-9]*\z/ and 1 < $v and $v < 255;
    $w->{$_} = 0+$v;
  }
  return %$w;
} # status_columns

sub status_filter_columns ($) {
  my $self = $_[0];
  my $r = {};
  for (qw(author_status owner_status admin_status)) {
    my $v = $self->{app}->bare_param_list ($_);
    next unless @$v;
    $r->{$_} = {-in => $v};
  }
  return %$r;
} # status_filter_columns

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

## Named object (NObj).  An NObj is an object or concept in the
## application.  It is externally identified by a Key in the API or
## internally by an ID on the straoge.  The key can be any value
## assigned by the application.  The ID is assigned by Apploach.  It
## can be used to represent an object stored in Apploach, such as a
## comment or a tag, an external object such as account, or an
## abstract concept such as "blogs", "bookmarks of a user", or
## "anonymous".
##
## Sometimes "author" of an NObj can be specified, which is not part
## of the canonical data model of Apploach object but is necessary for
## indexing.
##
## In addition, "index" value for an NObj can be specified, which is
## not part of the canoncial data model of Apploach object but is used
## for indexing.
##
## NObj (/prefix/) is an NObj, specified by the following parameter:
##
##   |/prefix/_nobj_key| : Key : The NObj's key.
##
## NObj (/prefix/ with author) has the following additional parameter:
##
##   |/prefix/_author_nobj_key| : Key : The NObj's author's key.
##
## NObj (/prefix/ with index) has the following additional parameter:
##
##   |/prefix/_index_nobj_key| : Key : The NObj's additional index's
##   key.  If the additional indexing is not necessary, an
##   application-dependent dummy value such as "-" should be specified
##   as filler.
##
## NObj list (/prefix/) are zero or more NObj, specified by the
## following parameters:
##
##   |/prefix/_nobj_key| : Key : The NObj's key.  Zero or more
##   parameters can be specified.
sub new_nobj_list ($$) {
  my ($self, $params) = @_;
  my @key = map { $self->{app}->bare_param ($_.'_nobj_key') } @$params;
  return $self->_no (\@key)->then (sub {
    my $nos = $_[0];
    return promised_map {
      my $param = $params->[$_[0]];
      my $nobj_key = $key[$_[0]];
      my $no = $nos->[$_[0]];

      return $self->throw ({reason => 'Bad |'.$param.'_nobj_key|'})
          if $no->missing or $no->invalid_key;
      return $no unless $no->not_found;

      # not found
      my $nobj_key_sha = sha1_hex $nobj_key;
      return $self->ids (1)->then (sub {
        my $id = $_[0]->[0];
        return $self->db->insert ('nobj', [{
          ($self->app_id_columns),
          nobj_id => $id,
          nobj_key => $nobj_key,
          nobj_key_sha => $nobj_key_sha,
          timestamp => time,
        }], source_name => 'master', duplicate => 'ignore');
      })->then (sub {
        return $self->db->select ('nobj', {
          ($self->app_id_columns),
          nobj_key_sha => $nobj_key_sha,
          nobj_key => $nobj_key,
        }, fields => ['nobj_id'], limit => 1, source_name => 'master');
      })->then (sub {
        my $v = $_[0]->first;
        if (defined $v) {
          my $t = NObj->new (nobj_id => $v->{nobj_id},
                             nobj_key => $nobj_key);
          $self->{nobj_id_to_object}->{$v->{nobj_id}} = $t;
          $self->{nobj_key_to_object}->{$nobj_key} = $t;
          return $t;
        }
        die "Can't generate |nobj_id| for |$nobj_key|";
      });
    } [0..$#key];
  });
} # new_nobj_list

sub nobj ($$) {
  my ($self, $param) = @_;
  return $self->_no ([$self->{app}->bare_param ($param.'_nobj_key')])->then (sub {
    return $_[0]->[0];
  });
} # nobj

sub one_nobj ($$) {
  my ($self, $params) = @_;
  my $n;
  my $w;
  for my $param (@$params) {
    my $v = $self->{app}->bare_param ($param.'_nobj_key');
    if (defined $v) {
      $n = $param;
      $w = $v;
      last;
    }
  }
  return $self->_no ([$w])->then (sub {
    return [$n, $_[0]->[0]];
  });
} # one_nobj

sub nobj_list ($$) {
  my ($self, $param) = @_;
  return $self->_no ($self->{app}->bare_param_list ($param.'_nobj_key'));
} # nobj_list

sub _no ($$) {
  my ($self, $nobj_keys) = @_;
  my @key;
  my $results = [map {
    my $nobj_key = $_;
    if (not defined $nobj_key) {
      NObj->new (missing => 1);
    } elsif (not length $nobj_key or 4095 < length $nobj_key) {
      NObj->new (not_found => 1, invalid_key => 1, nobj_key => $nobj_key);
    } elsif (defined $self->{nobj_key_to_object}->{$nobj_key}) {
      $self->{nobj_key_to_object}->{$nobj_key};
    } else {
      my $nobj_key_sha = sha1_hex $nobj_key;
      push @key, [$nobj_key, $nobj_key_sha];
      $nobj_key;
    }
  } @$nobj_keys];
  return Promise->resolve->then (sub {
    return unless @key;
    return $self->db->select ('nobj', {
      ($self->app_id_columns),
      nobj_key_sha => {-in => [map { $_->[1] } @key]},
      nobj_key => {-in => [map { $_->[0] } @key]},
    }, fields => ['nobj_id', 'nobj_key'], source_name => 'master')->then (sub {
      for (@{$_[0]->all}) {
        my $t = NObj->new (nobj_id => $_->{nobj_id},
                           nobj_key => $_->{nobj_key});
        $self->{nobj_key_to_object}->{$_->{nobj_key}} = $t;
        $self->{nobj_id_to_object}->{$_->{nobj_id}} = $t;
      }
    });
  })->then (sub {
    $results = [map {
      if (ref $_ eq 'NObj') {
        $_;
      } else {
        if ($self->{nobj_key_to_object}->{$_}) {
          $self->{nobj_key_to_object}->{$_};
        } else {
          NObj->new (not_found => 1, nobj_key => $_);
        }
      }
    } @$results];
    return $results;
  });
} # _no

sub replace_nobj_ids ($$$) {
  my ($self, $items, $fields) = @_;
  my $keys = {};
  for my $item (@$items) {
    for my $field (@$fields) {
      $keys->{$item->{$field.'_nobj_id'}}++;
    }
  }
  return $self->_nobj_list_by_ids ([keys %$keys])->then (sub {
    my $map = $_[0];
    for my $item (@$items) {
      for my $field (@$fields) {
        my $v = $map->{delete $item->{$field.'_nobj_id'}};
        $item->{$field.'_nobj_key'} = $v->nobj_key
            if defined $v and not $v->is_error;
      }
    }
    return $items;
  });
} # replace_nobj_ids

sub _nobj_list_by_ids ($$) {
  my ($self, $ids) = @_;
  return Promise->resolve->then (sub {
    my @id;
    my $results = [map {
      if (defined $self->{nobj_id_to_object}->{$_}) {
        $self->{nobj_id_to_object}->{$_};
      } else {
        push @id, $_;
        $_;
      }
    } @$ids];
    return $results unless @id;
    return $self->db->select ('nobj', {
      ($self->app_id_columns),
      nobj_id => {-in => \@id},
    }, fields => ['nobj_id', 'nobj_key'], source_name => 'master')->then (sub {
      for (@{$_[0]->all}) {
        my $t = NObj->new (nobj_id => $_->{nobj_id},
                           nobj_key => $_->{nobj_key});
        $self->{nobj_key_to_object}->{$_->{nobj_key}} = $t;
        $self->{nobj_id_to_object}->{$_->{nobj_id}} = $t;
      }
      return [map {
        if (ref $_ eq 'NObj') {
          $_;
        } else {
          $self->{nobj_id_to_object}->{$_} // die "NObj |$_| not found";
        }
      } @$ids];
    });
  })->then (sub {
    return {map { $_->nobj_id => $_ } @{$_[0]}};
  });
} # _nobj_list_by_ids

sub run ($) {
  my $self = $_[0];

  if ($self->{type} eq 'comment') {
    ## Comments.  A thread can have zero or more comments.  A comment
    ## has ID : ID, thread : NObj, author : NObj, data : JSON object,
    ## internal data : JSON object, statuses : Statuses.
    if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'list.json') {
      ## /{app_id}/comment/list.json - Get comments.
      ##
      ## Parameters.
      ##
      ##   NObj (|thread|) : The comment's thread.
      ##
      ##   |comment_id| : ID : The comment's ID.  Either the thread or
      ##   the ID, or both, is required.  If the thread is specified,
      ##   returned comments are limited to those for the thread.  If
      ##   |comment_id| is specified, it is further limited to one
      ##   with that |comment_id|.
      ##
      ##   |with_internal_data| : Boolean : Whether |internal_data|
      ##   should be returned or not.
      ##
      ##   Status filters.
      ##
      ##   Pages.
      ##
      ## List response of comments.
      ##
      ##   NObj (|thread|) : The comment's thread.
      ##
      ##   |comment_id| : ID : The comment's ID.
      ##
      ##   NObj (|author|) : The comment's author.
      ##
      ##   |data| : JSON object : The comment's data.
      ##
      ##   |internal_data| : JSON object: The comment's internal data.
      ##   Only when |with_internal_data| is true.
      ##
      ##   Statuses.
      my $page = Pager::this_page ($self, limit => 10, max_limit => 100);
      return Promise->all ([
        $self->nobj ('thread'),
      ])->then (sub {
        my $thread = $_[0]->[0];
        return [] if $thread->not_found;

        my $where = {
          ($self->app_id_columns),
          ($thread->missing ? () : ($thread->to_columns ('thread'))),
          ($self->status_filter_columns),
        };
        $where->{timestamp} = $page->{value} if defined $page->{value};
        
        my $comment_id = $self->{app}->bare_param ('comment_id');
        if (defined $comment_id) {
          $where->{comment_id} = $comment_id;
        } else {
          return $self->throw
              ({reason => 'Either thread or |comment_id| is required'})
              if $thread->missing;
        }

        return $self->db->select ('comment', $where, fields => [
          'comment_id',
          'thread_nobj_id',
          'author_nobj_id',
          'data',
          ($self->{app}->bare_param ('with_internal_data') ? ('internal_data') : ()),
          'author_status', 'owner_status', 'admin_status',
          'timestamp',
        ], source_name => 'master',
          offset => $page->{offset}, limit => $page->{limit},
          order => ['timestamp', $page->{order_direction}],
        )->then (sub {
          return $_[0]->all->to_a;
        });
      })->then (sub {
        my $items = $_[0];
        for my $item (@$items) {
          $item->{comment_id} .= '';
          $item->{data} = Dongry::Type->parse ('json', $item->{data});
          $item->{internal_data} = Dongry::Type->parse ('json', $item->{internal_data})
              if defined $item->{internal_data};
        }
        return $self->replace_nobj_ids ($items, ['author', 'thread'])->then (sub {
          my $next_page = Pager::next_page $page, $items, 'timestamp';
          delete $_->{timestamp} for @$items;
          return $self->json ({items => $items, %$next_page});
        });
      });
    } elsif (@{$self->{path}} == 1 and $self->{path}->[0] eq 'post.json') {
      ## /{app_id}/comment/post.json - Add a new comment.
      ##
      ## Parameters.
      ##
      ##   NObj (|thread|) : The comment's thread.
      ##
      ##   Statuses : The comment's statuses.
      ##
      ##   NObj (|author|) : The comment's author.
      ##
      ##   |data| : JSON object : The comment's data.  Its |timestamp|
      ##   is replaced by the time Apploach accepts the comment.
      ##
      ##   |internal_data| : JSON object : The comment's internal
      ##   data, intended for storing private data such as author's IP
      ##   address.
      ##
      ## Created object response.
      ##
      ##   |comment_id| : ID : The comment's ID.
      ##
      ##   |timestamp| : Timestamp : The comment's data's timestamp.
      return Promise->all ([
        $self->new_nobj_list (['thread', 'author']),
        $self->ids (1),
      ])->then (sub {
        my (undef, $ids) = @{$_[0]};
        my ($thread, $author) = @{$_[0]->[0]};
        my $data = $self->json_object_param ('data');
        my $time = time;
        $data->{timestamp} = $time;
        return $self->db->insert ('comment', [{
          ($self->app_id_columns),
          ($thread->to_columns ('thread')),
          comment_id => $ids->[0],
          ($author->to_columns ('author')),
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
      ##   |data_delta| : JSON object : The comment's new data.
      ##   Unchanged name/value pairs can be omitted.  Removed names
      ##   should be set to |null| values.  Optional if nothing to
      ##   change.
      ##
      ##   |internal_data_delta| : JSON object : The comment's new
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
            'author_status', 'owner_status', 'admin_status',
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
          for (qw(author_status owner_status admin_status)) {
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
    ## Stars.  A starred NObj can have zero or more stars.  A star has
    ## starred NObj : NObj, author : NObj, item : NObj, count :
    ## Integer.
    if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'add.json') {
      ## /{app_id}/star/add.json - Add a star.
      ##
      ## Parameters.
      ##
      ##   NObj (|starred| with author and index) : The star's starred
      ##   NObj.  For example, a blog entry.
      ##
      ##   NObj (|author|) : The star's author.
      ##
      ##   NObj (|item|) : The star's item.  It represents the type of
      ##   the star.
      ##
      ##   |delta| : Integer : The difference of the new and the
      ##   current numbers of the star's count.
      ##
      ## Response.  No additional data.
      return Promise->all ([
        $self->new_nobj_list (['item', 'author',
                               'starred', 'starred_author', 'starred_index']),
      ])->then (sub {
        my ($item, $author,
            $starred, $starred_author, $starred_index) = @{$_[0]->[0]};
        
        my $delta = 0+($self->{app}->bare_param ('delta') || 0); # can be negative
        return unless $delta;

        my $time = time;
        return $self->db->insert ('star', [{
          ($self->app_id_columns),
          ($starred->to_columns ('starred')),
          ($starred_author->to_columns ('starred_author')),
          ($starred_index->to_columns ('starred_index')),
          ($author->to_columns ('author')),
          count => $delta > 0 ? $delta : 0,
          ($item->to_columns ('item')),
          created => $time,
          updated => $time,
        }], duplicate => {
          count => $self->db->bare_sql_fragment (sprintf 'greatest(cast(`count` as signed) + %d, 0)', $delta),
          updated => $self->db->bare_sql_fragment ('VALUES(updated)'),
        }, source_name => 'master');
      })->then (sub {
        return $self->json ({});
      });
      # XXX notification hook
    } elsif (@{$self->{path}} == 1 and $self->{path}->[0] eq 'get.json') {
      ## /{app_id}/star/get.json - Get stars for rendering.
      ##
      ## Parameters.
      ##
      ##   NObj list (|starred|).  List of starred NObj to get.
      ##
      ## Response.
      ##
      ##   |stars| : Object.
      ##
      ##     {NObj (|starred|) : The star's starred} : Array of stars.
      ##
      ##       NObj (|author|) : The star's author.
      ##
      ##       NObj (|item|) : The star's item.
      ##
      ##       |count| : Integer : The star's count.
      return Promise->all ([
        $self->nobj_list ('starred'),
      ])->then (sub {
        my $starreds = $_[0]->[0];

        my @nobj_id;
        for (@$starreds) {
          push @nobj_id, $_->nobj_id unless $_->is_error;
        }
        return [] unless @nobj_id;
        
        return $self->db->select ('star', {
          ($self->app_id_columns),
          starred_nobj_id => {-in => \@nobj_id},
          count => {'>', 0},
        }, fields => [
          'starred_nobj_id',
          'item_nobj_id', 'count', 'author_nobj_id',
        ], order => ['created', 'ASC'], source_name => 'master')->then (sub {
          return $_[0]->all;
        });
      })->then (sub {
        return $self->replace_nobj_ids ($_[0], ['author', 'item', 'starred']);
      })->then (sub {
        my $stars = {};
        for (@{$_[0]}) {
          push @{$stars->{delete $_->{starred_nobj_key}} ||= []}, $_;
        }
        return $self->json ({stars => $stars});
      });
    } elsif (@{$self->{path}} == 1 and $self->{path}->[0] eq 'list.json') {
      ## /{app_id}/star/list.json - Get stars for listing.
      ##
      ## Parameters.
      ##
      ##   NObj (|author|) : The star's author.
      ##
      ##   NObj (|starred_author|) : The star's starred NObj's author.
      ##   Either NObj (|author|) or NObj (|starred_author|) is
      ##   required.
      ##
      ##   NObj (|starred_index|) : The star's starred NObj's index.
      ##   Optional.  The list is filtered by both star's author or
      ##   starred NObj's author and NObj's index, if specified.
      ##
      ##   Pages.
      ##
      ## List response of stars.
      ##
      ##   NObj (|starred|) : The star's starred NObj.
      ##
      ##   NObj (|author|) : The star's author.
      ##
      ##   NObj (|item|) : The star's item.
      ##
      ##   |count| : Integer : The star's count.
      my $page = Pager::this_page ($self, limit => 10, max_limit => 100);
      return Promise->all ([
        $self->one_nobj (['author', 'starred_author']),
        $self->nobj ('starred_index'),
      ])->then (sub {
        my ($name, $nobj) = @{$_[0]->[0]};
        my $starred_index = $_[0]->[1];
        
        return [] if $nobj->is_error;
        return [] if $starred_index->is_error and not $starred_index->missing;

        my $where = {
          ($self->app_id_columns),
          ($nobj->to_columns ($name)),
          count => {'>', 0},
        };
        unless ($starred_index->missing) {
          $where = {%$where, ($starred_index->to_columns ('starred_index'))};
        }
        $where->{updated} = $page->{value} if defined $page->{value};

        return $self->db->select ('star', $where, fields => [
          'starred_nobj_id',
          'item_nobj_id', 'count', 'author_nobj_id',
          'updated',
        ], source_name => 'master',
          offset => $page->{offset}, limit => $page->{limit},
          order => ['updated', $page->{order_direction}],
        )->then (sub {
          return $_[0]->all->to_a;
        });
      })->then (sub {
        return $self->replace_nobj_ids ($_[0], ['author', 'item', 'starred']);
      })->then (sub {
        my $items = $_[0];
        my $next_page = Pager::next_page $page, $items, 'updated';
        delete $_->{updated} for @$items;
        return $self->json ({items => $items, %$next_page});
      });
    }
  } # star

  if ($self->{type} eq 'nobj') {
    if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'changeauthor.json') {
      ## /{app_id}/nobj/changeauthor.json - Change the author of an
      ## NObj.
      ##
      ## Parameters.
      ##
      ##   NObj (|subject|) - The NObj.
      ##
      ##   NObj (|author|) - The new author.
      ##
      ## Response.  No additional data.
      return Promise->all ([
        $self->new_nobj_list (['subject', 'author']),
      ])->then (sub {
        my ($subject, $author) = @{$_[0]->[0]};
        return $self->db->update ('star', {
          ($author->to_columns ('starred_author')),
        }, where => {
          ($self->app_id_columns),
          ($subject->to_columns ('starred')),
        })->then (sub {
          return $self->json ({});
        });
      });
    }
  } # nobj
  
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
