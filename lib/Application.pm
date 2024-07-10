package Application;
use strict;
use warnings;
use Time::HiRes qw(time);
use JSON::PS;
use Digest::SHA qw(sha1_hex);
use POSIX qw(ceil);
use Dongry::Type;
use Dongry::Type::JSONPS;
use Promise;
use Promised::Flow;
use Web::DomainName::Punycode;
use Web::Encoding;
use Web::Encoding::Normalization;
use Web::URL;
use Web::DOM::Document;
use Web::XML::Parser;
use Web::Transport::Base64;
use Web::Transport::AWS;
use Web::DateTime;
use Web::DateTime::Clock;
use Web::DateTime::Parser;
use Web::Transport::BasicClient;
use Crypt::Perl::ECDSA::Parse;

use NObj;
use Pager;

## Configurations.  The path to the configuration JSON file must be
## specified to the |APP_CONFIG| environment variable.  The JSON file
## must contain an object with following name/value pairs:
##
##   |is_test_script| : Boolean : Whether it is a test script or not.
##
##   |bearer| : Key : The bearer (API key).
##
##   |dsn| : String : The DSN of the MySQL database.
##
##   |ikachan_url_prefix| : String? : The prefix of the
##   Ikachan-compatible Web API to which errors are reported.  If not
##   specified, errors are not sent.
##
##   |ikachan_channel| : String? : The channel to which errors are
##   sent.  Required if |ikachan_url_prefix| is specified.
##
##   |ikachan_message_prefix| : String? : A short string used as the
##   prefix of the error message.  Required if |ikachan_url_prefix| is
##   specified.
##
##   |s3_aws4| : Array of four Strings : The access key ID, the secret
##   access key, the AWS region such as C<us-east-1>, and the AWS
##   service such as C<s3>, used to access to the storage server.
##   Required when the storage server is used.
##
##   |s3_sts_role_arn| : String? : The AWS STS role ARN.  If
##   specified, it is used to generate upload forms.
##
##   |s3_bucket| : String : The bucket name on the storage server.
##   Required when the storage server is used.
##
##   |s3_form_url| : String : The URL of the bucket on the storage
##   server that is accessible from the client (who uploads files).
##   Required when the storage server is used.
##
##   |s3_file_url_prefix| : String : The URL scheme, host, optional
##   port, and path in the bucket on the storage server, under which
##   the files are stored.  Required when the storage server is used.
##
##   |s3_file_url_signed_hostport| : String : The hostport of the
##   storage server, used to sign file URLs.  Required when it is
##   different from |s3_file_url_prefix|'s hostport.
##
##   |push_application_server_key_public| : Array of Uint8 : The
##   public key of the application server in the context of the Push
##   API and VAPID.  If |push_application_server_key_public./app_id/|
##   is specified, its value is used.  Otherwise, fallbacked to
##   |push_application_server_key_public|.
##
##   |push_application_server_key_private| : Array of Uint8 : The
##   private key of the application server in the context of the Push
##   API and VAPID.  If |push_application_server_key_private./app_id/|
##   is specified, its value is used.  Otherwise, fallbacked to
##   |push_application_server_key_private|.
##
## There must be a storage server that has AWS S3 compatible Web API,
## such as Minio, when storage-server-bound features are used.  The
## bucket must be configured such that files in the directory of
## |s3_file_url_prefix| are private (i.e. not readable by the world)
## and the |public/| directory in the directory of
## |s3_file_url_prefix| are public (i.e. readable by the world).  We
## don't use |x-aws-acl:| header as it is not supported by Minio.

sub error_log ($$$$) {
  my ($class, $config, $important, $message) = @_;
  warn $message;
  return undef unless defined $config->{ikachan_url_prefix};
  my $url = Web::URL->parse_string ($config->{ikachan_url_prefix});
  my $con = Web::Transport::BasicClient->new_from_url ($url);
  $con->request (
    path => [$important ? 'privmsg' : 'notice'],
    method => 'POST', params => {
      channel => $config->{ikachan_channel},
      message => (sprintf "%s%s", $config->{ikachan_message_prefix}, $message),
    },
  )->finally (sub {
    return $con->close;
  });
  return undef;
} # error_log

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
##   |reversed| : Boolean : Whether the |items| are in reverse order
##   or not.  The |items| are in reversed order if the order is
##   different from the order that would be returned in case no
##   special parameter is given.
##
##   |has_next| : Boolean : Whether there is the next page or not.
##
##   |next_ref| : Ref ? : The |ref| string of the Pages parameter set
##   that can be used to obtain the next page.
##
##   |has_prev| : Boolean : Whether there is the previous page or not.
##   Note that this flag might not be reliable.
##
##   |prev_ref| : Ref ? : The |ref| string of the Pages parameter set
##   that can be used to obtain the previous page.  Note that this
##   value can be wrong when there are items with same timestamps
##   across the page boundary.
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
## ID.  A non-zero 64-bit unsigned integer.  The underlying MySQL
## server has to be properly configured such that |uuid_short()|
## returns unique identifiers.
##
## Application ID.  The ID which identifies the application.  The
## application defines the scope of the objects.
##
## Account ID.  The ID of an account in the scope of the application.
##
## String.  A Unicode string.
##
## Language.  An ASCII string whose length is less than or equal to
## 40.  Though its semantics is application specific, the value should
## be a BCP 47 language tag normalized in an application defined way.
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

sub json_object_list_param ($$) {
  my ($self, $name) = @_;
  my @v;
  for my $v (@{$self->{app}->bare_param_list ($name)}) {
    my $w = json_bytes2perl $v;
    if (defined $w and ref $w eq 'HASH') {
      push @v, $w;
    } else {
      return $self->throw ({reason => 'Bad JSON parameter |'.$name.'|'});
    }
  }
  return \@v;
} # json_object_list_param

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

sub sha ($) {
  return sha1_hex +Dongry::Type->serialize ('text', $_[0]);
} # sha

sub db ($) {
  my $self = $_[0];
  return $self->{app}->http->server_state->data->{dbs}->{main};
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

sub db_ids ($$$) {
  my ($self, $db_or_tr, $n) = @_;
  return Promise->resolve ([]) unless $n;
  my $v = join ',', map { sprintf 'uuid_short() as `%d`', $_ } 0..($n-1);
  return $db_or_tr->execute ('select '.$v, undef, source_name => 'master')->then (sub {
    my $w = $_[0]->first;
    my $r = [];
    for (keys %$w) {
      $r->[$_] = $w->{$_};
    }
    return $r;
  });
} # db_ids

## Named object (NObj).  An NObj is an object or concept in the
## application.  It is externally identified by a Key in the API or
## internally by an ID on the straoge.  The key can be any value
## assigned by the application, though any key starting with
## "apploach-" might have specific semantics assigned by some APIs of
## Apploach.  The ID is assigned by Apploach.  It can be used to
## represent an object stored in Apploach, such as a comment or a tag,
## an external object such as account, or an abstract concept such as
## "blogs", "bookmarks of a user", or "anonymous".
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
  my @key = map { ref $_ ? $$_ : $self->{app}->bare_param ($_.'_nobj_key') } @$params;
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

sub nobj_list_by_values ($$) {
  my ($self, $values) = @_;
  return $self->_no ($values);
} # nobj_list_by_values

sub nobj_list_set ($$) {
  my ($self, $params) = @_;
  my @key;
  my $lists = {};
  for my $param (@$params) {
    $lists->{$param} = $self->{app}->bare_param_list ($param.'_nobj_key');
    push @key, @{$lists->{$param}};
  }
  return $self->_no (\@key)->then (sub {
    return Promise->all ([map { $self->_no ($lists->{$_}) } @$params]);
  });
} # nobj_list_set

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
  return $self->_nobj_list_by_ids ($self->db, [keys %$keys])->then (sub {
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

sub _nobj_ids_to_nobj ($$$$) {
  my ($self, $db_or_tr, $items, $fields) = @_;
  my $keys = {};
  for my $item (@$items) {
    for my $field (@$fields) {
      $keys->{$item->{$field.'_nobj_id'}}++;
    }
  }
  return $self->_nobj_list_by_ids ($db_or_tr, [keys %$keys])->then (sub {
    my $map = $_[0];
    for my $item (@$items) {
      for my $field (@$fields) {
        my $v = $map->{delete $item->{$field.'_nobj_id'}};
        $item->{$field} = $v if defined $v and not $v->is_error;
      }
    }
    return $items;
  });
} # replace_nobj_ids_to_nobj

sub _nobj_list_by_ids ($$$) {
  my ($self, $db_or_tr, $ids) = @_;
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
    return $db_or_tr->select ('nobj', {
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
          $self->{nobj_id_to_object}->{$_} // do {
            if ($_ eq '0') {
              ();
            } else {
              die "NObj |$_| not found";
            }
          };
        }
      } @$ids];
    });
  })->then (sub {
    return {map { $_->nobj_id => $_ } @{$_[0]}};
  });
} # _nobj_list_by_ids

sub write_log ($$$$$$$) {
  my ($self, $db_or_tr, $operator, $target, $target_index, $verb, $data) = @_;
  return $self->db_ids ($db_or_tr, 1)->then (sub {
    my ($log_id) = @{$_[0]};
    my $time = $data->{timestamp} = 0+($data->{timestamp} // time);
    return $db_or_tr->insert ('log', [{
      ($self->app_id_columns),
      log_id => $log_id,
      ($operator->to_columns ('operator')),
      ($target->to_columns ('target')),
      ((defined $target_index and not $target_index->is_error) ? $target_index->to_columns ('target_index') : (target_index_nobj_id => 0)),
      ($verb->to_columns ('verb')),
      data => Dongry::Type->serialize ('json', $data),
      timestamp => $time,
    }], source_name => 'master')->then (sub {
      return {
        log_id => ''.$log_id,
        timestamp => $time,
      };
    });
  });
} # write_log

sub set_status_info ($$$$$$$) {
  my ($self, $db_or_tr, $operator, $target, $verb, $data, $d1, $d2, $d3) = @_;
  return $self->write_log ($db_or_tr, $operator, $target, undef, $verb, {
    data => $data,
    author_data => $d1,
    owner_data => $d2,
    admin_data => $d3,
  })->then (sub {
    $data->{timestamp} = $_[0]->{timestamp};
    $data->{log_id} = $_[0]->{log_id};
    return $db_or_tr->insert ('status_info', [{
      ($self->app_id_columns),
      ($target->to_columns ('target')),
      data => Dongry::Type->serialize ('json', $data),
      author_data => Dongry::Type->serialize ('json', $d1 // {}),
      owner_data => Dongry::Type->serialize ('json', $d2 // {}),
      admin_data => Dongry::Type->serialize ('json', $d3 // {}),
      timestamp => 0+$data->{timestamp},
    }], source_name => 'master', duplicate => {
      data => $self->db->bare_sql_fragment ('VALUES(`data`)'),
      (defined $d1 ? (author_data => $self->db->bare_sql_fragment ('VALUES(`author_data`)')) : ()),
      (defined $d2 ? (owner_data => $self->db->bare_sql_fragment ('VALUES(`owner_data`)')) : ()),
      (defined $d3 ? (admin_data => $self->db->bare_sql_fragment ('VALUES(`admin_data`)')) : ()),
      timestamp => $self->db->bare_sql_fragment ('VALUES(`timestamp`)'),
    });
  })->then (sub {
    return {
      timestamp => $data->{timestamp},
      log_id => $data->{log_id},
    };
  });
} # set_status_info

sub prepare_upload ($$%) {
  my ($self, $tr, %args) = @_;
  ## File upload parameters.
  ##
  ##   |mime_type| : String : The MIME type essence of the file to be
  ##   submitted.
  ##
  ##   |byte_length| : Integer : The byte length of the file to be
  ##   submitted.
  ##
  ##   |prefix| : String : The URL path prefix of the file in the
  ##   storage.
  ##
  ##   |signed_url_max_age| : Integer : The lifetime of the
  ##   |signed_url| to be returned.
  ##
  ## File upload information.
  ##
  ##   |form_data| : Object : The |name|/|value| pairs of |hidden|
  ##   form data.
  ##
  ##   |form_url| : String : The |action| URL of the form.
  ##
  ##   |form_expires| : Timestamp : The expiration time of the form.
  ##
  ##   |file| : Object.
  ##
  ##     |file_url| : String : The result URL of the file.  Note that
  ##     this URL is not world-accessible.
  ##
  ##     |public_file_url| : String : The result URL of the file that
  ##     is world-accessible, if the file is made public.
  ##
  ##     |signed_url| : String : A signed URL of the file, which can
  ##     be used to access to the file content.
  ##
  ##     |mime_type| : String : The MIME type of the file.
  ##
  ##     |byte_length| : Integer : The byte length of the file.
  return $self->db_ids ($tr, 1)->then (sub {
    my ($key) = @{$_[0]};
    $key = $args{prefix} . '/' . $key;

    die $self->throw ({reason => "Bad MIME type"})
        unless defined $args{mime_type} and
               $args{mime_type} =~ m{\A[\x21-\x7E]+\z};
    die $self->throw ({reason => "Bad byte length"})
        unless defined $args{byte_length} and
               $args{byte_length} =~ /\A[0-9]+\z/ and
               $args{byte_length} <= 10*1024*1024*1024;
               ## This is a hard limit.  Applications should enforce
               ## its own limit, if necessary.
    die "Bad prefix"
        unless defined $args{prefix} and length $args{prefix};

    $key .= {
      'image/png' => '.png',
      'image/jpeg' => '.jpeg',
    }->{$args{mime_type}} // '';
    
    #my $file_url = "https://$service-$region.amazonaws.com/$bucket/$key";
    #my $file_url = "https://$bucket/$key";
    my $file_url = $self->{config}->{s3_file_url_prefix} . $key;
    my $public_file_url = $self->{config}->{s3_file_url_prefix} . 'public/' . $key;
    my $bucket = $self->{config}->{s3_bucket};
    my $accesskey = $self->{config}->{s3_aws4}->[0];
    my $secret = $self->{config}->{s3_aws4}->[1];
    my $region = $self->{config}->{s3_aws4}->[2];
    my $token;
    my $expires;
    my $max_age = 60*60;
    my $now = time;
    
    return Promise->resolve->then (sub {
      my $sts_role_arn = $self->{config}->{s3_sts_role_arn};
      return unless defined $sts_role_arn;
      my $sts_url = Web::URL->parse_string
          (qq<https://sts.$region.amazonaws.com/>);
      my $sts_client = Web::Transport::BasicClient->new_from_url
          ($sts_url);
      $expires = $now + $max_age;
      return $sts_client->request (
        url => $sts_url,
        params => {
          Version => '2011-06-15',
          Action => 'AssumeRole',
          ## Maximum length = 64 (sha1_hex length = 40)
          RoleSessionName => 'apploach-' . sha $args{prefix},
          RoleArn => $sts_role_arn,
          Policy => perl2json_chars ({
            "Version" => "2012-10-17",
            "Statement" => [
              {'Sid' => "Stmt1",
               "Effect" => "Allow",
               "Action" => ["s3:PutObject", "s3:PutObjectAcl", "s3:GetObject"],
               "Resource" => "arn:aws:s3:::$bucket/*"},
            ],
          }),
          DurationSeconds => $max_age,
        },
        aws4 => [$accesskey, $secret, $region, 'sts'],
      )->then (sub {
        my $res = $_[0];
        die $res unless $res->status == 200;

        my $doc = new Web::DOM::Document;
        my $parser = new Web::XML::Parser;
        $parser->onerror (sub { });
        $parser->parse_byte_string ('utf-8', $res->body_bytes => $doc);
        $accesskey = $doc->get_elements_by_tag_name
            ('AccessKeyId')->[0]->text_content;
        $secret = $doc->get_elements_by_tag_name
            ('SecretAccessKey')->[0]->text_content;
        $token = $doc->get_elements_by_tag_name
            ('SessionToken')->[0]->text_content;
      });
    })->then (sub {
      my $acl = 'private';
      #my $redirect_url = ...;
      my $form_data = Web::Transport::AWS->aws4_post_policy
          (clock => Web::DateTime::Clock->realtime_clock,
           max_age => $max_age,
           access_key_id => $accesskey,
           secret_access_key => $secret,
           security_token => $token,
           region => $region,
           service => 's3',
           policy_conditions => [
             {"bucket" => $bucket},
             {"key", $key}, #["starts-with", q{$key}, $prefix],
             {"acl" => $acl},
             #{"success_action_redirect" => $redirect_url},
             {"Content-Type" => $args{mime_type}},
             ["content-length-range", $args{byte_length}, $args{byte_length}],
           ]);

      my $signed = Web::Transport::AWS->aws4_signed_url
          (clock => Web::DateTime::Clock->realtime_clock,
           max_age => $args{signed_url_max_age} // 60*10,
           access_key_id => $self->{config}->{s3_aws4}->[0],
           secret_access_key => $self->{config}->{s3_aws4}->[1],
           #security_token => $token,
           region => $self->{config}->{s3_aws4}->[2],
           service => 's3',
           method => 'GET',
           signed_hostport => $self->{config}->{s3_file_url_signed_hostport}, # or undef
           url => Web::URL->parse_string ($file_url));
      
      return {
        time => $now,
        form_data => {
          key => $key,
          acl => $acl,
          #success_action_redirect => $redirect_url,
          "Content-Type" => $args{mime_type},
          %$form_data,
        },
        form_url => $self->{config}->{s3_form_url},
        file => {
          key => $key,
          file_url => $file_url,
          public_file_url => $public_file_url,
          signed_url => $signed->stringify,
          mime_type => $args{mime_type},
          byte_length => 0+$args{byte_length},
        },
      };
    });
  })->then (sub {
    my $result = $_[0];
    return $tr->insert ('attachment', [{
      ($self->app_id_columns),
      ($args{target}->to_columns ('target')),
      url => Dongry::Type->serialize ('text', $result->{file}->{file_url}),
      data => Dongry::Type->serialize ('json', $result->{file}),
      open => 0,
      deleted => 0,
      created => $result->{time},
      modified => $result->{time},
    }], source_name => 'master')->then (sub {
      return $result;
    });
  });
} # prepare_upload

sub signed_storage_url ($$$) {
  my ($self, $url, $max_age) = @_;
  
  my $prefix = $self->{config}->{s3_file_url_prefix};
  return undef unless defined $url and $url =~ m{\A\Q$prefix\E};

  $url = Web::URL->parse_string ($url);
  return undef unless defined $url and $url->is_http_s;
  
  my $signed = Web::Transport::AWS->aws4_signed_url
      (clock => Web::DateTime::Clock->realtime_clock,
       max_age => $max_age,
       access_key_id => $self->{config}->{s3_aws4}->[0],
       secret_access_key => $self->{config}->{s3_aws4}->[1],
       #security_token => 
       region => $self->{config}->{s3_aws4}->[2],
       service => 's3',
       method => 'GET',
       signed_hostport => $self->{config}->{s3_file_url_signed_hostport}, # or undef
       url => $url);
  return $signed->stringify;
} # signed_storage_url

sub edit_comment ($$$%) {
  my ($self, $tr, $comment_id, %args) = @_;
  return Promise->resolve->then (sub {
    return $tr->select ('comment', {
      ($self->app_id_columns),
      comment_id => Dongry::Type->serialize ('text', $comment_id),
    }, fields => [
      'comment_id',
      ((defined $args{data_delta} or defined $args{files_delta}) ? ('data') : ()),
      (defined $args{internal_data_delta} ? ('internal_data') : ()),
      'author_nobj_id',
      'author_status', 'owner_status', 'admin_status',
    ], lock => 'update') if $args{comment};
    return $tr->select ('blog_entry', {
      ($self->app_id_columns),
      blog_entry_id => Dongry::Type->serialize ('text', $comment_id),
    }, fields => [
      'blog_entry_id',
      (defined $args{data_delta} ? ('data') : ()),
      (defined $args{summary_data_delta} ? ('summary_data') : ()),
      (defined $args{internal_data_delta} ? ('internal_data') : ()),
      'author_status', 'owner_status', 'admin_status',
    ], lock => 'update') if $args{blog};
  })->then (sub {
    my $current = $_[0]->first;
    return $self->throw ({reason => 'Object not found'})
        unless defined $current;

    if ($args{validate_operator_is_author}) { # $args{comment} only
      if (not $current->{author_nobj_id} eq $args{operator_nobj}->nobj_id) {
        return $self->throw ({reason => 'Bad operator'});
      }
    }
    
    my $updates = {}; # |summary_data| is $args{blog} only
    for my $name (qw(data summary_data internal_data)) {
      my $delta = $args{$name.'_delta'};
      $updates->{$name} = Dongry::Type->parse ('json', $current->{$name})
          if defined $current->{$name};
      if ($name eq 'data' and @{$args{files_delta} or []}) { # $args{comment}
        $delta->{files} = $updates->{$name}->{files} || [];
        $delta->{files} = [] unless ref $delta->{files} eq 'ARRAY';
        push @{$delta->{files}}, @{$args{files_delta}};
      }
      next unless defined $delta;
      next unless keys %$delta;
      my $changed = 0;
      for (keys %$delta) {
        if (defined $delta->{$_}) {
          if (not defined $updates->{$name}->{$_} or
              $updates->{$name}->{$_} ne $delta->{$_}) {
            $updates->{$name}->{$_} = $delta->{$_};
            $changed = 1;
            if ($name eq 'data') {
              if ($_ eq 'timestamp') {
                $updates->{timestamp} = 0+$updates->{$name}->{$_};
              } elsif ($_ eq 'modified') {
                $updates->{modified} = 0+$updates->{$name}->{$_};
              } elsif ($_ eq 'title') {
                $updates->{title} = ''.Dongry::Type->serialize ('text', $updates->{$name}->{$_});
              }
            }
          }
        } else {
          if (defined $updates->{$name}->{$_}) {
            delete $updates->{$name}->{$_};
            $changed = 1;
            if ($name eq 'data') {
              if ($_ eq 'timestamp') {
                $updates->{timestamp} = 0;
              } elsif ($_ eq 'modified') {
                $updates->{modified} = 0;
              } elsif ($_ eq 'title') {
                $updates->{title} = ''.Dongry::Type->serialize ('text', $updates->{$name}->{$_});
              }
            }
          }
        }
      }
      $updates->{$name}->{modified} = $updates->{modified} = time
          if $changed and $name eq 'data';
      delete $updates->{$name} unless $changed;
    } # $name
    delete $updates->{modified} unless $args{blog};
    for (qw(author_status owner_status admin_status)) {
      my $v = $args{$_};
      next unless defined $v;
      return $self->throw ({reason => "Bad |$_|"})
          unless $v =~ /\A[1-9][0-9]*\z/ and 1 < $v and $v < 255;
      $updates->{$_} = 0+$v if $current->{$_} != $v;
    } # status

    for (qw(data summary_data internal_data)) { # |summary_data| - $args{blog}
      $updates->{$_} = Dongry::Type->serialize ('json', $updates->{$_})
          if defined $updates->{$_};
    }
    
    my $d1 = $args{status_info_author_data};
    my $d2 = $args{status_info_owner_data};
    my $d3 = $args{status_info_admin_data};
    return Promise->resolve->then (sub {
      return unless $updates->{author_status} or
          $updates->{owner_status} or
          $updates->{admin_status} or
          defined $d1 or defined $d2 or defined $d3;
      my $data = {
        old => {
          author_status => $current->{author_status},
          owner_status => $current->{owner_status},
          admin_status => $current->{admin_status},
        },
        new => {
          author_status => $updates->{author_status} // $current->{author_status},
          owner_status => $updates->{owner_status} // $current->{owner_status},
          admin_status => $updates->{admin_status} // $current->{admin_status},
        },
      };
      return $self->set_status_info
          ($tr,
           ($args{operator_nobj} // die "No |operator|"),
           ($args{comment_nobj} // die "No |comment_nobj|"),
           ($args{set_status_nobj} // die "No |set_status_nobj|"),
           $data, $d1, $d2, $d3);
    })->then (sub {
      return unless keys %$updates;
      return $tr->update ('comment', $updates, where => {
        ($self->app_id_columns),
        comment_id => $current->{comment_id},
      }) if $args{comment};
      return $tr->update ('blog_entry', $updates, where => {
        ($self->app_id_columns),
        blog_entry_id => $current->{blog_entry_id},
      }) if $args{blog};
    });
  })->then (sub {
    my $dd = $args{data_delta};
    if ($args{blog} and
        defined $args{tag_context_nobj} and
        not $args{tag_context_nobj}->is_error and
        defined $dd and
        defined $dd->{tags} and ref $dd->{tags} eq 'ARRAY') {
      # no return
      $self->publish_tags
          ($self->db, $args{tag_context_nobj}, $args{comment_nobj}, $dd->{tags}, undef, time);
      ## This is executed after $tr is completed.
      undef;
    }
    
    # XXX revision if $args{blog}
  });
} # edit_comment

sub run_comment ($) {
  my $self = $_[0];

  ## Comments.  A thread can have zero or more comments.  A comment
  ## has ID : ID, thread : NObj, author : NObj, data : JSON object,
  ## internal data : JSON object, statuses : Statuses.  A comment's
  ## NObj key is |apploach-comment-| followed by the comment's ID.

  if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'list.json') {
    ## /{app_id}/comment/list.json - Get comments.
    ##
    ## Parameters.
    ##
    ##   NObj (|thread|) : The comment's thread.
    ##
    ##   |comment_id| : ID : The comment's ID.  If the thread is
    ##   specified, returned comments are limited to those for the
    ##   thread.  If |comment_id| is specified, it is further limited
    ##   to one with that |comment_id|.  Zero or more parameters can
    ##   be specified, but either the thread or the ID, or both, is
    ##   required.
    ##
    ##   |with_internal_data| : Boolean : Whether |internal_data|
    ##   should be returned or not.
    ##
    ##   Status filters.
    ##
    ##   Pages.
    ##
    ##   |signed_url_max_age| : Integer : The lifetime of the
    ##   |signed_url| in the |files| of the comment's data, if any.
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
    my $page = Pager::this_page ($self, limit => 10, max_limit => 10000);
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
      
      my $comment_ids = $self->{app}->bare_param_list ('comment_id')->to_a;
      if (@$comment_ids) {
        $_ = unpack 'Q', pack 'Q', $_ for @$comment_ids;
        $where->{comment_id} = {-in => $comment_ids};
        $page->{only_item} = 1;
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
      my $signed_max_age = $self->{app}->bare_param ('signed_url_max_age') // 60*10;
      for my $item (@$items) {
        $item->{comment_id} .= '';
        $item->{data} = Dongry::Type->parse ('json', $item->{data});
        $item->{internal_data} = Dongry::Type->parse ('json', $item->{internal_data})
            if defined $item->{internal_data};
        if (ref $item->{data}->{files} eq 'ARRAY') {
          for (@{$item->{data}->{files}}) {
            $_->{signed_url} = $self->signed_storage_url
                ($_->{file_url}, $signed_max_age); # not undef in theory
          }
        }
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
    ##   and |modified| are replaced by the time Apploach accepts the
    ##   comment.
    ##
    ##   |internal_data| : JSON object : The comment's internal
    ##   data, intended for storing private data such as author's IP
    ##   address.
    ##
    ##   Notifications (|notification_|).
    ##
    ## Created object response.
    ##
    ##   |comment_id| : ID : The comment's ID.
    ##
    ##   |timestamp| : Timestamp : The comment's data's timestamp.
    ##
    return Promise->all ([
      $self->new_nobj_list (['thread', 'author']),
      $self->ids (1),
    ])->then (sub {
      my (undef, $ids) = @{$_[0]};
      my ($thread, $author) = @{$_[0]->[0]};
      my $data = $self->json_object_param ('data');
      my $time = time;
      $data->{timestamp} = $data->{modified} = $time;
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
        return $self->fire_nevent (
          'notification_',
          {
            author_nobj_key => $author->nobj_key,
            thread_nobj_key => $thread->nobj_key,
            comment_id => ''.$ids->[0],
            timestamp => $time,
          },
          timestamp => $time,
        );
      })->then (sub {
        return $self->json ({
          comment_id => ''.$ids->[0],
          timestamp => $time,
        });
      });
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
    ##   change.  If the comment's data is found to be altered, its
    ##   |modified| is updated to the time Apploach accepts the
    ##   modification.
    ##
    ##   |internal_data_delta| : JSON object : The comment's new
    ##   internal data.  Unchanged name/value pairs can be omitted.
    ##   Removed names should be set to |null| values.  Optional if
    ##   nothing to change.
    ##
    ##   Statuses : The comment's statuses.  Optional if nothing to
    ##   change.  When statuses are changed, the comment NObj's
    ##   status info is updated (and a log is added).
    ##
    ##   |status_info_author_data| : JSON Object : The comment
    ##   NObj's status info's author data.  Optional if no change.
    ##
    ##   |status_info_owner_data| : JSON Object : The comment NObj's
    ##   status info's owner data.  Optional if no change.
    ##
    ##   |status_info_admin_data| : JSON Object : The comment
    ##   NObj's status info's admin data.  Optional if no change.
    ##
    ##   NObj (|operator|) : The operator of this editing.
    ##   Required.
    ##
    ##   |validate_operator_is_author| : Boolean : Whether the
    ##   operator has to be the comment's author or not.
    ##
    ## Response.  No additional data.
    my $operator;
    my $cnobj;
    my $ssnobj;
    my $comment_id = $self->id_param ('comment');
    return Promise->all ([
      $self->new_nobj_list (['operator',
                             \('apploach-comment-' . $comment_id),
                             \'apploach-set-status']),
    ])->then (sub {
      ($operator, $cnobj, $ssnobj) = @{$_[0]->[0]};
      return $self->db->transaction;
    })->then (sub {
      my $tr = $_[0];
      return $self->edit_comment ($tr, $comment_id,
        comment => 1,
        data_delta => $self->optional_json_object_param ('data_delta'),
        internal_data_delta => $self->optional_json_object_param ('internal_data_delta'),
        validate_operator_is_author => $self->{app}->bare_param ('validate_operator_is_author'),
        operator_nobj => $operator,
        comment_nobj => $cnobj,
        set_status_nobj => $ssnobj,
        author_status => $self->{app}->bare_param ('author_status'),
        owner_status => $self->{app}->bare_param ('owner_status'),
        admin_status => $self->{app}->bare_param ('admin_status'),
        status_info_author_data => $self->optional_json_object_param ('status_info_author_data'),
        status_info_owner_data => $self->optional_json_object_param ('status_info_owner_data'),
        status_info_admin_data => $self->optional_json_object_param ('status_info_admin_data'),
      )->then (sub {
        return $tr->commit->then (sub { undef $tr });
      })->finally (sub {
        return $tr->rollback if defined $tr;
      }); # transaction
    })->then (sub {
      return $self->json ({});
    });
  } elsif (@{$self->{path}} == 1 and $self->{path}->[0] eq 'attachform.json') {
    ## /{app_id}/comment/attachform.json - Create a form to attach a
    ## file to the comment.
    ##
    ## Parameters.
    ##
    ##   |comment_id| : ID : The comment's ID.
    ##
    ##   NObj (|operator|) : The operator of this editing.
    ##   Required.
    ##
    ##   |validate_operator_is_author| : Boolean : Whether the
    ##   operator has to be the comment's author or not.
    ##
    ##   |path_prefix| : String : The path of the attachment's URL,
    ##   within the directory specified by the configuration, without
    ##   random string part assigned by the Apploach server.  It must
    ##   be a string matching to |(/[A-Za-z0-9]+)+|.  Default is
    ##   |/apploach/comment|.
    ##
    ##   File upload parameters: |mime_type| and |byte_length|.
    ##
    ## Response.
    ##
    ##   File upload information.
    ##
    ## This end point creates a file upload form and associate it
    ## with the comment.  The comment's data's |files| is set to an
    ## array which contains the |file| value of the created file
    ## upload information.
    ##
    ## This is similar to |/nobj/attachform.json| but integrated with
    ## comments.
    my $operator;
    my $cnobj;
    my $comment_id = $self->id_param ('comment');

    my $path = $self->{app}->bare_param ('path_prefix') // '/apploach/comment';
    return $self->throw ({reason => 'Bad |path_prefix|'})
        unless $path =~ m{\A(?:/[0-9A-Za-z]+)+\z} and
        512 > length $path;
    $path =~ s{^/}{};
    
    return Promise->all ([
      $self->new_nobj_list (['operator',
                             \('apploach-comment-' . $comment_id)]),
    ])->then (sub {
      ($operator, $cnobj) = @{$_[0]->[0]};
      return $self->db->transaction;
    })->then (sub {
      my $tr = $_[0];
      return $self->prepare_upload ($tr,
        target => $cnobj,
        mime_type => $self->{app}->bare_param ('mime_type'),
        byte_length => $self->{app}->bare_param ('byte_length'),
        prefix => $path . '/' . $comment_id,
      )->then (sub {
        my $result = $_[0];
        return $self->edit_comment ($tr, $comment_id,
          comment => 1,
          files_delta => [$result->{file}],
          validate_operator_is_author => $self->{app}->bare_param ('validate_operator_is_author'),
          operator_nobj => $operator,
          comment_nobj => $cnobj,
        )->then (sub {
          return $tr->commit->then (sub { undef $tr });
        })->then (sub {
          return $self->json ($result);
        });
      })->finally (sub {
        return $tr->rollback if defined $tr;
      }); # transaction
    });
  }

  return $self->{app}->throw_error (404);
} # run_comment

sub run_blog ($) {
  my $self = $_[0];

  ## Blogs.  A blog can have zero or more blog entries.  A blog entry
  ## has ID : ID, blog : NObj, data : JSON object, summary data : JSON
  ## object, internal data : JSON object, statuses : Statuses.  A blog
  ## entry's NObj key is |apploach-bentry-| followed by the blog
  ## entry's ID.

  if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'list.json') {
    ## /{app_id}/blog/list.json - Get blog entries.
    ##
    ## Parameters.
    ##
    ##   NObj (|blog|) : The blog entry's blog.
    ##
    ##   |blog_entry_id| : ID : The blog entry's ID.  Zero or more
    ##   parameters can be specified.  Either the blog or the ID, or
    ##   both, is required.  If the blog is specified, returned blog
    ##   entries are limited to those in the blog.  If |blog_entry_id|
    ##   is specified, it is further limited to one with that
    ##   |blog_entry_id|.
    ##
    ##   |timestamp_lt|, |timestamp_le|, |timestamp_gt|,
    ##   |timestamp_ge| : Timestamp : Limit the range of the blog
    ##   entry's timestamp, using operator |<|, |<=|, |>=|, or |>|,
    ##   respectively.  If omitted, no range limitations.
    ##
    ##   |with_title| : Boolean : Whether |data|'s |title| and
    ##   |timestamp| should be returned or not.  This is implied as
    ##   true if |with_data| is true.
    ##
    ##   |with_data| : Boolean : Whether |data| should be returned or
    ##   not.
    ##
    ##   |with_summary_data| : Boolean : Whether |summary_data| should
    ##   be returned or not.
    ##
    ##   |with_internal_data| : Boolean : Whether |internal_data|
    ##   should be returned or not.
    ##
    ##   |with_neighbors| : Boolean : Whether |prev_item| and
    ##   |next_item| should be returned or not.  Only applicable when
    ##   exactly one |blog_entry_id| is specified.
    ##
    ##   Status filters.
    ##
    ##   Pages.
    ##
    ## List response of blog entries.
    ##
    ##   NObj (|blog|) : The blog entry's blog.
    ##
    ##   |blog_entry_id| : ID : The blog entry's ID.
    ##
    ##   |data| : JSON object : The blog entry's data.  Only when
    ##   |with_data| or |with_title| is true.
    ##
    ##   |summary_data| : JSON object: The blog entry's summary data.
    ##   Only when |with_summary_data| is true.
    ##
    ##   |internal_data| : JSON object: The blog entry's internal
    ##   data.  Only when |with_internal_data| is true.
    ##
    ##   Statuses.
    ##
    ##   Statuses with |with_neighbors_| prefixes.  If specified,
    ##   preferably used in place of unprefixed statuses for
    ##   generating |prev_item| and |next_item| objects.
    ##
    ## In addition to list response name/value pairs:
    ##
    ##   |prev_item| : JSON object? : The blog entry's previous blog
    ##   entry sorted by their |timestamp| values, if any, within the
    ##   same blog entry's blog.  Only when |with_neighbors| is
    ##   specified.
    ##
    ##   |next_item| : JSON object? : The blog entry's next blog entry
    ##   sorted by their |timestamp| values, if any, within the same
    ##   blog entry's blog.  Only when |with_neighbors| is specified.
    ##
    ## The values of the |prev_item| and |next_item| name/value pairs,
    ## if non-null, are JSON objects with following name/value pairs:
    ##
    ##   |blog_entry_id| : ID : The blog entry's ID.
    ##
    ##   |data| : JSON object with following name/value pair:
    ##
    ##     |title| : String? : The blog entry's data's |title|.
    ##                           Only when |with_title| is specified.
    my $result = {};
    my $page = Pager::this_page ($self, limit => 10, max_limit => 10000);
    return Promise->all ([
      $self->nobj ('blog'),
    ])->then (sub {
      my $thread = $_[0]->[0];
      return $result->{items} = [] if $thread->not_found;

      my $where_base = {
        ($self->app_id_columns),
        ($thread->missing ? () : ($thread->to_columns ('blog'))),
        ($self->status_filter_columns),
      };
      my $where = {%$where_base};
      $where->{timestamp} = $page->{value} if defined $page->{value};
      for (
        ['timestamp_le', '<='],
        ['timestamp_lt', '<'],
        ['timestamp_ge', '>='],
        ['timestamp_gt', '>'],
      ) {
        my $value = $self->{app}->bare_param ($_->[0]);
        if (defined $value) {
          if (defined $where->{timestamp}->{$_->[1]}) {
            if ($_->[1] eq '<=' or $_->[1] eq '<') {
              $where->{timestamp}->{$_->[1]} = $value
                  if $where->{timestamp}->{$_->[1]} > $value;
            } else {
              $where->{timestamp}->{$_->[1]} = $value
                  if $where->{timestamp}->{$_->[1]} < $value;
            }
          } else {
            $where->{timestamp}->{$_->[1]} = $value;
          }
        }
      }

      my $id_list = $self->{app}->bare_param_list ('blog_entry_id')->to_a;
      if (@$id_list) {
        $_ = unpack 'Q', pack 'Q', $_ for @$id_list;
        $where->{blog_entry_id} = {-in => $id_list};
        $page->{only_item} = 1;
      } else {
        return $self->throw
            ({reason => 'Either blog or |blog_entry_id| is required'})
            if $thread->missing;
      }

      my $wd = $self->{app}->bare_param ('with_data');
      return $self->db->select ('blog_entry', $where, fields => [
        'blog_entry_id',
        'blog_nobj_id',
        (($self->{app}->bare_param ('with_title') and not $wd) ? ('title') : ()),
        ($wd ? ('data') : ()),
        ($self->{app}->bare_param ('with_summary_data') ? ('summary_data') : ()),
        ($self->{app}->bare_param ('with_internal_data') ? ('internal_data') : ()),
        'author_status', 'owner_status', 'admin_status',
        'timestamp',
      ], source_name => 'master',
        offset => $page->{offset}, limit => $page->{limit},
        order => ['timestamp', $page->{order_direction}, 'blog_entry_id', $page->{order_direction}],
      )->then (sub {
        my $items = $result->{items} = $_[0]->all->to_a;
        for my $item (@$items) {
          $item->{blog_entry_id} .= '';
          if (defined $item->{data}) {
            $item->{data} = Dongry::Type->parse ('json', $item->{data});
          } elsif (defined $item->{title}) {
            $item->{data} = {
              title => Dongry::Type->parse ('text', delete $item->{title}),
              timestamp => $item->{timestamp},
            };
          }
          $item->{summary_data} = Dongry::Type->parse ('json', $item->{summary_data})
              if defined $item->{summary_data};
          $item->{internal_data} = Dongry::Type->parse ('json', $item->{internal_data})
              if defined $item->{internal_data};
        }
        if (@$items == 1 and $self->{app}->bare_param ('with_neighbors') and
            $page->{only_item}) {
          my $prev;
          my $next;
          $where_base->{blog_nobj_id} = $items->[0]->{blog_nobj_id};
          # $self->status_filter_columns with "with_neighbors_" prefix.
          for (qw(author_status owner_status admin_status)) {
            my $v = $self->{app}->bare_param_list ('with_neighbors_'.$_);
            next unless @$v;
            $where_base->{$_} = {-in => $v};
          }
          return Promise->all ([
            $self->db->select ('blog_entry', {
              %$where_base,
              timestamp => {'<', $items->[0]->{timestamp}},
            }, fields => [
              'blog_entry_id',
              ($self->{app}->bare_param ('with_title') ? ('title') : ()),
            ], source_name => 'master', order => ['timestamp', 'desc'], limit => 1)->then (sub { return $_[0]->first }),
            $self->db->select ('blog_entry', {
              %$where_base,
              timestamp => {'>', $items->[0]->{timestamp}},
            }, fields => [
              'blog_entry_id',
              ($self->{app}->bare_param ('with_title') ? ('title') : ()),
            ], source_name => 'master', order => ['timestamp', 'asc'], limit => 1)->then (sub { return $_[0]->first }),
            $self->db->select ('blog_entry', {
              %$where_base,
              timestamp => $items->[0]->{timestamp},
            }, fields => [
              'blog_entry_id',
            ], source_name => 'master', order => ['timestamp', 'asc', 'blog_entry_id', 'asc'], limit => 1000)->then (sub { return [map { $_->{blog_entry_id} } @{$_[0]->all}] }),
          ])->then (sub {
            $prev = $_[0]->[0]; # or undef
            $next = $_[0]->[1]; # or undef
            my @eid = @{$_[0]->[2]};
            if (@eid > 1) {
              my $prev_eid;
              my $next_eid;
              my $found;
              for (@eid) {
                if ($_ == $items->[0]->{blog_entry_id}) {
                  $found = 1;
                } elsif ($found) {
                  $next_eid = $_;
                  last;
                } else {
                  $prev_eid = $_;
                }
              }
              my $eids = [];
              push @$eids, $prev_eid if defined $prev_eid;
              push @$eids, $next_eid if defined $next_eid;
              return unless @$eids;
              return $self->db->select ('blog_entry', {
                %$where_base,
                blog_entry_id => {-in => $eids},
              }, fields => [
                'blog_entry_id',
                ($self->{app}->bare_param ('with_title') ? ('title') : ()),
              ], source_name => 'master')->then (sub {
                for (@{$_[0]->all}) {
                  if ($_->{blog_entry_id} == $prev_eid) {
                    $prev = $_;
                  } elsif ($_->{blog_entry_id} == $next_eid) {
                    $next = $_;
                  }
                }
              });
            }
          })->then (sub {
            if (defined $prev) {
              $result->{prev_item}->{blog_entry_id} = ''.$prev->{blog_entry_id};
              $result->{prev_item}->{data}->{title} = Dongry::Type->parse ('text', $prev->{title})
                  if defined $prev->{title};
            }
            if (defined $next) {
              $result->{next_item}->{blog_entry_id} = ''.$next->{blog_entry_id};
              $result->{next_item}->{data}->{title} = Dongry::Type->parse ('text', $next->{title})
                  if defined $next->{title};
            }
          });
        }
      });
    })->then (sub {
      return $self->replace_nobj_ids ($result->{items}, ['blog']);
    })->then (sub {
      my $next_page = Pager::next_page $page, $result->{items}, 'timestamp';
      delete $_->{timestamp} for @{$result->{items}};
      return $self->json ({%$result, %$next_page});
    });
  } elsif (@{$self->{path}} == 1 and $self->{path}->[0] eq 'createentry.json') {
    ## /{app_id}/blog/createentry.json - Add a new blog entry.
    ##
    ## Parameters.
    ##
    ##   NObj (|blog|) : The blog entry's blog.
    ##
    ##   Statuses : The blog entry's statuses.
    ##
    ## Created object response.
    ##
    ##   |blog_entry_id| : ID : The blog entry's ID.
    ##
    ##   |timestamp| : Timestamp : The blog entry's data's timestamp.
    return Promise->all ([
      $self->new_nobj_list (['blog']),
      $self->ids (1),
    ])->then (sub {
      my (undef, $ids) = @{$_[0]};
      my ($thread) = @{$_[0]->[0]};
      my $time = time;
      my $data = {timestamp => $time, modified => $time, title => ''};
      return $self->db->insert ('blog_entry', [{
        ($self->app_id_columns),
        ($thread->to_columns ('blog')),
        blog_entry_id => $ids->[0],
        data => Dongry::Type->serialize ('json', $data),
        summary_data => Dongry::Type->serialize ('json', {}),
        internal_data => Dongry::Type->serialize ('json', {}),
        ($self->status_columns),
        title => $data->{title},
        timestamp => $data->{timestamp},
        modified => $data->{timestamp},
      }])->then (sub {
        return $self->json ({
          blog_entry_id => ''.$ids->[0],
          timestamp => $time,
        });
      });
    });
  } elsif (@{$self->{path}} == 1 and $self->{path}->[0] eq 'edit.json') {
    ## /{app_id}/blog/edit.json - Edit a blog entry.
    ##
    ## Parameters.
    ##
    ##   |blog_entry_id| : ID : The blog entry's ID.
    ##
    ##   |data_delta| : JSON object : The blog entry's new data.
    ##   Unchanged name/value pairs can be omitted.  Removed names
    ##   should be set to |null| values.  Optional if nothing to
    ##   change.  If the blog entry's data is found to be altered, its
    ##   |modified| is updated to the time Apploach accepts the
    ##   modification.
    ##
    ##   |summary_data_delta| : JSON object : The blog entry's new
    ##   summary data.  Unchanged name/value pairs can be omitted.
    ##   Removed names should be set to |null| values.  Optional if
    ##   nothing to change.
    ##
    ##   |internal_data_delta| : JSON object : The blog entry's new
    ##   internal data.  Unchanged name/value pairs can be omitted.
    ##   Removed names should be set to |null| values.  Optional if
    ##   nothing to change.
    ##
    ##   Statuses : The blog entry's statuses.  Optional if nothing to
    ##   change.  When statuses are changed, the blog entry NObj's
    ##   status info is updated (and a log is added).
    ##
    ##   |status_info_author_data| : JSON Object : The blog entry
    ##   NObj's status info's author data.  Optional if no change.
    ##
    ##   |status_info_owner_data| : JSON Object : The blog entry
    ##   NObj's status info's owner data.  Optional if no change.
    ##
    ##   |status_info_admin_data| : JSON Object : The blog entry
    ##   NObj's status info's admin data.  Optional if no change.
    ##
    ##   NObj (|tag_context|) : If this parameter is specified and
    ##   |data_delta|'s |data| member is an array, |data| members are
    ##   considered as tag names in the context of NObj
    ##   (|tag_context|).
    ##
    ##   NObj (|operator|) : The operator of this editing.
    ##   Required.
    ##
    ## Response.  No additional data.
    my $operator;
    my $cnobj;
    my $ssnobj;
    my $tag_context;
    my $comment_id = $self->id_param ('blog_entry');
    return Promise->all ([
      $self->new_nobj_list (['operator',
                             \('apploach-bentry-' . $comment_id),
                             \'apploach-set-status',
                             (defined $self->{app}->bare_param ('tag_context_nobj_key') ? 'tag_context' : ())]),
    ])->then (sub {
      ($operator, $cnobj, $ssnobj, $tag_context) = @{$_[0]->[0]};
      return $self->db->transaction;
    })->then (sub {
      my $tr = $_[0];
      return $self->edit_comment ($tr, $comment_id,
        blog => 1,
        data_delta => $self->optional_json_object_param ('data_delta'),
        summary_data_delta => $self->optional_json_object_param ('summary_data_delta'),
        internal_data_delta => $self->optional_json_object_param ('internal_data_delta'),
        operator_nobj => $operator,
        tag_context_nobj => $tag_context,
        comment_nobj => $cnobj,
        set_status_nobj => $ssnobj,
        author_status => $self->{app}->bare_param ('author_status'),
        owner_status => $self->{app}->bare_param ('owner_status'),
        admin_status => $self->{app}->bare_param ('admin_status'),
        status_info_author_data => $self->optional_json_object_param ('status_info_author_data'),
        status_info_owner_data => $self->optional_json_object_param ('status_info_owner_data'),
        status_info_admin_data => $self->optional_json_object_param ('status_info_admin_data'),
      )->then (sub {
        return $tr->commit->then (sub { undef $tr });
      })->finally (sub {
        return $tr->rollback if defined $tr;
      }); # transaction
    })->then (sub {
      return $self->json ({});
    });
  }

  return $self->{app}->throw_error (404);
} # run_blog

sub run_star ($) {
  my $self = $_[0];

  ## Stars.  A starred NObj can have zero or more stars.  A star has
  ## starred NObj : NObj, author : NObj, item : NObj, count : Integer.

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
    ##   |delta| : Integer : The difference of the new and the current
    ##   numbers of the star's count.
    ##
    ##   Notifications (|notification_|).
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
      }, source_name => 'master')->then (sub {
        return unless $delta > 0;
        return $self->fire_nevent (
          'notification_',
          {
            author_nobj_key => $author->nobj_key,
            starred_nobj_key => $starred->nobj_key,
            starred_author_nobj_key => $starred_author->nobj_key,
            timestamp => $time,
          },
          timestamp => $time,
        );
      });
    })->then (sub {
      return $self->json ({});
    });
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
    ##     {NObj (|starred|) : The star's starred NObj} : Array of stars.
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
      my $page = Pager::this_page ($self, limit => 10, max_limit => 10000);
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

  return $self->{app}->throw_error (404);
} # run_star

sub run_follow ($) {
  my $self = $_[0];

  ## A follow is a relation from subject NObj to object NObj of verb
  ## (type) NObj.  It can have value which is an 8-bit unsigned
  ## integer, where value |0| is equivalent to not having any
  ## relation.  It has created and timestamp which are Timestamps.

  if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'set.json') {
    ## /{app_id}/follow/set.json - Set a follow.
    ##
    ## Parameters.
    ##
    ##   NObj (|subject|) : The follow's subject NObj.
    ##
    ##   NObj (|object|) : The follow's object NObj.
    ##
    ##   NObj (|verb|) : The follow's object NObj.
    ##
    ##   |value| : Integer : The follow's value.
    ##
    ##   Notifications (|notification_|).
    ##
    ## Response.  No additional data.
    ##
    ## The follow's created and timestamp are set to the current
    ## timestamp.
    return Promise->all ([
      $self->new_nobj_list (['subject', 'object', 'verb']),
    ])->then (sub {
      my ($subj, $obj, $verb) = @{$_[0]->[0]};
      my $time = time;
      my $value = 0+($self->{app}->bare_param ('value') || 0);
      return $self->db->insert ('follow', [{
        ($self->app_id_columns),
        ($subj->to_columns ('subject')),
        ($obj->to_columns ('object')),
        ($verb->to_columns ('verb')),
        value => $value,
        created => $time,
        timestamp => $time,
      }], duplicate => {
        value => $self->db->bare_sql_fragment ('VALUES(`value`)'),
        timestamp => $self->db->bare_sql_fragment ('if(`value`=VALUES(`value`), `timestamp`, VALUES(`timestamp`))'),
      }, source_name => 'master')->then (sub {
        my $v = $_[0];
        return unless $value > 0;
        return $self->db->select ('follow', {
          ($self->app_id_columns),
          ($subj->to_columns ('subject')),
          ($obj->to_columns ('object')),
          ($verb->to_columns ('verb')),
          timestamp => $time,
        }, fields => ['timestamp'], source_name => 'master')->then (sub {
          my $v = $_[0]->first;
          return unless defined $v;
          return $self->fire_nevent (
            'notification_',
            {
              subject_nobj_key => $subj->nobj_key,
              object_nobj_key => $obj->nobj_key,
              verb_nobj_key => $verb->nobj_key,
              value => $value,
              timestamp => $time,
            },
            timestamp => $time,
          );
        });
      });
    })->then (sub {
      return $self->json ({});
    });
  } elsif (@{$self->{path}} == 1 and $self->{path}->[0] eq 'list.json') {
    ## /{app_id}/follow/list.json - Get follows.
    ##
    ## Parameters.
    ##
    ##   NObj (|subject|) : The follow's subject NObj.
    ##
    ##   NObj (|object|) : The follow's object NObj.  Either NObj
    ##   (|subject|) or NObj (|object|) or both is required.
    ##
    ##   NObj (|verb|) : The follow's object NObj.  Optional.
    ##
    ##   |antenna| : Boolean : If true, sorted by the follow's
    ##   |timestamp|.  Otherwise, sorted by the follow's |created|.
    ##
    ##   Pages.
    ##
    ## List response of follows.
    ##
    ##   NObj (|subject|) : The follow's subject NObj.
    ##
    ##   NObj (|object|) : The follow's object NObj.
    ##
    ##   NObj (|verb|) : The follow's verb NObj.
    ##
    ##   |value| : Integer : The follow's value.
    ##
    ##   |created| : Timestamp : The follow's created.
    ##
    ##   |timestamp| : Timestamp : The follow's timestamp.
      my $s = $self->{app}->bare_param ('subject_nobj_key');
      my $o = $self->{app}->bare_param ('object_nobj_key');
      my $v = $self->{app}->bare_param ('verb_nobj_key');
      my $page = Pager::this_page ($self, limit => 100, max_limit => 10000);
      my $sort_key = $self->{app}->bare_param ('antenna') ? 'timestamp' : 'created';
      return Promise->all ([
        $self->_no ([$s, $o, $v]),
      ])->then (sub {
        my ($subj, $obj, $verb) = @{$_[0]->[0]};
        return [] if defined $v and $verb->is_error;
        return [] if defined $s and $subj->is_error;
        return [] if defined $o and $obj->is_error;

        my $where = {
          ($self->app_id_columns),
          value => {'>', 0},
        };
        if (not $subj->is_error) {
          if (not $obj->is_error) {
            $where = {
              %$where,
              ($subj->to_columns ('subject')),
              ($obj->to_columns ('object')),
            };
          } else {
            $where = {
              %$where,
              ($subj->to_columns ('subject')),
            };
          }
        } else {
          if (not $obj->is_error) {
            $where = {
              %$where,
              ($obj->to_columns ('object')),
            };
          } else {
            return $self->throw ({reason => 'No |subject| or |object|'});
          }
        }
        if (not $verb->is_error) {
          $where = {%$where, ($verb->to_columns ('verb'))};
        }
        $where->{$sort_key} = $page->{value} if defined $page->{value};

        return $self->db->select ('follow', $where, fields => [
          'subject_nobj_id', 'object_nobj_id', 'verb_nobj_id',
          'value', 'timestamp', 'created',
        ], source_name => 'master',
          offset => $page->{offset}, limit => $page->{limit},
          order => [$sort_key, $page->{order_direction}],
        )->then (sub {
          return $self->replace_nobj_ids ($_[0]->all->to_a, ['subject', 'object', 'verb']);
        });
      })->then (sub {
        my $items = $_[0];
        my $next_page = Pager::next_page $page, $items, $sort_key;
        return $self->json ({items => $items, %$next_page});
      });
    }

  return $self->{app}->throw_error (404);
} # run_follow

sub normalize_tag_name ($) {
  my $n = to_nfkc $_[0];
  $n =~ s/\s+/ /g;
  $n =~ s/\A //;
  $n =~ s/ \z//;
  return $n;
} # normalize_tag_name

sub publish_tags ($$$$$$$) {
  my ($self, $tr, $context, $item, $tags, $score, $time) = @_;
  return Promise->resolve->then (sub {
    return $tr->insert ('tag_item', [map { {
      ($self->app_id_columns),
      ($context->to_columns ('context')),
      ($item->to_columns ('item')),
      tag_name_sha => (sha $_),
      score => (defined $score ? 0+$score : 0),
      timestamp => $time,
    } } @$tags], source_name => 'master', duplicate => {
      (defined $score ? 
           (score => $self->db->bare_sql_fragment ('VALUES(`score`)')) : ()),
      timestamp => $self->db->bare_sql_fragment ('VALUES(`timestamp`)'),
    }) if @$tags;
  })->then (sub {
    return $tr->delete ('tag_item', {
      ($self->app_id_columns),
      ($context->to_columns ('context')),
      ($item->to_columns ('item')),
      tag_name_sha => {-not_in => [map { sha $_ } @$tags]},
    }, source_name => 'master') if @$tags;
    return $tr->delete ('tag_item', {
      ($self->app_id_columns),
      ($context->to_columns ('context')),
      ($item->to_columns ('item')),
    }, source_name => 'master');
  })->then (sub {
    return promised_for {
      my $tag_name = shift;
      return $tr->execute (q{insert into `tag` (`app_id`, `context_nobj_id`, `tag_name_sha`, `tag_name`, `count`, `author_status`, `owner_status`, `admin_status`, `timestamp`)
        select :app_id as `app_id`, :context_nobj_id as `context_nobj_id`, :tag_name_sha as `tag_name_sha`, :tag_name as `tag_name`, count(*) as `count`, :author_status as `author_status`, :owner_status as `owner_status`, :admin_status as `admin_status`, :timestamp as `timestamp` from `tag_item` where `app_id` = :app_id and `context_nobj_id` = :context_nobj_id and `tag_name_sha` = :tag_name_sha
        on duplicate key update `count` = values(`count`), `timestamp` = values(`timestamp`)}, {
          ($self->app_id_columns),
          ($context->to_columns ('context')),
          tag_name => Dongry::Type->serialize ('text', $tag_name),
          tag_name_sha => sha $tag_name,
          author_status => 0,
          owner_status => 0,
          admin_status => 0,
          timestamp => $time,
        }, source_name => 'master');
    } $tags;
  });
} # publish_tags

sub run_tag ($) {
  my $self = $_[0];

  ## Tags.
  ##
  ## A tag has context : NObj, tag name : String, Statuses, timestamp
  ## : Timestamp.  Tag names are unique within their context.  The
  ## initial values of the statuses and timestamp fields are zero (0).
  ##
  ## A tag's NObj key is |apploach-tag-[/context/]-/tag/| where
  ## /context/ is the tag's context NObj key and /tag/ is the
  ## punycode-encoded tag's tag name.
  ##
  ## A tag has zero or more string data, which are name : String and
  ## value : String pairs where names are unique for a tag.
  ##
  ## A tag can be redirected to another tag.  A tag's canonical tag
  ## name is the tag name of the tag to which the tag is redirected,
  ## if any, or the tag's tag name.  If the tag name normalized by
  ## NFKC, replaced any |\s+| by a U+0020 character, and trimmed
  ## leading and trailing any U+0020 character is different from the
  ## original tag name, there is an implicit redirect from the
  ## original tag name to the normalized tag name.  A tag can have
  ## zero or more localized tag names, which are pairs of language :
  ## Language and value : String.  Languages are unique for a tag.
  ## Whenever a localized tag name pair is generated, a redirect from
  ## the localized tag name's value to the tag name is created.
  ## Initially there is no tag redirects or localized tag name, except
  ## for implicit redirects.
  ##
  ## A tag can be associated with zero or more tag items, which are
  ## context NObj, tag name : String, item NObj, score : Integer,
  ## timestamp : Timestamp.  Item NObjs are unique for a tag.
  ## Initially there is no tag item.  The tag's count : Integer is the
  ## number of tag items associated with the tag.
  if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'list.json') {
    ## /{app_id}/tag/list.json - Get tag data.
    ##
    ## Parameters.
    ##
    ##   NObj (|context|) : The tag's context NObj.
    ##
    ##   |tag_name| : String : The tag's tag name.  Zero or more
    ##   parameters can be specified.
    ##
    ## Response.
    ##
    ##   |tags| : JSON object.
    ##
    ##     /tag's tag name/ : JSON object.
    ##
    ##       |tag_name| : String : The tag's tag name.
    ##
    ##       |canon_tag_name| : String : The tag's canonical tag name.
    ##
    ##       |localized_tag_name| : JSON object : The tag's localized
    ##       tag names.
    ##
    ##         /localized tag name's language : Language/ : Localized
    ##         tag name's value.
    ##
    ##       |nobj_key| : String : The tag's NObj key.
    ##
    ##       Statuses : The tag's statuses (or |0| value, if not
    ##       specified).
    ##
    ##       |count| : Integer : The tag's count.
    ##
    ##       |timestamp| : Timestamp : The tag's timestamp.
    my $names = $self->{app}->text_param_list ('tag_name');
    my $name_shas = {map { $_ => sha $_ } @$names};
    my $all_name_shas = {map { $_ => 1 } values %$name_shas};
    my $context;
    my $sha_redirects = {};
    my $sha2r = {};
    my $result = {tags => {}};
    return Promise->all ([
      $self->nobj ('context'),
    ])->then (sub {
      ($context) = @{$_[0]};
      return {} if $context->is_error;
      return {} unless keys %$name_shas;

      return $self->db->select ('tag_redirect', {
        ($self->app_id_columns),
        ($context->to_columns ('context')),
        from_tag_name_sha => {-in => [values %$name_shas]},
      }, source_name => 'master', fields => ['from_tag_name_sha', 'to_tag_name_sha'])->then (sub {
        for (@{$_[0]->all}) {
          $sha_redirects->{$_->{from_tag_name_sha}} = $_->{to_tag_name_sha};
          $all_name_shas->{$_->{to_tag_name_sha}} = 1;
        }
        for my $name (@$names) {
          next if defined $sha_redirects->{$name_shas->{$name}};
          my $normalized = normalize_tag_name $name;
          next if $name eq $normalized;
          my $name_sha = sha $name;
          $sha_redirects->{$name_shas->{$name}} = $name_sha;
          $all_name_shas->{$name_sha} = 1;
        }
        return $self->db->select ('tag', {
          ($self->app_id_columns),
          ($context->to_columns ('context')),
          tag_name_sha => {-in => [keys %$all_name_shas]},
        }, source_name => 'master', fields => [
          'tag_name', 'tag_name_sha', 'count', 'timestamp',
          'author_status', 'owner_status', 'admin_status',
        ]);
      })->then (sub {
        return {map {
          $_->{tag_name} = Dongry::Type->parse ('text', $_->{tag_name});
          ($_->{tag_name} => $_);
        } @{$_[0]->all}};
      });
    })->then (sub {
      my $v = $_[0];

      for my $w (values %$v) {
        push @{$sha2r->{$w->{tag_name_sha}} ||= []}, $result->{tags}->{$w->{tag_name}} = {
          tag_name => $w->{tag_name},
          nobj_key => "apploach-tag-[@{[$context->nobj_key]}]-@{[encode_punycode $w->{tag_name}]}",
          count => $w->{count},
          timestamp => $w->{timestamp},
          author_status => $w->{author_status},
          owner_status => $w->{owner_status},
          admin_status => $w->{admin_status},
        };
        $name_shas->{$w->{tag_name}} = $w->{tag_name_sha};
      }
      for my $name (@$names) {
        push @{$sha2r->{$name_shas->{$name}} ||= []}, $result->{tags}->{$name} ||= {
          tag_name => $name,
          nobj_key => "apploach-tag-[@{[$context->nobj_key]}]-@{[encode_punycode $name]}",
          count => 0,
          timestamp => 0,
          author_status => 0,
          owner_status => 0,
          admin_status => 0,
        };
      }
      for my $name (keys %{$result->{tags}}) {
        $result->{tags}->{$name}->{canon_tag_name} = $sha2r->{
          $sha_redirects->{$name_shas->{$name}} // $name_shas->{$name}
        }->[0]->{tag_name};
        $result->{tags}->{$name}->{localized_tag_names} = {};
      }

      return if $context->is_error;
      my $string_data_names = $self->{app}->text_param_list ('sd');
      return unless keys %$all_name_shas and @$string_data_names;
      return $self->db->select ('tag_string_data', {
        ($self->app_id_columns),
        ($context->to_columns ('context')),
        tag_name_sha => {-in => [keys %$all_name_shas]},
        name => {-in => [map { Dongry::Type->serialize ('text', $_) } @$string_data_names]},
      }, source_name => 'master', fields => [
        'tag_name_sha', 'name', 'value',
      ])->then (sub {
        for my $v (@{$_[0]->all}) {
          for (@{$sha2r->{$v->{tag_name_sha}} || []}) {
            $_->{string_data}->{Dongry::Type->parse ('text', $v->{name})}
                = Dongry::Type->parse ('text', $v->{value});
          }
        }
      });
    })->then (sub {
      return if $context->is_error;
      return unless keys %$all_name_shas;
      return $self->db->select ('tag_name', {
        ($self->app_id_columns),
        ($context->to_columns ('context')),
        tag_name_sha => {-in => [keys %$all_name_shas]},
      }, source_name => 'master', fields => [
        'tag_name_sha', 'lang', 'localized_tag_name',
      ])->then (sub {
        for my $v (@{$_[0]->all}) {
          for (@{$sha2r->{$v->{tag_name_sha}} || []}) {
            $_->{localized_tag_names}->{$v->{lang}} = Dongry::Type->parse ('text', $v->{localized_tag_name});
          }
        }
      });
    })->then (sub {
      return $self->json ($result);
    });
  } # /tag/list.json

  if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'index.json') {
    ## /{app_id}/tag/index.json - Get tag list, sorted by count.
    ##
    ## Parameters.
    ##
    ##   NObj (|context|) : The tag's context NObj.
    ##
    ## List response of:
    ##
    ##   |tag_name| : String : The tag's tag name.
    ##
    ##   Statuses : The tag's statuses (or |0| value, if not
    ##   specified).
    ##
    ##   |count| : Integer : The tag's count.
    ##
    ##   |timestamp| : Timestamp : The tag's timestamp.
    return Promise->all ([
      $self->nobj ('context'),
    ])->then (sub {
      my ($context) = @{$_[0]};
      return [] if $context->is_error;
      my $limit = 0+($self->{app}->bare_param ('limit') // 100);
      return $self->throw ({reason => 'Bad |limit|'}) if $limit > 10000;
      return $self->db->select ('tag', {
        ($self->app_id_columns),
        ($context->to_columns ('context')),
      }, source_name => 'master', fields => [
        'tag_name', 'count', 'timestamp',
        'author_status', 'owner_status', 'admin_status',
      ], limit => $limit, order => [
        'count', 'desc', 'timestamp', 'desc',
      ])->then (sub {
        return [map {
          $_->{tag_name} = Dongry::Type->parse ('text', $_->{tag_name});
          $_;
        } @{$_[0]->all}];
      });
    })->then (sub {
      return $self->json ({items => $_[0]});
    });
  } # /tag/index.json
  
  if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'edit.json') {
    ## /{app_id}/tag/edit.json - Edit a tag.
    ##
    ## Parameters.
    ##
    ##   NObj (|context|) : The tag's context NObj.
    ##
    ##   NObj (|operator|) : The operator of this editing.
    ##   Required.
    ##
    ##   |tag_name| : String : The tag's tag name.  Required.
    ##
    ##   Statuses : The tag's statuses.  Optional if nothing to
    ##   change.  When statuses are changed, the tag NObj's status
    ##   info is updated (and a log is added).
    ##
    ##   |status_info_author_data| : JSON object : The tag NObj's
    ##   status info's author data.  Optional if no change.
    ##
    ##   |status_info_owner_data| : JSON object : The tag NObj's
    ##   status info's owner data.  Optional if no change.
    ##
    ##   |status_info_admin_data| : JSON object : The tag NObj's
    ##   status info's admin data.  Optional if no change.
    ##
    ##   |string_data| : JSON object : The tag's string data.  Names
    ##   in the JSON object are names of the tag's string data and
    ##   their values are values of the tag's string data or |null|.
    ##   If |null|, the name/value pair is deleted.  Otherwise, the
    ##   name/value pair is updated.  Any existing string data
    ##   name/value pair with no matching name specified is left
    ##   unchanged.  Optional if no change.
    ##
    ##   |redirect| : JSON object : Optional if no change.
    ##
    ##     |to| : String? : Tag name to which this tag is redirected.
    ##     If |null|, any existing redirect is removed.  Otherwise,
    ##     redirect is set to the value.
    ##
    ##     |langs| : JSON object : Optional if no change.
    ##
    ##       /localized tag name's language : Language/ : String? :
    ##       Localized tag name's value.  If |null|, any existing
    ##       localized tag name is removed.  Otherwise, localized tag
    ##       name's value is set to the value.
    ##
    ## Response.  No additional data.
    my $name = $self->{app}->text_param ('tag_name') // '';
    my $name_sha = sha $name;
    my $name_map = {$name => $name_sha};
    my $time = time;
    return Promise->all ([
      $self->new_nobj_list ([
        'context', 'operator',
        \"apploach-tag-[@{[$self->{app}->bare_param ('context_nobj_key') // '']}]-@{[encode_punycode $name]}",
        \'apploach-set-status',
      ]),
    ])->then (sub {
      my ($context, $operator, $tag_nobj, $ssnobj) = @{$_[0]->[0]};
      
      my $updates = {};
      for (qw(author_status owner_status admin_status)) {
        my $v = $self->{app}->bare_param ($_);
        next unless defined $v;
        return $self->throw ({reason => "Bad |$_|"})
            unless $v =~ /\A[1-9][0-9]*\z/ and 1 < $v and $v < 255;
        $updates->{$_} = 0+$v;
      } # status

      my $d1 = $self->optional_json_object_param ('status_info_author_data');
      my $d2 = $self->optional_json_object_param ('status_info_owner_data');
      my $d3 = $self->optional_json_object_param ('status_info_admin_data');

      my $string_data = $self->optional_json_object_param ('string_data') || {};
      my $deleted_string_data = [];
      for (keys %$string_data) {
        unless (defined $string_data->{$_}) {
          push @$deleted_string_data, $_;
          delete $string_data->{$_};
        }
      }

      my $redirects = $self->optional_json_object_param ('redirect') || {};

      return Promise->resolve->then (sub {
        return unless $updates->{author_status} or
            $updates->{owner_status} or
            $updates->{admin_status} or
            defined $d1 or defined $d2 or defined $d3;

        return $self->db->transaction->then (sub {
          my $tr = $_[0];
          return $tr->select ('tag', {
            ($self->app_id_columns),
            ($context->to_columns ('context')),
            tag_name_sha => $name_sha,
          }, source_name => 'master', fields => [
            'author_status', 'owner_status', 'admin_status',
          ], lock => 'share')->then (sub {
            my $current = $_[0]->first // {
              author_status => 0,
              owner_status => 0,
              admin_status => 0,
            };
            for (qw(author_status owner_status admin_status)) {
              delete $updates->{$_} if defined $updates->{$_} and
                  $updates->{$_} == $current->{$_};
            }
            my $data = {
              old => {
                author_status => $current->{author_status},
                owner_status => $current->{owner_status},
                admin_status => $current->{admin_status},
              },
              new => {
                author_status => $updates->{author_status} // $current->{author_status},
                owner_status => $updates->{owner_status} // $current->{owner_status},
                admin_status => $updates->{admin_status} // $current->{admin_status},
              },
            };
            return $self->set_status_info
                ($tr, $operator, $tag_nobj, $ssnobj, $data, $d1, $d2, $d3);
          })->then (sub {
            return unless keys %$updates;
            return $tr->insert ('tag', [{
              ($self->app_id_columns),
              ($context->to_columns ('context')),
              tag_name => Dongry::Type->serialize ('text', $name),
              tag_name_sha => $name_sha,
              author_status => $updates->{author_status} // 0,
              owner_status => $updates->{owner_status} // 0,
              admin_status => $updates->{admin_status} // 0,
              count => 0,
              timestamp => $time,
            }], source_name => 'master', duplicate => {
              (defined $updates->{author_status} ? (author_status => $self->db->bare_sql_fragment ('VALUES(`author_status`)')) : ()),
              (defined $updates->{owner_status} ? (owner_status => $self->db->bare_sql_fragment ('VALUES(`owner_status`)')) : ()),
              (defined $updates->{admin_status} ? (admin_status => $self->db->bare_sql_fragment ('VALUES(`admin_status`)')) : ()),
              timestamp => $self->db->bare_sql_fragment ('VALUES(`timestamp`)'),
            });
          })->then (sub {
            delete $name_map->{$name};
            return $tr->commit->then (sub { undef $tr });
          })->finally (sub {
            return $tr->rollback if defined $tr;
          });
        });
      })->then (sub {
        return unless keys %$string_data;
        return $self->db->insert ('tag_string_data', [map {
          +{
            ($self->app_id_columns),
            ($context->to_columns ('context')),
            tag_name_sha => $name_sha,
            name => Dongry::Type->serialize ('text', $_),
            value => Dongry::Type->serialize ('text', $string_data->{$_}),
            timestamp => $time,
          };
        } keys %$string_data], source_name => 'master', duplicate => 'replace');
      })->then (sub {
        return unless @$deleted_string_data;
        return $self->db->delete ('tag_string_data', {
          ($self->app_id_columns),
          ($context->to_columns ('context')),
          tag_name_sha => $name_sha,
          name => {-in => [map { Dongry::Type->serialize ('text', $_) } @$deleted_string_data]},
        }, source_name => 'master');
      })->then (sub {
        my @from_sha;
        if (defined $redirects->{to}) {
          my $normalized = normalize_tag_name $redirects->{to};
          if ($name eq $normalized) {
            push @from_sha, $name_sha;
          } else {
            push @from_sha, $name_sha, sha $redirects->{to};
            $name_map->{$redirects->{to}} = $from_sha[-1];
            $redirects->{to} = $normalized;
          }
          {
            my $normalized = normalize_tag_name $name;
            unless ($name eq $normalized) {
              push @from_sha, sha $normalized;
              $name_map->{$normalized} = $from_sha[-1];
            }
          }
        } else {
          my $normalized = normalize_tag_name $name;
          unless ($name eq $normalized) {
            $redirects->{to} = $normalized;
            push @from_sha, $name_sha;
          }
        }
        for my $lang (keys %{$redirects->{langs} or {}}) {
          my $n = $redirects->{langs}->{$lang};
          next unless defined $n;
          my $nn = normalize_tag_name $n;
          next if $n eq $name or $nn eq $name;
          push @from_sha, sha $n;
          $name_map->{$n} = $from_sha[-1];
          unless ($n eq $nn) {
            push @from_sha, sha $nn;
            $name_map->{$nn} = $from_sha[-1];
            $redirects->{langs}->{$lang} = $nn;
          }
          $redirects->{to} //= $name;
        }
        if (@from_sha) {
          return $self->db->transaction->then (sub {
            my $tr = $_[0];
            my $final_name_sha = sha $redirects->{to};
            $name_map->{$redirects->{to}} = $final_name_sha;
            return $tr->select ('tag_redirect', {
              ($self->app_id_columns),
              ($context->to_columns ('context')),
              from_tag_name_sha => $final_name_sha,
            }, source_name => 'master', fields => ['to_tag_name_sha'])->then (sub {
              my $v = $_[0]->first;
              $final_name_sha = $v->{to_tag_name_sha} if defined $v;
              return $tr->insert ('tag_redirect', [map { {
                ($self->app_id_columns),
                ($context->to_columns ('context')),
                from_tag_name_sha => $_,
                to_tag_name_sha => $final_name_sha,
                timestamp => $time,
              } } @from_sha], source_name => 'master', duplicate => 'replace');
            })->then (sub {
              return $tr->update ('tag_redirect', {
                to_tag_name_sha => $final_name_sha,
                timestamp => $time,
              }, where => {
                ($self->app_id_columns),
                ($context->to_columns ('context')),
                to_tag_name_sha => {-in => \@from_sha},
              }, source_name => 'master');
            })->then (sub {
              return $tr->commit->then (sub { undef $tr });
            })->finally (sub {
              return $tr->rollback if defined $tr;
            });
          });
        } elsif (exists $redirects->{to}) {
          return $self->db->delete ('tag_redirect', {
            ($self->app_id_columns),
            ($context->to_columns ('context')),
            from_tag_name_sha => $name_sha,
          }, source_name => 'master');
        }
      })->then (sub {
        my @insert;
        my @delete;
        for my $lang (keys %{$redirects->{langs} or {}}) {
          if (defined $redirects->{langs}->{$lang}) {
            push @insert, {
              ($self->app_id_columns),
              ($context->to_columns ('context')),
              tag_name_sha => $name_sha,
              localized_tag_name => Dongry::Type->serialize ('text', $redirects->{langs}->{$lang}),
              localized_tag_name_sha => sha $redirects->{langs}->{$lang},
              lang => Dongry::Type->serialize ('text', $lang),
              timestamp => $time,
            };
          } else {
            push @delete, Dongry::Type->serialize ('text', $lang);
          }
        }
        return Promise->all ([
          (@insert ? $self->db->insert ('tag_name', \@insert, source_name => 'master') : undef),
          (@delete ? $self->db->delete ('tag_name', {
            ($self->app_id_columns),
            ($context->to_columns ('context')),
            tag_name_sha => $name_sha,
            lang => {-in => \@delete},
          }, source_name => 'master') : undef),
        ]);
      })->then (sub {
        return unless keys %$name_map;
        return $self->db->insert ('tag', [map { {
          ($self->app_id_columns),
          ($context->to_columns ('context')),
          tag_name => Dongry::Type->serialize ('text', $_),
          tag_name_sha => $name_map->{$_},
          author_status => 0,
          owner_status => 0,
          admin_status => 0,
          count => 0,
          timestamp => $time,
        } } keys %$name_map], source_name => 'master', duplicate => 'ignore');
      });
    })->then (sub {
      return $self->json ({});
    });
  }

  if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'items.json') {
    ## /{app_id}/tag/items.json - Get items associated with a tag.
    ##
    ## Parameters.
    ##
    ##   NObj (|context|) : The tag item's context NObj.
    ##
    ##   |tag_name| : String : The tag item's tag name.  Zero or more
    ##   parameters can be specified.
    ##
    ##   |score| : Boolean : Sort by tag item's score.
    ##
    ##   Pages.  Not available when |score| is true.
    ##
    ## List response of tag items.
    ##
    ##   NObj (|item|) : The tag item's item NObj.
    ##
    ##   |timestamp| : Timestamp : The tag item's timestamp.
    ##
    ##   |score| : Integer : The tag item's score.
    my $page = Pager::this_page ($self, limit => 10, max_limit => 10000);
    my $by_score = $self->{app}->bare_param ('score');
    return Promise->all ([
      $self->nobj ('context'),
    ])->then (sub {
      my ($context) = @{$_[0]};
      return [] if $context->is_error;
      my $shas = {};
      for my $n (@{$self->{app}->text_param_list ('tag_name')}) {
        my $nn = normalize_tag_name $n;
        $shas->{sha $n} = 1;
        $shas->{sha $nn} = 1;
      }
      return [] unless keys %$shas;
      return $self->db->select ('tag_redirect', {
        ($self->app_id_columns),
        ($context->to_columns ('context')),
        from_tag_name_sha => {-in => [keys %$shas]},
      }, source_name => 'master', fields => ['to_tag_name_sha'])->then (sub {
        my $v = $_[0];
        for (@{defined $v ? $v->all : []}) {
          $shas->{$_->{to_tag_name_sha}} = 1;
        }
        return $self->db->select ('tag_redirect', {
          ($self->app_id_columns),
          ($context->to_columns ('context')),
          to_tag_name_sha => {-in => [keys %$shas]},
        }, source_name => 'master', fields => ['from_tag_name_sha']);
      })->then (sub {
        my $v = $_[0];
        for (@{defined $v ? $v->all : []}) {
          $shas->{$_->{from_tag_name_sha}} = 1;
        }
        my $where = {
          ($self->app_id_columns),
          ($context->to_columns ('context')),
          tag_name_sha => {-in => [keys %$shas]},
        };
        $where->{timestamp} = $page->{value} if defined $page->{value};
        my $order = ['timestamp', $page->{order_direction}];
        unshift @$order, 'score', 'desc' if $by_score;
        return $self->db->select ('tag_item', $where, source_name => 'master',
          fields => ['item_nobj_id', 'score', 'timestamp'],
          distinct => 1,
          offset => $page->{offset}, limit => $page->{limit},
          order => $order,
        );
      })->then (sub {
        return $_[0]->all->to_a;
      });
    })->then (sub {
      my $items = $_[0];
      return $self->replace_nobj_ids ($items, ['item'])->then (sub {
        my $next_page = $by_score ? {} : Pager::next_page $page, $items, 'timestamp';
        return $self->json ({items => $items, %$next_page});
      });
    });
  } # /tag/items.json

  if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'publish.json') {
    ## /{app_id}/tag/publish.json - Update tags associated with an item.
    ##
    ## Parameters.
    ##
    ##   NObj (|context|) : The tag item's context NObj.
    ##
    ##   NObj (|item|) : The tag item's item NObj.
    ##
    ##   |tag| : String : The tag item's tag name.  Zero or more
    ##   parameters can be specified.
    ##
    ## Response.  No additional data.
    return Promise->all ([
      $self->new_nobj_list (['context', 'item']),
    ])->then (sub {
      my ($context, $item) = @{$_[0]->[0]};
      my $tags = $self->{app}->text_param_list ('tag');
      my $score = $self->{app}->bare_param ('score');
      my $time = time;
      return $self->publish_tags ($self->db, $context, $item, $tags, $score, $time);
    })->then (sub {
      return $self->json ({});
    });
  } # /tag/publish.json

  if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'related.json') {
    ## /{app_id}/tag/related.json - Get related tags.
    ##
    ## Parameters.
    ##
    ##   NObj (|context|) : The tag's context NObj.
    ##
    ##   |tag_name| : String : The tag's tag name.
    ##
    ## List response of:
    ##
    ##   |tag_name| : String : The tag's tag name.
    ##
    ##   |score| : Number : The score of "related"ness.  The greater,
    ##   the more related.
    return Promise->all ([
      $self->nobj ('context'),
    ])->then (sub {
      my ($context) = @{$_[0]};
      return [] if $context->is_error;
      my $n = $self->{app}->text_param ('tag_name') // '';
      my $nn = normalize_tag_name $n;
      my $shas = {sha $n => 1, sha $nn => 1};
      my $limit = $self->{app}->bare_param ('limit') // 30;
      return $self->throw ({reason => "Bad |limit|"}) if $limit > 100;
      return $self->db->select ('tag_item', {
        ($self->app_id_columns),
        ($context->to_columns ('context')),
        tag_name_sha => {-in => [keys %$shas]},
      }, fields => ['item_nobj_id'], limit => 500, source_name => 'master')->then (sub {
        my $ids = [map { $_->{item_nobj_id} } @{$_[0]->all}];
        return [] unless @$ids;
        return $self->db->select ('tag_item', {
          ($self->app_id_columns),
          ($context->to_columns ('context')),
          item_nobj_id => {-in => $ids},
          tag_name_sha => {-not_in => [keys %$shas]},
        }, fields => [{-count => undef, as => 'count'}, 'tag_name_sha'],
          group => ['tag_name_sha'],
          order => ['count', 'DESC'], limit => $limit,
          source_name => 'master',
        )->then (sub {
          my $items = $_[0]->all;
          return [] unless @$items;
          return $self->db->select ('tag', {
            ($self->app_id_columns),
            ($context->to_columns ('context')),
            tag_name_sha => {-in => [map { $_->{tag_name_sha} } @$items]},
          }, source_name => 'master', fields => ['tag_name', 'tag_name_sha'])->then (sub {
            my $map = {};
            for (@{$_[0]->all}) {
              $map->{$_->{tag_name_sha}} = Dongry::Type->parse ('text', $_->{tag_name});
            }
            return [map {
              {
                tag_name => $map->{$_->{tag_name_sha}},
                score => $_->{count},
              };
            } @$items];
          });
        });
      });
    })->then (sub {
      my $items = $_[0];
      return $self->json ({items => $items});
    });
  } # /tag/related.json
  
  return $self->{app}->throw_error (404);
} # run_tag

# XXX
sub bu ($) {
  my $b64 = encode_web_base64 $_[0];
  $b64 =~ tr{+/}{-_};
  $b64 =~ s/=+\z//;
  return $b64;
} # bu

# XXX
sub _vapid_authorization ($$$) {
  my ($pub_key, $prv_key, $url) = @_;

  my $k = bu join '', map { pack 'C', $_ } @$pub_key;

  my $exp = time + 10*3600;
  my $z = '{"aud":"'.$url->get_origin->to_ascii # to_unicode according to spec
        .'","exp":'.$exp.'}';
  my $x = bu ('{"alg":"ES256","typ":"JWT"}') . '.' . bu (encode_web_utf8 $z);

  my $vkey = Crypt::Perl::ECDSA::Parse::private (join '', map { pack 'C', $_ } @$prv_key);
  my $sig = $vkey->sign_jwa ($x);

  my $t = $x . '.' . bu ($sig);
  
  return 'vapid t='.$t.', k='.$k;
} # _vapid_authorization

sub run_notification ($) {
  my $self = $_[0];

  ## Notifications.

  ## Topics.  A topic is an NObj representing a kind of notification
  ## events, which can be subscribed by notification event
  ## subscribers.

  ## A topic subscription has topic : NObj with index, subscriber :
  ## NObj, created : Timestamp, updated : Timestamp, channel : NObj,
  ## which identifies an application-specific destination media or
  ## platform of the notification, e.g. email, Web notification, and
  ## IRC, status : 2 - enabled, 3 - disabled, 4 - inherit, data :
  ## object, which can contain application-specific parameters
  ## applicable to the channel.

  if (@{$self->{path}} == 2 and
      $self->{path}->[0] eq 'topic' and
      $self->{path}->[1] eq 'subscribe.json') {
    ## /{app_id}/notification/topic/subscribe.json - Update a topic
    ## subscription.
    ##
    ## Parameters.
    ##
    ##   NObj (|topic| with index) : The topic subscription's topic.
    ##   Required.
    ##
    ##   NObj (|subscriber|) : The topic subscription's subscriber.
    ##   Required.
    ##
    ##   NObj (|channel|) : The topic subscription's channel.
    ##   Required.
    ##
    ##   |status| : Integer : The topic subscription's status.
    ##   Required.
    ##
    ##   |data| : JSON object : The topic subscription's data.
    ##   Required.
    ##
    ##   |is_default| : Boolean : If true, the topic subscription is
    ##   added only when there is no topic subscription with same
    ##   topic, subscriber, and channel.  Otherwise, any existing
    ##   topic subscription is not updated.
    ##
    ## Empty response.
    return Promise->all ([
      $self->new_nobj_list (['topic', 'topic_index', 'subscriber', 'channel']),
    ])->then (sub {
      my ($topic, $topic_index, $subscriber, $channel) = @{$_[0]->[0]};

      my $status = $self->{app}->bare_param ('status') // '';
      return $self->throw ({reason => "Bad |status|"})
          unless $status =~ /\A[1-9][0-9]*\z/ and
                 1 < $status and $status < 255;
      my $data = $self->json_object_param ('data');
      my $is_default = $self->{app}->bare_param ('is_default');
      my $time = time;
      return $self->db->insert ('topic_subscription', [{
        ($self->app_id_columns),
        ($topic->to_columns ('topic')),
        ($topic_index->to_columns ('topic_index')),
        ($subscriber->to_columns ('subscriber')),
        ($channel->to_columns ('channel')),
        created => $time,
        updated => $time,
        status => 0+$status,
        data => Dongry::Type->serialize ('json', $data),
      }], duplicate => ($is_default ? 'ignore' : {
        status => $self->db->bare_sql_fragment ('VALUES(`status`)'),
        data => $self->db->bare_sql_fragment ('VALUES(`data`)'),
        updated => $self->db->bare_sql_fragment ('VALUES(`updated`)'),
      }), source_name => 'master');
    })->then (sub {
      return $self->json ({});
    });
  } elsif (@{$self->{path}} == 2 and
           $self->{path}->[0] eq 'topic' and
           $self->{path}->[1] eq 'list.json') {
    ## /{app_id}/notification/topic/list.json - Get topic
    ## subscriptions.
    ##
    ## Parameters.
    ##
    ##   NObj (|subscriber|) : The topic subscription's subscriber.
    ##   Required.
    ##
    ##   NObj (|topic|) : The topic subscription's topic.  Zero or
    ##   more parameters can be specified.
    ##
    ##   NObj (|topic_index|) : The topic subscription's topic's
    ##   index.
    ##
    ##   NObj (|channel|) : The topic subscription's channel.  Zero or
    ##   more parameters can be specified.
    ##
    ##   Pages.
    ##
    ## List response of:
    ##
    ##   NObj (|topic|) : The topic subscription's topic.
    ##
    ##   NObj (|subscriber|) : The topic subscription's subscriber.
    ##
    ##   NObj (|channel|) : The topic subscription's channel.
    ##
    ##   |created| : The topic subscription's created.
    ##
    ##   |updated| : The topic subscription's updated.
    ##
    ##   |status| : The topic subscription's status.
    ##
    ##   |data| : The topic subscription's data.
    ##
    my $page = Pager::this_page ($self, limit => 100, max_limit => 10000);
    return Promise->all ([
      $self->nobj_list_set (['topic', 'topic_index', 'channel', 'subscriber']),
    ])->then (sub {
      my ($topics, $topic_indexes, $channels, $subscribers) = @{$_[0]->[0]};

      my $has_topics = 0+@$topics;
      $topics = [grep { not $_->is_error } @$topics];
      my $has_channels = 0+@$channels;
      $channels = [grep { not $_->is_error } @$channels];
      my $subscriber = $subscribers->[0];
      return $self->throw ({reason => "Bad subscriber"})
          unless defined $subscriber;
      my $topic_index = $topic_indexes->[0];
      
      return [] if $subscriber->is_error;
      return [] if $has_topics and not @$topics;
      return [] if $has_channels and not @$channels;
      return [] if defined $topic_index and $topic_index->is_error;

      my $where = {
        ($self->app_id_columns),
        ($subscriber->to_columns ('subscriber')),
      };
      $where->{topic_nobj_id} = {-in => [map { $_->nobj_id } @$topics]}
          if @$topics;
      $where->{channel_nobj_id} = {-in => [map { $_->nobj_id } @$channels]}
          if @$channels;
      $where = {%$where, ($topic_index->to_columns ('topic_index'))}
          if defined $topic_index;
      $where->{updated} = $page->{value} if defined $page->{value};

      return $self->db->select ('topic_subscription', $where, fields => [
        'topic_nobj_id', 'subscriber_nobj_id', 'channel_nobj_id',
        'status', 'data', 'created', 'updated',
      ], source_name => 'master',
        offset => $page->{offset}, limit => $page->{limit},
        order => ['updated', $page->{order_direction}],
      )->then (sub {
        return $_[0]->all->to_a;
      });
    })->then (sub {
      return $self->replace_nobj_ids ($_[0], ['topic', 'subscriber', 'channel']);
    })->then (sub {
      my $items = $_[0];
      my $next_page = Pager::next_page $page, $items, 'updated';
      for (@$items) {
        $_->{data} = Dongry::Type->parse ('json', $_->{data});
      }
      return $self->json ({items => $items, %$next_page});
    });
  }

  ## NEvents.  An nevent is an event in the notification system.  An
  ## nevent has ID : ID, which identifies the nevent uniquely, key :
  ## Key, which is a short string that is unique within an
  ## application-specific realm, topic : NObj, data : object, which is
  ## an application-specific detail of the nevent, timestamp :
  ## Timestamp, expires : Timestamp, after which the nevent is
  ## discarded.
  ##
  ## When an nevent is fired, it is queued to notification channels
  ## according to the applicable topic subscriptions.  A queued nevent
  ## has nevent : nevent, channel : NObj, topic subscription : topic
  ## subscription, result data : object, which is an
  ## application-specific result log of the processing of the queued
  ## nevent.
  ##
  ## Expired nevents and queued nevents are removed.

  ## A subscriber : NObj has a last checked timestamp : Timestamp.

  if (@{$self->{path}} == 2 and
      $self->{path}->[0] eq 'nevent' and
      $self->{path}->[1] eq 'fire.json') {
    ## /{app_id}/notification/nevent/fire.json - Fire an nevent.
    ##
    ## Parameters.
    ##
    ##   Notifications (||).
    ##
    ##   |data| : JSON object : The nevent's data.  Required.
    ##
    ##   |timestamp| : Timestamp : The nevent's timestamp.  If
    ##   omitted, the curernt time.
    ##
    ##   |expires| : Timestamp : The nevent's expires.  If omitted, 30
    ##   days later of the current time.
    ##
    ## Response.
    ##
    ##   |nevent_id| : ID : The nevent's ID.
    ##
    ##   |timestamp| : Timestamp : The nevent's timestamp.
    ##
    ##   |expires| : Timestamp : The nevent's expires.
    ##
    return $self->fire_nevent (
      '',
      $self->json_object_param ('data'),
      timestamp => $self->{app}->bare_param ('timestamp'),
      expires => $self->{app}->bare_param ('expires'),
    )->then (sub {
      return $self->json ($_[0]);
    });
  } elsif (@{$self->{path}} == 2 and
           $self->{path}->[0] eq 'nevent' and
           $self->{path}->[1] eq 'list.json') {
    ## /{app_id}/notification/nevent/list.json - Get a list of nevents
    ## for a subscriber.
    ##
    ## Parameters.
    ##
    ##   NObj (|subscriber|) : The nevent's subscriber.
    ##
    ##   |nevent_id| : ID : The nevent's ID.  Either NObj
    ##   (|subscriber|) or |nevent_id|, or both, is required.
    ##
    ##   NObj (|topic|) : The nevent's topic.  Zero or more parameters
    ##   can be specified.
    ##
    ##   NObj (|topic_excluded|) : The topic that should not match to
    ##   the nevent's topic.  Zero or more parameters can be
    ##   specified.
    ##
    ##   Pages.
    ##
    ## List response of:
    ##
    ##   NObj (|subscriber|) : The nevent's subscriber.
    ##
    ##   NObj (|topic|) : The nevent's topic.
    ##
    ##   |nevent_id| : ID : The nevent's ID.
    ##
    ##   |data| : JSON object : The nevent's data.
    ##
    ##   |timestamp| : Timestamp : The nevent's timestamp.
    ##
    ##   |expires| : Timestamp : The nevent's expires.
    ##
    ## ... with additional property:
    ##
    ##   |last_checked| : Timestamp : The subscriber's last checked
    ##   timestamp.
    ##
    my $page = Pager::this_page ($self, limit => 10, max_limit => 10000);
    my $last_checked = 0;
    return Promise->all ([
      $self->nobj ('subscriber'),
      $self->nobj_list_set (['topic', 'topic_excluded']),
    ])->then (sub {
      my ($subscriber) = @{$_[0]};
      my ($topic_includeds, $topic_excludeds) = @{$_[0]->[1]};
      return [] if $subscriber->is_error and not $subscriber->missing;

      my $now = time;
      my $where = {
        ($self->app_id_columns),
        expires => {'>=', $now},
      };
      $where = {%$where, ($subscriber->to_columns ('subscriber'))}
          unless $subscriber->is_error;
      my $nevent_id = $self->{app}->bare_param ('nevent_id');
      $where->{nevent_id} = $nevent_id if defined $nevent_id;
      return $self->throw ({reason => 'Bad subscriber'})
          unless defined $where->{subscriber_nobj_id} or
                 defined $where->{nevent_id};
      $where->{timestamp} = $page->{value} if defined $page->{value};

      if (@$topic_includeds) {
        $topic_includeds = [grep { not $_->is_error } @$topic_includeds];
        return [] unless @$topic_includeds;
        $where->{topic_nobj_id}->{-in} = [map { $_->nobj_id } @$topic_includeds];
      }
      if (@$topic_excludeds) {
        $topic_excludeds = [grep { not $_->is_error } @$topic_excludeds];
        $where->{topic_nobj_id}->{-not_in} = [map { $_->nobj_id } @$topic_excludeds]
            if @$topic_excludeds;
      }

      return $self->db->select ('nevent', $where, fields => [
        'subscriber_nobj_id', 'topic_nobj_id',
        'nevent_id', 'data', 'timestamp', 'expires',
      ], source_name => 'master',
        offset => $page->{offset}, limit => $page->{limit},
        order => ['timestamp', $page->{order_direction}],
      )->then (sub {
        my $list = $_[0]->all->to_a;
        return $list if $subscriber->is_error;
        return $self->db->select ('nevent_list', {
          ($self->app_id_columns),
          ($subscriber->to_columns ('subscriber')),
        }, fields => ['last_checked'], source_name => 'master')->then (sub {
          my $v = $_[0]->first;
          $last_checked = defined $v ? $v->{last_checked} : 0;
          return $list;
        });
      });
    })->then (sub {
      my $items = $_[0];
      return $self->replace_nobj_ids ($items, ['subscriber', 'topic']);
    })->then (sub {
      my $items = $_[0];
      my $next_page = Pager::next_page $page, $items, 'timestamp';
      for (@$items) {
        $_->{nevent_id} .= '';
        $_->{data} = Dongry::Type->parse ('json', $_->{data});
      }
      return $self->json ({items => $items, %$next_page,
                           last_checked => $last_checked});
    });
  } elsif (@{$self->{path}} == 2 and
           $self->{path}->[0] eq 'nevent' and
           $self->{path}->[1] eq 'listcount.json') {
    ## /{app_id}/notification/nevent/listcount.json - Get the number
    ## of unchecked nevents for a subscriber.
    ##
    ## Parameters.
    ##
    ##   NObj (|subscriber|) : The nevent's subscriber.  Required.
    ##
    ##   NObj (|topic|) : The nevent's topic.  Zero or more parameters
    ##   can be specified.
    ##
    ##   NObj (|topic_excluded|) : The topic that should not match to
    ##   the nevent's topic.  Zero or more parameters can be
    ##   specified.
    ##
    ## Response.
    ##
    ##   |unchecked_count| : Integer : The number of unchecked
    ##   nevents.
    ##
    ##   |last_checked| : Timestamp : The subscriber's last checked
    ##   timestamp.
    ##
    my $last_checked = 0;
    return Promise->all ([
      $self->nobj ('subscriber'),
      $self->nobj_list_set (['topic', 'topic_excluded']),
    ])->then (sub {
      my ($subscriber) = @{$_[0]};
      my ($topic_includeds, $topic_excludeds) = @{$_[0]->[1]};
      return 0 if $subscriber->is_error;

      my $now = time;
      my $where = {
        ($self->app_id_columns),
        ($subscriber->to_columns ('subscriber')),
        expires => {'>=', $now},
      };

      return $self->db->select ('nevent_list', {
        ($self->app_id_columns),
        ($subscriber->to_columns ('subscriber')),
      }, fields => ['last_checked'], source_name => 'master')->then (sub {
        my $v = $_[0]->first;
        $last_checked = defined $v ? $v->{last_checked} : 0;

        if (@$topic_includeds) {
          $topic_includeds = [grep { not $_->is_error } @$topic_includeds];
          return 0 unless @$topic_includeds;
          $where->{topic_nobj_id}->{-in} = [map { $_->nobj_id } @$topic_includeds];
        }
        if (@$topic_excludeds) {
          $topic_excludeds = [grep { not $_->is_error } @$topic_excludeds];
          $where->{topic_nobj_id}->{-not_in} = [map { $_->nobj_id } @$topic_excludeds]
              if @$topic_excludeds;
        }
        
        $where->{timestamp} = {'>', $last_checked,
                               '<=', time};
        return $self->db->select ('nevent', $where, fields => [
          {-count => undef, as => 'count'},
        ], source_name => 'master')->then (sub {
          my $v = $_[0]->first;
          return defined $v ? $v->{count} : 0;
        });
      });
    })->then (sub {
      my $count = $_[0];
      return $self->json ({
        unchecked_count => $count,
        last_checked => $last_checked,
      });
    });
  } elsif (@{$self->{path}} == 2 and
           $self->{path}->[0] eq 'nevent' and
           $self->{path}->[1] eq 'listtouch.json') {
    ## /{app_id}/notification/nevent/listtouch.json - Set the last
    ## checked timestamp of the nevent list.
    ##
    ## Parameters.
    ##
    ##   NObj (|subscriber|) : The subscriber.  Required.
    ##
    ##   |timestamp| : Timestamp : The timestamp.  Required.
    ##
    ## Empty response.
    return Promise->all ([
      $self->new_nobj_list (['subscriber']),
    ])->then (sub {
      my ($subscriber) = @{$_[0]->[0]};
      my $time = $self->{app}->bare_param ('timestamp');
      return $self->throw ({reason => 'Bad |timestamp|'}) unless defined $time;
      return $self->db->insert ('nevent_list', [{
        ($self->app_id_columns),
        ($subscriber->to_columns ('subscriber')),
        last_checked => 0+$time,
      }], duplicate => {
        last_checked => $self->db->bare_sql_fragment ('GREATEST(VALUES(`last_checked`), `last_checked`)'),
      });
    })->then (sub {
      return $self->json ({});
    });
  }
  
  if (@{$self->{path}} == 2 and
      $self->{path}->[0] eq 'nevent' and
      $self->{path}->[1] eq 'lockqueued.json') {
    ## /{app_id}/notification/nevent/lockqueued.json - Lock nevents
    ## queued for a channel for processing.
    ##
    ## Parameters.
    ##
    ##   NObj (|channel|) : The queued nevent's channel.  Required.
    ##
    ##   |limit| : Integer : The maximum number of queued nevents to
    ##   return and lock.  Defaulted to 10.
    ##
    ## List response of:
    ##
    ##   NObj (|subscriber|) : The queued nevent's nevent's
    ##   subscriber.
    ##
    ##   NObj (|topic|) : The queued nevent's nevent's topic.
    ##
    ##   |nevent_id| : ID : The queued nevent's nevent's ID.
    ##
    ##   |data| : JSON object : The queued nevent's nevent's data.
    ##
    ##   |timestamp| : Timestamp : The queued nevent's nevent's
    ##   timestamp.
    ##
    ##   |expires| : Timestamp : The queued nevent's nevent's expires.
    ##
    ##   |topic_subscription_data| : JSON object : The queued nevent's
    ##   topic subscription's data.
    ##
    ## The returned queued nevents are locked for 600 seconds after
    ## the invocation of this end point.
    return Promise->all ([
      $self->nobj ('channel'),
    ])->then (sub {
      my ($channel) = @{$_[0]};
      return [] if $channel->is_error;
      
      my $limit = 0+($self->{app}->bare_param ('limit') || 10);
      my $now = time;
      my $max_locked = $now - 10*60;
      return $self->db->update ('nevent_queue', {
        locked => $now,
      }, source_name => 'master', where => {
        ($self->app_id_columns),
        ($channel->to_columns ('channel')),
        timestamp => {'<=', $now},
        expires => {'>', $now},
        result_done => 0, # not yet done
        locked => {'<', $max_locked},
      }, order => ['timestamp', 'asc'], limit => $limit)->then (sub {
        my $v = $_[0];
        return [] unless $v->row_count;
        return $self->db->execute (q{select
            `nevent`.`nevent_id` as `nevent_id`,
            `nevent`.`topic_nobj_id` as `topic_nobj_id`,
            `nevent`.`subscriber_nobj_id` as `subscriber_nobj_id`,
            `nevent`.`data` as `data`,
            `nevent`.`timestamp` as `timestamp`,
            `nevent`.`expires` as `expires`,
            `nevent_queue`.`topic_subscription_data` as `topic_subscription_data`
          from `nevent_queue` inner join `nevent` on
            `nevent_queue`.`app_id` = `nevent`.`app_id` and
            `nevent_queue`.`nevent_id` = `nevent`.`nevent_id` and
            `nevent_queue`.`subscriber_nobj_id` = `nevent`.`subscriber_nobj_id`
          where
            `nevent`.`app_id` = :app_id and
            `nevent_queue`.`locked` = :locked
          order by `nevent`.`timestamp` asc
        }, {
          ($self->app_id_columns),
          locked => $now,
        }, source_name => 'master')->then (sub {
          return $_[0]->all;
        });
      }, sub {
        my $e = $_[0];
        if (UNIVERSAL::can ($e, 'error_text') and
            $e->error_text =~ m{^Deadlock found when trying to get lock}) {
          #Deadlock found when trying to get lock; try restarting transaction
          return [];
        }
        die $e;
      });
    })->then (sub {
      my $items = $_[0];
      return $self->replace_nobj_ids ($items, ['subscriber', 'topic']);
    })->then (sub {
      my $items = $_[0];
      for (@$items) {
        $_->{nevent_id} .= '';
        $_->{data} = Dongry::Type->parse ('json', $_->{data});
        $_->{topic_subscription_data} = Dongry::Type->parse ('json', $_->{topic_subscription_data});
      }
      return $self->json ({items => $items});
    });
  } elsif (@{$self->{path}} == 2 and
           $self->{path}->[0] eq 'nevent' and
           $self->{path}->[1] eq 'donequeued.json') {
    ## /{app_id}/notification/nevent/donequeued.json - Mark locked
    ## queued nevent as processed.
    ##
    ## Parameters.
    ##
    ##   NObj (|subscriber|) : The queued nevent's nevent's
    ##   subscriber.  Required.
    ##
    ##   |nevent_id| : ID : The queued nevent's nevent's ID.
    ##   Required.
    ##
    ##   NObj (|channel|) : The queued nevent's channel.  Required.
    ##
    ##   |data| : JSON object : The queued nevent's result data.
    ##   Required.
    ##
    ## Empty response.
    return Promise->all ([
      $self->nobj ('subscriber'),
      $self->nobj ('channel'),
    ])->then (sub {
      my ($subscriber, $channel) = @{$_[0]};
      my $nevent_id = $self->{app}->bare_param ('nevent_id') // '';
      my $data = $self->json_object_param ('data');
      return $self->done_queued_nevent
          ($subscriber, $channel, $nevent_id, $data);
    })->then (sub {
      return $self->json ({});
    })->then (sub {
      return $self->expire_old_nevents;
    });
  }

  ## Hooks.  A hook represents an external URL that should be invoked
  ## upon relevants events.  It can be used to store end point URLs
  ## for the Push API, for example.  A hook has subscriber : NObj,
  ## type : NObj, which represents the application-specific kind of
  ## the hook, URL : String, status : Integer, which represents the
  ## application-specific status of the hook, data : Object, which can
  ## contain application-specific parameters of the hook, created :
  ## Timestamp, updated : Timestamp, expires : Timestamp.  There can
  ## be at most one hook of same (subscriber, type, URL) tuple.

  if (@{$self->{path}} == 2 and
      $self->{path}->[0] eq 'hook' and
      $self->{path}->[1] eq 'subscribe.json') {
    ## /{app_id}/notification/hook/subscribe.json - Add a hook.
    ##
    ## Parameters.
    ##
    ##   NObj (|subscriber|) : The hook's subscriber.  Required.
    ##
    ##   NObj (|type|) : The hook's type.  Required.
    ##
    ##   |url| : String : The hook's URL.  It must be an absolute URL.
    ##   Required.
    ##
    ##   |status| : Integer : The hook's status.  Required.
    ##
    ##   |data| : JSON object : The hook's data.  Required.  If it
    ##   contains a name |apploach_subscription| whose value is an
    ##   object with a name |expirationTime|, the hook's expires is
    ##   set to its value, interpreted as a JavaScript date and time
    ##   string.
    ##
    ## Empty response.
    return Promise->all ([
      $self->new_nobj_list (['subscriber', 'type']),
    ])->then (sub {
      my ($subscriber, $type) = @{$_[0]->[0]};

      my $u = $self->{app}->text_param ('url') // '';
      return $self->throw ({reason => 'Bad |url|'}) unless length $u;
      my $url = Web::URL->parse_string ($u);
      return $self->throw ({reason => 'Bad |url|'}) unless defined $url;
      $url = Dongry::Type->serialize ('text', $url->stringify);
      ## Non HTTP(S) URLs are also allowed.

      my $status = $self->{app}->bare_param ('status') // '';
      return $self->throw ({reason => "Bad |status|"})
          unless ($status =~ /\A[1-9][0-9]*\z/ and
                  1 < $status and $status < 255);
      my $data = $self->json_object_param ('data');
      
      my $time = time;
      my $expires = time + 100*365*24*60*60;
      if (defined $data->{apploach_subscription} and
          ref $data->{apploach_subscription} eq 'HASH' and
          defined $data->{apploach_subscription}->{expirationTime}) {
        my $parser = Web::DateTime::Parser->new;
        $parser->onerror (sub { });
        my $dt = $parser->parse_js_date_time_string
            ($data->{apploach_subscription}->{expirationTime});
        $expires = $dt->to_unix_number if defined $dt;
      }
      return $self->db->insert ('hook', [{
        ($self->app_id_columns),
        ($subscriber->to_columns ('subscriber')),
        ($type->to_columns ('type')),
        url => $url,
        url_sha => sha1_hex ($url),
        status => $status,
        created => $time,
        updated => $time,
        expires => $expires,
        data => Dongry::Type->serialize ('json', $data),
      }], duplicate => {
        data => $self->db->bare_sql_fragment ('VALUES(`data`)'),
        updated => $self->db->bare_sql_fragment ('VALUES(`updated`)'),
        status => $self->db->bare_sql_fragment ('VALUES(`status`)'),
        expires => $self->db->bare_sql_fragment ('VALUES(`expires`)'),
      }, source_name => 'master');
    })->then (sub {
      return $self->json ({});
    });
  } elsif (@{$self->{path}} == 2 and
           $self->{path}->[0] eq 'hook' and
           $self->{path}->[1] eq 'delete.json') {
    ## /{app_id}/notification/hook/delete.json - Delete a hook.
    ##
    ## Parameters.
    ##
    ##   NObj (|subscriber|) : The hook's subscriber.  Required.
    ##
    ##   NObj (|type|) : The hook's type.  Required.
    ##
    ##   |url| : String : The hook's URL.  It must be an absolute URL.
    ##
    ##   |url_sha| : String : An opaque string identifying the hook
    ##   instead of |url|.  Either |url| or |url_sha| is required.
    ##
    ## Empty response.
    return Promise->all ([
      $self->nobj ('subscriber'),
      $self->nobj ('type'),
    ])->then (sub {
      my ($subscriber, $type) = @{$_[0]};
      
      my $u = $self->{app}->text_param ('url');
      my $hk = $self->{app}->bare_param ('url_sha');
      return $self->throw ({reason => 'Bad |url|'})
          unless defined $u or defined $hk;
      my $url;
      if (defined $u) {
        return unless length $u;
        $url = Web::URL->parse_string ($u);
        return unless defined $url;
        $url = Dongry::Type->serialize ('text', $url->stringify);
      }
      my $url_sha = $hk // sha1_hex ($url);

      return if $subscriber->is_error;
      return if $type->is_error;
      
      return $self->db->delete ('hook', {
        ($self->app_id_columns),
        ($subscriber->to_columns ('subscriber')),
        ($type->to_columns ('type')),
        (defined $url ? (url => $url) : ()),
        url_sha => $url_sha,
      }, source_name => 'master');
    })->then (sub {
      return $self->json ({});
    });
  } elsif (@{$self->{path}} == 2 and
           $self->{path}->[0] eq 'hook' and
           $self->{path}->[1] eq 'list.json') {
    ## /{app_id}/notification/hook/list.json - Get hooks.
    ##
    ## Parameters.
    ##
    ##   NObj (|subscriber|) : The hook's subscriber.  Required.
    ##
    ##   NObj (|type|) : The hook's type.  Zero or more parameters can
    ##   be specified.
    ##
    ##   Pages.
    ##
    ## List response of:
    ##
    ##   NObj (|subscriber|) : The hook's subscriber.
    ##
    ##   NObj (|type|) : The hook's type.
    ##
    ##   |url| : String : The hook's URL.
    ##
    ##   |url_sha| : String : An opaque string identifying the hook
    ##   instead of |url|.
    ##
    ##   |created| : Timestamp : The hook's created.
    ##
    ##   |updated| : Timestamp : The hook's updated.
    ##
    ##   |expires| : Timestamp : The hook's expires.
    ##
    ##   |status| : Integer : The hook's status.
    ##
    ##   |data| : Object : The hook's data.
    ##
    my $page = Pager::this_page ($self, limit => 100, max_limit => 10000);
    return Promise->all ([
      $self->nobj_list_set (['type', 'subscriber']),
    ])->then (sub {
      my ($types, $subscribers) = @{$_[0]->[0]};

      my $subscriber = $subscribers->[0];
      return $self->throw ({reason => "Bad subscriber"})
          unless defined $subscriber;

      return $self->get_hooks ($subscriber, $types, $page);
    })->then (sub {
      return $self->replace_nobj_ids ($_[0], ['subscriber', 'type']);
    })->then (sub {
      my $items = $_[0];
      my $next_page = Pager::next_page $page, $items, 'updated';
      for (@$items) {
        $_->{data} = Dongry::Type->parse ('json', $_->{data});
        $_->{url} = Dongry::Type->parse ('text', $_->{url});
      }
      return $self->json ({items => $items, %$next_page});
    });
  }

  if (@{$self->{path}} == 2 and
      $self->{path}->[0] eq 'send' and
      $self->{path}->[1] eq 'push.json') {
    ## /{app_id}/notification/send/push.json - Send a Push API
    ## notification.
    ##
    ## Parameters.
    ##
    ##   |url| : String : The Push API end point URL.  It must be an
    ##   absolute |https:| URL.  Zero or more parameters can be
    ##   specified.
    ##
    ##   NObj (|nevent_subscriber|) : The subscriber.  If no |url|
    ##   parameter is specified, URLs of the hooks whose subscriber is
    ##   the specified subscriber, type is |apploach-push|, and status
    ##   is |2|, are used. If |nevent_id| is specified, the subscriber
    ##   is also used as the queued nevent's subscriber.
    ##
    ##   |nevent_id| : ID : The queued nevent's ID.  If specified, the
    ##   queued nevent is marked as processed (equivalent to
    ##   |/notification/nevent/donequeued.json|).
    ##
    ##   NObj (|nevent_channel|) : The queued nevent's channel.
    ##   Required if |nevent_id| is specified.
    ##
    ## Empty response.
    my $urls = [];
    for my $u (@{$self->{app}->text_param_list ('url')}) {
      my $url = Web::URL->parse_string ($u);
      unless (defined $url and ($url->scheme eq 'https' or
                                ($url->scheme eq 'http' and $self->{config}->{is_test_script}))) { # XXX
        return $self->throw ({reason => 'Bad |url|'});
      }
      push @$urls, $url;
    }

    my $nevent_id = $self->{app}->bare_param ('nevent_id');
    my ($nevent_channel, $nevent_subscriber);
    my $nevent_done = {apploach_errors => []};
    return Promise->all ([
      $self->nobj ('nevent_channel'),
      $self->nobj ('nevent_subscriber'),
      $self->new_nobj_list ([\'apploach-push']),
    ])->then (sub {
      ($nevent_channel, $nevent_subscriber) = @{$_[0]};
      return [] if @$urls;
      my ($push) = @{$_[0]->[2]};
      return $self->get_hooks ($nevent_subscriber, [$push], {
        order_direction => 'ASC',
        offset => 0, limit => 100000, # XXX page iterator?
      });
    })->then (sub {
      for (@{$_[0]}) {
        next unless $_->{status} == 2; # enabled
        my $url = Web::URL->parse_string (Dongry::Type->parse ('text', $_->{url}));
        if (defined $url and ($url->scheme eq 'https' or
                              ($url->scheme eq 'http' and $self->{config}->{is_test_script}))) { # XXX
          push @$urls, $url;
        }
      }
      my $config = $self->{config};
      my $pub_key = [@{
        $config->{'push_application_server_key_public.'.$self->{app_id}} ||
        $config->{push_application_server_key_public}
      }];
      my $pvt_key = [@{
        $config->{'push_application_server_key_private.'.$self->{app_id}} ||
        $config->{push_application_server_key_private}
      }];
      $self->{app}->http->set_response_header
          ('content-type', 'application/json;charset=utf-8');
      $self->{app}->http->send_response_body_as_ref (\""); # send headers
      my @job;
      return ((promised_for {
        my $url = shift;
        my $options = {
          name => 'push: ' . $self->{app_id},
          method => 'POST',
          vapid_public_key => $pub_key,
          vapid_private_key => $pvt_key,
          headers => {
            ttl => 24*60*60, # XXX this should be configurable by app
          },
        };
        if (1) {
          $options->{url} = $url->stringify;
          push @job, {
            url => $url,
            options => $options,
          };
        } else {
          return $self->run_fetch_job ($self->{app}->http->server_state->data, {
            url => $url,
            options => $options,
          }, $self->db);
        }
      } $urls)->then (sub {
        my $now = time;
        my $expires = $now + 60*60*10; # XXX configurable
        return $self->insert_fetch_jobs
            (\@job,
             now => $now,
             expires => $expires);
      })->then (sub {
        return unless defined $nevent_id;
        return $self->done_queued_nevent
            ($nevent_subscriber, $nevent_channel, $nevent_id, $nevent_done);
      }));
    })->then (sub {
      my $data = {
      };
      $self->{app}->http->send_response_body_as_ref (\perl2json_bytes $data);
      $self->{app}->http->close_response_body;
    })->then (sub {
      return $self->expire_old_nevents;
    });
  }

  return $self->{app}->throw_error (404);
} # run_notification

sub run_alarm ($) {
  my $self = $_[0];

  ## An alarm has:
  ##
  ##   NObj (|scope|) : The alarm's scope.  An application-specific
  ##   value that defines the realm to which the alarm belongs.
  ##
  ##   NObj (|target|) : The alarm's target.  An application-specific
  ##   value that identifies the target about which the alarm
  ##   describes.
  ##
  ##   NObj (|type|) : The alarm's type.  An application-specific
  ##   value that identifies the kind of the alarm.  It is also used
  ##   to the verb of the log that is added when the alarm is started
  ##   or ended.
  ##
  ##   NObj (|level|) : The alarm's level.  An application-specific
  ##   value that identifies the severity or priority of the alarm.
  ##
  ##   |started| : Timestamp : The latest time the alarm has been
  ##   started.
  ##
  ##   |latest| : Timestamp : The latest time the alarm has been
  ##   confirmed.
  ##
  ##   |ended| : Timestamp : The latest time the alarm has been ended.
  ##   If it's never been ended, 0.
  ##
  ##   |data| : Object : The alarm's data.  An application-specific
  ##   set of values.
  ##
  ## An alarm is uniquly identified by a tuple of (application, scope,
  ## target, type).
  ##
  ## An alarm is in active at a time when its |started| is less than
  ## the time and either its |ended| is 0 or its |ended| is greater
  ## than the time.

  if (@{$self->{path}} == 1 and
      $self->{path}->[0] eq 'update.json') {
    ## /{app_id}/alarm/update.json - Update alarm statuses.
    ##
    ## Parameters.
    ##
    ##   NObj (|scope|) : The alarm's scope.
    ##
    ##   NObj (|operator|) : The operator of logs.
    ##
    ##   |timestamp| : Timestamp : The "current" time.
    ##
    ##   |alarm| : JSON object : An alarm's current status.  Zero or
    ##   more parameters can be specified.  An object can have the
    ##   following name/value pairs:
    ##
    ##     NObj (|target| with index) : The alarm's target.
    ##
    ##     NObj (|type|) : The alarm's type.
    ##
    ##     NObj (|level|) : The alarm's level.
    ##
    ##     |data| : Object : The alarm's data.
    ##
    ##   Notifications (|notification_|).  If specified, an nevent is
    ##   fired when at least one of alarms is started or ended.
    ##
    ## Empty response.
    ##
    ## Any existing alarm with same target and type within the
    ## application and scope is replaced by new one.  Any existing
    ## alarm with no updated alarm is marked as ended.
    ##
    ## When an alarm is changed to in-active or not-in-active, a log
    ## is inserted.
    my $alarms = $self->json_object_list_param ('alarm');
    my $time = 0+$self->{app}->bare_param ('timestamp');

    for (@$alarms) {
      $_->{target_nobj_key} //= '';
      $_->{target_index_nobj_key} //= 'apploach-null';
      $_->{type_nobj_key} //= '';
      $_->{level_nobj_key} //= '';
    }
    
    return Promise->all ([
      $self->new_nobj_list ([
        'scope',
        'operator',
        map {
          (\(''.$_->{target_nobj_key}),
           \(''.$_->{target_index_nobj_key}),
           \(''.$_->{type_nobj_key}),
           \(''.$_->{level_nobj_key}));
        } @$alarms
      ]),
    ])->then (sub {
      my ($scope, $operator, @nobjs) = @{$_[0]->[0]};
      my $k2no = {};
      for my $no (@nobjs) {
        return $self->throw ({reason => 'Bad nobj key |'.$no->nobj_key.'|'})
            if $no->is_error;
        $k2no->{$no->nobj_key} = $no;
      }
      return $self->throw ({reason => 'Bad NObj parameter |scope|'})
          if $scope->is_error;

      return $self->db->transaction->then (sub {
        my $tr = $_[0];

        my $current = {};
        my $logs = [];
        my $nevent_data = [];
        my $prev_timestamp = $time;
        return Promise->resolve->then (sub {
          my $offset = 0;
          return promised_until {
            return $tr->select ('alarm_status', {
              ($self->app_id_columns),
              ($scope->to_columns ('scope')),
            }, lock => 'update', fields => [
              'target_nobj_id', 'target_index_nobj_id',
              'type_nobj_id', 'level_nobj_id',
              'started', 'latest', 'ended',
            ], order => [
              'created', 'asc',
            ], limit => 100, offset => $offset)->then (sub {
              my @v = $_[0]->all->to_list;
              return 'done' unless @v;
              for (@v) {
                $current->{$_->{target_nobj_id}, $_->{type_nobj_id}} = $_;
              }
              $offset += @v;
              return not 'done' if @v == 100;
              return 'done';
            });
          };
        })->then (sub {
          my $new = [];
          my $new2 = [];
          my $has_started = 0;

          my $now = time;
          for my $alarm (@$alarms) {
            my $target_no = $k2no->{$alarm->{target_nobj_key}};
            my $target_index_no = $k2no->{$alarm->{target_index_nobj_key}};
            my $type_no = $k2no->{$alarm->{type_nobj_key}};
            my $level_no = $k2no->{$alarm->{level_nobj_key}};
            my $cur = delete $current->{$target_no->nobj_id, $type_no->nobj_id};
            $prev_timestamp = $cur->{latest}
                if defined $cur and $cur->{latest} < $prev_timestamp;

            if (not defined $cur) {
              my $data = ref $alarm->{data} eq 'HASH' ? $alarm->{data} : {};
              push @$new, {
                ($self->app_id_columns),
                ($scope->to_columns ('scope')),
                ($target_no->to_columns ('target')),
                ($target_index_no->to_columns ('target_index')),
                ($type_no->to_columns ('type')),
                ($level_no->to_columns ('level')),
                data => Dongry::Type->serialize ('json', $data),
                created => ($now += 0.001),
                started => $time,
                latest => $time,
                ended => 0,
              };
              $has_started = 1;
              push @$logs, [$target_no, $target_index_no, $type_no, {
                scope_nobj_key => $scope->nobj_key,
                level_nobj_key => $level_no->nobj_key,
                data => $data,
                timestamp => $time,
                started => $time,
                ended => 0,
              }];
            } elsif ($time < $cur->{started}) {
              #
            } elsif ($cur->{started} <= $time and $time <= $cur->{ended}) {
              if ($cur->{latest} <= $time) {
                push @$new, {
                  ($self->app_id_columns),
                  ($scope->to_columns ('scope')),
                  ($target_no->to_columns ('target')),
                  ($target_index_no->to_columns ('target_index')),
                  ($type_no->to_columns ('type')),
                  ($level_no->to_columns ('level')),
                  data => Dongry::Type->serialize ('json', ref $alarm->{data} eq 'HASH' ? $alarm->{data} : {}),
                  created => ($now += 0.001),
                  started => $cur->{started},
                  latest => $time,
                  ended => $cur->{ended},
                };
              }
            } elsif ($cur->{started} <= $time and not $cur->{ended}) {
              my $data = ref $alarm->{data} eq 'HASH' ? $alarm->{data} : {};
              push @$new, {
                ($self->app_id_columns),
                ($scope->to_columns ('scope')),
                ($target_no->to_columns ('target')),
                ($target_index_no->to_columns ('target_index')),
                ($type_no->to_columns ('type')),
                ($level_no->to_columns ('level')),
                data => Dongry::Type->serialize ('json', $data),
                created => ($now += 0.001),
                started => $cur->{started},
                latest => ($cur->{latest} < $time ? $time : $cur->{latest}),
                ended => $cur->{ended},
              };
            } else {
              my $data = ref $alarm->{data} eq 'HASH' ? $alarm->{data} : {};
              push @$new, {
                ($self->app_id_columns),
                ($scope->to_columns ('scope')),
                ($target_no->to_columns ('target')),
                ($target_index_no->to_columns ('target_index')),
                ($type_no->to_columns ('type')),
                ($level_no->to_columns ('level')),
                data => Dongry::Type->serialize ('json', $data),
                created => ($now += 0.001),
                started => $time,
                latest => $time,
                ended => 0,
              };
              $has_started = 1;
              push @$logs, [$target_no, $target_index_no, $type_no, {
                scope_nobj_key => $scope->nobj_key,
                level_nobj_key => $level_no->nobj_key,
                data => $data,
                started => $time,
                ended => 0,
                timestamp => $time,
              }];
            }
          } # $alarm

          my $removed = [];
          for (keys %$current) {
            my $cur = $current->{$_};
            $prev_timestamp = $cur->{latest}
                if $cur->{latest} < $prev_timestamp;
            if ($cur->{started} <= $time and
                (not $cur->{ended} or $time <= $cur->{ended})) {
              push @$new2, {
                ($self->app_id_columns),
                ($scope->to_columns ('scope')),
                target_nobj_id => $cur->{target_nobj_id},
                target_index_nobj_id => $cur->{target_index_nobj_id},
                type_nobj_id => $cur->{type_nobj_id},
                level_nobj_id => $cur->{level_nobj_id},
                data => '{}', #
                created => ($now += 0.001), #
                started => $time, #
                ended => $time,
                latest => $time, #
              };
              push @$removed, {
                target_nobj_id => $cur->{target_nobj_id},
                target_index_nobj_id => $cur->{target_index_nobj_id},
                type_nobj_id => $cur->{type_nobj_id},
                level_nobj_id => $cur->{level_nobj_id},
                started => $cur->{started},
              };
            }
          } # $current

          push @$nevent_data, {
            scope_nobj_key => $scope->nobj_key,
            has_in_active => (@$new ? 1 : 0),
            has_started => ($has_started ? 1 : 0),
            has_ended => (@$removed ? 1 : 0),
            prev_timestamp => ($time == $prev_timestamp ? 0 : $prev_timestamp),
            timestamp => $time,
          } if @$logs or @$removed;
          
          return Promise->all ([
            (@$new ? $tr->insert ('alarm_status', $new, duplicate => {
              level_nobj_id => $self->db->bare_sql_fragment ('values(`level_nobj_id`)'),
              data => $self->db->bare_sql_fragment ('values(`data`)'),
              started => $self->db->bare_sql_fragment ('values(`started`)'),
              latest => $self->db->bare_sql_fragment ('values(`latest`)'),
              ended => $self->db->bare_sql_fragment ('values(`ended`)'),
            }) : ()),
            (@$new2 ? $tr->insert ('alarm_status', $new2, duplicate => {
              ended => $self->db->bare_sql_fragment ('values(`ended`)'),
            }) : ()),
            $self->_nobj_ids_to_nobj ($tr, $removed, [
              'target', 'target_index', 'type', 'level',
            ])->then (sub {
              my $is = $_[0];
              for (@$is) {
                push @$logs, [$_->{target}, $_->{target_index}, $_->{type}, {
                  scope_nobj_key => $scope->nobj_key,
                  level_nobj_key => $_->{level}->nobj_key,
                  data => {},
                  timestamp => $time,
                  started => $_->{started},
                  ended => $time,
                }];
              }
            }),
          ]);
        })->then (sub {
          return promised_for {
            return $self->write_log ($tr, $operator, @{$_[0]});
          } $logs;
        })->then (sub {
          return $tr->commit;
        })->then (sub {
          return promised_for {
            my $data = $_[0];
            return $self->fire_nevent (
              'notification_',
              $data,
              timestamp => $data->{timestamp},
            );
          } $nevent_data;
        });
      })->then (sub {
        return $self->json ({});
      });
    });
  }
  
  if (@{$self->{path}} == 1 and
      $self->{path}->[0] eq 'list.json') {
    ## /{app_id}/alarm/list.json - List alarm statuses.
    ##
    ## Parameters.
    ##
    ##   NObj (|scope|) : The alarm's scope.  Zero or more parameters
    ##   can be specified.
    ##
    ## List response of alarms.
    my $page = Pager::this_page ($self, limit => 100, max_limit => 10000);
    return Promise->all ([
      $self->nobj_list_set (['scope']),
    ])->then (sub {
      my ($scopes) = @{$_[0]->[0]};
      $scopes = [grep { not $_->is_error } @$scopes];
      return [] unless @$scopes;

      my $where = {
        ($self->app_id_columns),
        'scope_nobj_id' => {-in => [map { $_->nobj_id } @$scopes]},
      };
      $where->{created} = $page->{value} if defined $page->{value};
      
      return $self->db->select ('alarm_status', $where, fields => [
        'target_nobj_id', 'target_index_nobj_id', 'scope_nobj_id',
        'type_nobj_id', 'level_nobj_id',
        'data', 'created', 'started', 'ended', 'latest',
      ], source_name => 'master',
        offset => $page->{offset}, limit => $page->{limit},
        order => ['created', $page->{order_direction}],
      )->then (sub {
        return $_[0]->all->to_a;
      });
    })->then (sub {
      my $items = $_[0];
      for my $item (@$items) {
        $item->{data} = Dongry::Type->parse ('json', $item->{data});
      }
      return $self->replace_nobj_ids ($items, [
        'target', 'target_index', 'type', 'level', 'scope',
      ])->then (sub {
        my $next_page = Pager::next_page $page, $items, 'created';
        return $self->json ({items => $items, %$next_page});
      });
    });
  }
  
  return $self->{app}->throw_error (404);
} # run_alarm

sub run_message ($) {
  my $self = $_[0];

  if (@{$self->{path}} == 1 and
      $self->{path}->[0] eq 'callback.json') {
    ## /{app_id}/message/callback.json - Enqueue Web hook requests.
    ##
    ## Parameters.
    ##
    ##   |channel| : String    : The messaging channel.  Required.
    ##   |body| : String       : Received data, Base64 encoded.
    ##
    ## Returns nothing.
    ##
    my $ch = $self->{app}->text_param ('channel') // '';
    my $url = Web::URL->parse_string (qq<https://apploach.internal/ch/$ch>);
    my $job = {
      url => $url,
      options => {
        name => $ch,
        is_callback => 1,
        callback_channel => $ch,
        callback_body => $self->{app}->bare_param ('body') // '',
      },
    };

    my $now = time;
    my $expires = $now + 60*60*10;
    return $self->insert_fetch_jobs
        ([$job],
         now => $now,
         after => $now,
         expires => $expires)->then (sub {
      return $self->json ({});
    });
  } # callback

  if (@{$self->{path}} == 1 and
      $self->{path}->[0] eq 'send.json') {
    ## /{app_id}/message/send.json - Set a message.
    ##
    ## Parameters.
    ##
    ##   NObj (|station|)      : The messaging station.  Required.
    ##   |to| : String         : An application-specific destination key.
    ##                           Required unless |broadcast| is true.
    ##   |broadcast| : Boolean : If true, all destinations are selected.
    ##   |from_name| : String  : A source name in protocol specific format.
    ##                           Defaulted to the empty string.
    ##   |body| : String       : A text message.  Required.
    ##   NObj (|operator|)     : The operator.  Required.
    ##   NObj (|verb|)         : The verb for the log.  Required.
    ##   NObj (|status_verb|)  : The verb for the log of the status changes.
    ##                           Required.
    ##
    ## Returns,
    ##
    ##   |request_set_id| : ID : The message submission's request set ID.
    ##
    return Promise->all ([
      $self->nobj ('station'),
      $self->new_nobj_list (['operator', 'verb', 'status_verb']),
    ])->then (sub {
      my ($station) = @{$_[0]};
      return $self->throw ({reason => 'Bad |station_nobj_key|'})
          if $station->is_error;
      my $operator = $_[0]->[1]->[0];
      return $self->throw ({reason => 'Bad NObj parameter |operator|'})
          if $operator->is_error;
      my $verb = $_[0]->[1]->[1];
      return $self->throw ({reason => 'Bad NObj parameter |verb|'})
          if $verb->is_error;
      my $verb2 = $_[0]->[1]->[2];
      return $self->throw ({reason => 'Bad NObj parameter |status_verb|'})
          if $verb2->is_error;

      my $now = time;
      return $self->db->select ('message_routes', {
        ($self->app_id_columns),
        ($station->to_columns ('station')),
        expires => {'>', $now},
      }, fields => ['data', 'expires'], source_name => 'master')->then (sub {
        my $row = $_[0]->first;
        my $data = Dongry::Type->parse ('json', $row->{data});

        my $dests = [];
        if ($self->{app}->bare_param ('broadcast')) {
          if (defined $self->{app}->text_param ('to')) {
            return $self->throw ({reason => 'Both |to| and |broacast| are specified'});
          }

          # XXX exclusions
          $dests = [values %{$data->{table}}];
        } else {
          my $dest = {};
          if (defined $row) {
            $dest = $data->{table}->{$self->{app}->text_param ('to') // ''} // {};
          }
          return $self->throw ({reason => 'Bad |to|'})
              unless defined $dest->{addr};
          push @$dests, $dest;
        }

        if ($data->{channel} eq 'vonage') { ## Vonage's Messages API for SMS
          my $key = $self->{config}->{'message_api_key.'.$data->{channel}.'.'.$self->{app_id}} //
              $self->{config}->{'message_api_key.'.$data->{channel}};
          my $secret = $self->{config}->{'message_api_secret.'.$data->{channel}.'.'.$self->{app_id}} //
              $self->{config}->{'message_api_secret.'.$data->{channel}};
          my $api_u = $self->{config}->{'message_api_url.'.$data->{channel}.'.'.$self->{app_id}} //
              $self->{config}->{'message_api_url.'.$data->{channel}};
          return $self->throw ({reason => 'Bad destination type'})
              unless defined $api_u and defined $key and defined $secret;
          my $api_url = Web::URL->parse_string ($api_u);
          return $self->throw ({reason => 'Bad destination type'})
              unless defined $api_url and $api_url->is_http_s;

          ## <https://developer.vonage.com/en/messaging/sms/guides/custom-sender-id>
          my $from = $self->{app}->text_param ('from_name') // '';
          my $body = $self->{app}->text_param ('body') // '';
          $body =~ s/\x0D\x0A/\x0A/g;
          $body =~ s/\x0D/\x0A/g;

          my $size = length $body;
          $size += $body =~ /[^\x{0000}-\x{FFFF}]/g;
          $size = ceil ($size / 70);
          
          my $now = time;
          my $expires = $row->{expires};

          my $request_set_id;
          return $self->db->uuid_short (1)->then (sub {
            my $ids = $_[0];
            $request_set_id = $ids->[0];
            return $self->db->insert ('request_set', [{
              ($self->app_id_columns),
              ($station->to_columns ('station')),
              request_set_id => $ids->[0],
              data => Dongry::Type->serialize ('json', {
                channel => $data->{channel},
              }),
              created => $now,
              updated => $now,
              status_2_count => 0, status_3_count => 0, status_4_count => 0,
              status_5_count => 0, status_6_count => 0, status_7_count => 0,
              status_8_count => 0, status_9_count => 0,
              size_for_cost => $size,
            }]);
          })->then (sub {
            return $self->write_log ($self->db, $operator, $station, $station, $verb, {
              timestamp => $now,
              expires => $expires,
              channel => $data->{channel},
              request_set_id => '' . $request_set_id,
              size_for_cost => $size,
              dest_count => 0+@$dests,
            });
          })->then (sub {
            $self->json ({
              request_set_id => '' . $request_set_id,
            });
          })->then (sub {
            return promised_for {
              my $dest = shift;

              ## <https://developer.vonage.com/en/api/messages-olympus>
              my $options = {
                name => 'message: ' . $self->{app_id} . ': ' . $data->{channel} . ': ' . $request_set_id,
                url => $api_url,
                method => 'POST',
                headers => {'content-type' => 'application/json'},
                basic_auth => [$key, $secret],
                json => {
                  to => $dest->{addr},
                  from => $from,
                  text => $body,
                  channel => 'sms',
                  #client_ref =>
                  message_type => 'text',
                },
                ($verb2->to_columns ('status_verb')),
              };

              return $self->db->uuid_short (2)->then (sub {
                my $ids = $_[0];
                $options->{json}->{client_ref} = 'r' . $ids->[0];
                $options->{request_id} = '' . $ids->[0];
                return $self->db->insert ('request_status', [{
                  ($self->app_id_columns),
                  request_set_id => $request_set_id,
                  request_id => $ids->[0],
                  request_data => Dongry::Type->serialize ('json', {
                    job_id => '' . $ids->[1],
                  }),
                  response_log => Dongry::Type->serialize ('json', {
                    items => [],
                  }),
                  callback_log => Dongry::Type->serialize ('json', {
                    items => [],
                  }),
                  status => 2, # waiting
                  created => $now,
                  updated => $now,
                  expires => $expires,
                }])->then (sub {
                  return $self->db->insert ('fetch_job', [{
                    ($self->app_id_columns),
                    job_id => $ids->[1],
                    origin => Dongry::Type->serialize ('text', $api_url->get_origin->to_ascii), # must be an HTTP(S) URL
                    options => Dongry::Type->serialize ('json', $options),
                    running_since => 0,
                    run_after => 0,
                    inserted => $now,
                    expires => $expires,
                  }]);
                });
              });
            } $dests;
          });
        } else { # unknown channel
          return $self->throw ({reason => 'Bad channel'});
        }
      });
    });
  } # send.json
  
  if (@{$self->{path}} == 1 and
      $self->{path}->[0] eq 'setroutes.json') {
    ## /{app_id}/message/setroutes.json - Set message routing table.
    ##
    ## Parameters.
    ##
    ##   NObj (|station|)      : The messaging station.  Required.
    ##   |channel| : String    : The messaging channel.  Required.
    ##   |table| : Object      : The routing table.  Required.
    ##     /name/              : An application-specific destination key.
    ##     /value/ : Object
    ##       |addr| : String   : The messaging channel-specific destination
    ##                           address.  Required.
    ##   |expires| : Timestamp : The expiration time.  Defaulted to 7 days
    ##                           from now.
    ##   NObj (|operator|)     : The operator.  Required.
    ##   NObj (|verb|)         : The verb for the log.  Required.
    ##
    ## Returns,
    ##
    ##   |expires| : Timestamp : The expiration time.
    ##
    return Promise->all ([
      $self->new_nobj_list (['station', 'operator', 'verb']),
    ])->then (sub {
      my $station = $_[0]->[0]->[0];
      return $self->throw ({reason => 'Bad NObj parameter |station|'})
          if $station->is_error;
      my $operator = $_[0]->[0]->[1];
      return $self->throw ({reason => 'Bad NObj parameter |operator|'})
          if $operator->is_error;
      my $verb = $_[0]->[0]->[2];
      return $self->throw ({reason => 'Bad NObj parameter |verb|'})
          if $verb->is_error;
      my $table = $self->json_object_param ('table');
      return $self->throw ({reason => 'Bad parameter |table|'})
          unless defined $table and ref $table eq 'HASH';
      for (values %$table) {
        return $self->throw ({reason => 'Bad parameter |table|'})
            unless defined $_ and ref $_ eq 'HASH';
      }

      my $channel = $self->{app}->bare_param ('channel') // '';
      my $api_u = $self->{config}->{'message_api_url.'.$channel.'.'.$self->{app_id}} //
          $self->{config}->{'message_api_url.'.$channel};
      return $self->throw ({reason => 'Bad parameter |channel|'})
          unless defined $api_u;
      
      my $now = time;
      my $expires = 0+($self->{app}->bare_param ('expires') || 0);
      $expires = $now + 7*24*60*60 if $expires < $now + 7*24*60*60;

      return $self->db->insert ('message_routes', [{
        ($self->app_id_columns),
        ($station->to_columns ('station')),
        data => Dongry::Type->serialize ('json', {
          channel => $channel,
          table => $table,
        }),
        expires => $expires,
        created => $now,
        updated => $now,
      }], duplicate => {
        data => $self->db->bare_sql_fragment ('VALUES(`data`)'),
        updated => $self->db->bare_sql_fragment ('VALUES(`updated`)'),
        expires => $self->db->bare_sql_fragment ('VALUES(`expires`)'),
      })->then (sub {
        return $self->write_log ($self->db, $operator, $station, $station, $verb, {
          timestamp => $now,
          expires => $expires,
          channel => $channel,
          table_summary => {map {
            ($_ => {has_addr => defined $table->{$_}->{addr}});
          } keys %$table},
        });
      })->then (sub {
        return $self->json ({
          expires => $expires,
        });
      });
    });
  } # setroutes.json
  
  if (@{$self->{path}} == 1 and
      $self->{path}->[0] eq 'status.json') {
    ## /{app_id}/message/status.json - Set message submission's request set's status.
    ##
    ## Parameters.
    ##
    ##   NObj (|station|) :      The request's station.
    ##   |request_set_id| : ID : The request set ID.
    ##                           Either or both of NObj (|station|) and
    ##                           |request_set_id| is required.
    ##   Pages.
    ##
    ## List response of:
    ##
    ##   NObj (|station|) :      The request's station.
    ##   |request_set_id| : ID : The request set ID.
    ##   |status_2_count| : Integer : The number of requests whose status
    ##                           is 2 (waiting).
    ##   |status_4_count| : Integer : The number of requests whose status
    ##                           is 4 (fetched).
    ##   |status_5_count| : Integer : The number of requests whose status
    ##                           is 5 (failed).
    ##   |status_6_count| : Integer : The number of requests whose status
    ##                           is 6 (callbacked, success).
    ##   |status_7_count| : Integer : The number of requests whose status
    ##                           is 7 (callbacked, failure).
    ##   |size_for_cost| : Integer : The size of the message for the cost
    ##                           calculations.
    ##
    my $page = Pager::this_page ($self, limit => 100, max_limit => 10000);
    return Promise->all ([
      $self->nobj ('station'),
    ])->then (sub {
      my ($station) = @{$_[0]};
      my $where = {
        ($self->app_id_columns),
      };
      if (not $station->missing) {
        return $self->throw ({reason => 'Bad |station_nobj_key|'})
            if $station->is_error;
        $where->{station_nobj_id} = $station->nobj_id;
      }
      my $set_id = $self->{app}->bare_param ('request_set_id');
      return $self->throw ({reason => 'Bad |request_set_id|'})
          if not defined $set_id and $station->missing;
      $where->{request_set_id} = $set_id if defined $set_id;
      $where->{created} = $page->{value} if defined $page->{value};
      return $self->db->select ('request_set', $where, fields => [
        'updated', 'status_2_count', 'status_3_count', 'status_4_count',
        'status_5_count', 'status_6_count', 'status_7_count', 'status_8_count',
        'status_9_count', 'size_for_cost',
        'station_nobj_id', 'created', 'request_set_id',
      ], source_name => 'master',
      offset => $page->{offset}, limit => $page->{limit},
      order => ['created', $page->{order_direction}])->then (sub {
        my $items = $_[0]->all->to_a;
        return $self->replace_nobj_ids ($items, ['station'])->then (sub {
          my $next_page = Pager::next_page $page, $items, 'created';
          for (@$items) {
            $_->{request_set_id} .= '';
          }
          return $self->json ({items => $items, %$next_page});
        });
      });
    });
  } # status.json
  
  return $self->{app}->throw_error (404);
} # run_message

sub insert_fetch_jobs ($$;%) {
  my ($self, $jobs, %args) = @_;
  my $now = $args{now} // die;
  my $after = $args{after} // $now;
  my $expires = $args{expires} // die;

  my @job = @$jobs;
  return Promise->resolve->then (sub {
    return promised_until {
      return 'done' if not @job;
      my @jj = splice @job, 0, 100, ();
      return $self->db->uuid_short (0+@jj)->then (sub {
        my $ids = shift;
        return $self->db->insert ('fetch_job', [map {
          my $job = $_;
          $job->{job_id} = '' . shift @$ids;
          +{
            ($self->app_id_columns),
            job_id => $job->{job_id},
            origin => Dongry::Type->serialize ('text', $job->{url}->get_origin->to_ascii), # must be an HTTP(S) URL
            options => Dongry::Type->serialize ('json', $job->{options}),
            running_since => 0,
            run_after => $after,
            inserted => $now,
            expires => $expires,
          };
        } @jj]);
      })->then (sub {
        return not 'done';
      });
    };
  })->then (sub {
    return $jobs;
  });
} # insert_fetch_jobs

sub run_fetch_job ($$$$) {
  my ($class, $obj, $job, $db) = @_;
  if ($job->{options}->{is_callback}) {
    return $class->run_fetch_callback_job ($obj, $job, $db);
  }

  my $now = time;
  my $ret = {};

  my $url = $job->{url} || Web::URL->parse_string ($job->{options}->{url});
  my $client = $obj->{clients}->{$url->get_origin->to_ascii}
      ||= Web::Transport::BasicClient->new_from_url ($url);

  my $headers = {%{$job->{options}->{headers} or {}}};
  if (defined $job->{options}->{vapid_private_key}) {
    $headers->{authorization} = _vapid_authorization
        ($job->{options}->{vapid_public_key},
         $job->{options}->{vapid_private_key}, $url);
  }
  
  return $client->request (
    url => $url,
    method => $job->{options}->{method},
    headers => $headers,
    basic_auth => $job->{options}->{basic_auth}, # or undef
    (defined $job->{options}->{json} ? (
      body => (perl2json_bytes $job->{options}->{json}),
    ) : ()),
  )->then (sub {
    my $res = $_[0];
    my $result = {status => $res->status};
    for (qw(content-type)) {
      $result->{headers}->{$_} = $res->header ($_);
      delete $result->{headers}->{$_} if not defined $result->{headers}->{$_};
    }
    if (($result->{headers}->{'content-type'} // '') =~ m{^application/(?:[0-9a-zA-Z_.-]+\+|)json(?:;|$)}) {
      $result->{body_json} = json_bytes2perl $res->body_bytes;
    }
    if (200 <= $res->status and $res->status <= 205) {
      ## Vonage returns 202.
      #$n++;
    } else {
      #push @{$nevent_done->{apploach_errors}},
      #          {request => {url => $url->stringify,
      #                       method => 'POST'},
      #           response => {status => $res->status}};
      unless ($res->status == 403 or $res->status == 410) {
        $class->error_log ($obj->{config}, (not 'important'),
                           $job->{options}->{name} . ': ' . $url->stringify . ' ' . $res);
      }
      #$m++;
      $result->{error} = 1;
      $result->{need_retry} = 1 if int ($res->status / 100) == 5;
    }
    return $result;
  }, sub {
    my $error = $_[0];
    #push @{$nevent_done->{apploach_errors}},
    #          {request => {url => $url->stringify,
    #                       method => 'POST'},
    #           response => {error_message => '' . $error}};
    $class->error_log ($obj->{config}, (not 'important'),
                       $job->{options}->{name} . ': ' . $url->stringify . ' ' . $error);
    #$m++;
    return {error => 1, error_message => '' . $error, need_retry => 1};
  })->then (sub {
    if (defined $job->{options}->{request_id}) {
      my $result = $_[0];
      $result->{time} = $now;
      return $db->transaction->then (sub {
        my $tr = $_[0];
        return $tr->select ('request_status', {
          app_id => $job->{app_id},
          request_id => 0+$job->{options}->{request_id},
        }, lock => 'update', fields => [
          'request_id', 'request_set_id', 'status', 'response_log',
        ])->then (sub {
          my $req = $_[0]->first;
          die "Bad |request_id|: |$job->{options}->{request_id}|"
              unless defined $req;
          my $log = Dongry::Type->parse ('json', $req->{response_log});
          push @{$log->{items} ||= []}, $result;
          my $new_status = $req->{status};
          if ($new_status == 2) { # waiting
            if ($result->{need_retry}) {
              if (@{$log->{items}} < 3) {
                $ret->{retry_after} = 60;
              } else {
                $new_status = 5; # failed
              }
            } else {
              if ($result->{error}) {
                $new_status = 5; # failed
              } else {
                $new_status = 4; # fetched
              }
            }
          }
          return $tr->update ('request_status', {
            status => $new_status,
            response_log => Dongry::Type->serialize ('json', $log),
            updated => $now,
          }, where => {
            app_id => $job->{app_id},
            request_id => $req->{request_id},
          })->then (sub {
            return $class->update_request_set_stats
                ($tr, $job->{app_id}, $req->{request_set_id}, $now);
          });
        })->then (sub {
          return $tr->commit;
        });
      });
    }
  })->catch (sub {
    my $error = $_[0];
    $class->error_log ($obj->{config}, ('important'),
                       $job->{options}->{name} . ': ' . $url->stringify . ' ' . $error);
  })->then (sub {
    return $ret;
  }); # can't reject
} # run_fetch_job

sub run_fetch_callback_job ($$$$) {
  my ($class, $obj, $job, $db) = @_;
  my $now = time;
  my $ret = {};

  return Promise->resolve->then (sub {
    my $ch = $job->{options}->{callback_channel};
    if ($ch eq 'vonage') {
      my $body = decode_web_base64 $job->{options}->{callback_body};
      my $json = json_bytes2perl $body;
      if (defined $json and ref $json eq 'HASH' and
          defined $json->{client_ref} and
          $json->{client_ref} =~ m{^r[0-9]+$}) {
        my $request_id = $json->{client_ref};
        $request_id =~ s/^r//;
        return $db->transaction->then (sub {
          my $tr = $_[0];
          return $tr->select ('request_status', {
            app_id => $job->{app_id},
            request_id => 0+$request_id,
          }, lock => 'update', fields => [
            'request_id', 'request_set_id', 'status', 'callback_log',
          ])->then (sub {
            my $req = $_[0]->first;
            die "Bad vonage callback" unless defined $req;
            my $log = Dongry::Type->parse ('json', $req->{callback_log});
            push @{$log->{items} ||= []}, {body => $json};
            my $new_status = $req->{status};
            if ($new_status == 4) { # fetched
              if (defined $json->{status} and
                  ($json->{status} eq 'submitted' or
                   $json->{status} eq 'delivered')) {
                $new_status = 6; # callbacked, success
              } else {
                $new_status = 7; # callbacked, failure
              }
            } # else, something wrong
            return $tr->update ('request_status', {
              status => $new_status,
              callback_log => Dongry::Type->serialize ('json', $log),
              updated => $now,
            }, where => {
              app_id => $job->{app_id},
              request_id => $req->{request_id},
            })->then (sub {
              return $class->update_request_set_stats
                  ($tr, $job->{app_id}, $req->{request_set_id}, $now);
            });
          })->then (sub {
            return $tr->commit;
          });
        });
      } else {
        die "Bad vonage callback";
      }
    } else {
      die "Bad callback channel |$ch|";
    }
  })->catch (sub {
    my $error = $_[0];
    $class->error_log ($obj->{config}, ('important'),
                       $job->{options}->{name} . ': ' . $error);
  })->then (sub {
    return $ret;
  }); # can't reject
} # run_fetch_callback_job

sub update_request_set_stats ($$$$$) {
  my ($class, $db, $app_id, $request_set_id, $now) = @_;
  return $db->execute (q{
    update `request_set` set
    status_2_count = (select count(*) from request_status where app_id = :app_id and request_set_id = :request_set_id and status = 2),
    status_3_count = (select count(*) from request_status where app_id = :app_id and request_set_id = :request_set_id and status = 3),
    status_4_count = (select count(*) from request_status where app_id = :app_id and request_set_id = :request_set_id and status = 4),
    status_5_count = (select count(*) from request_status where app_id = :app_id and request_set_id = :request_set_id and status = 5),
    status_6_count = (select count(*) from request_status where app_id = :app_id and request_set_id = :request_set_id and status = 6),
    status_7_count = (select count(*) from request_status where app_id = :app_id and request_set_id = :request_set_id and status = 7),
    status_8_count = (select count(*) from request_status where app_id = :app_id and request_set_id = :request_set_id and status = 8),
    status_9_count = (select count(*) from request_status where app_id = :app_id and request_set_id = :request_set_id and status = 9),
    updated = :updated
    where `app_id` = :app_id and request_set_id = :request_set_id
  }, {
    app_id => $app_id,
    request_set_id => $request_set_id,
    updated => $now,
  });
} # update_request_set_stats

sub run_fetch ($) {
  my $self = $_[0];

  if (@{$self->{path}} == 1 and
      $self->{path}->[0] eq 'enqueue.json') {
    ## /{app_id}/fetch/enqueue.json - Enqueue a fetch job.
    ##
    ## Parameters.
    ##
    ##   |options| : Object : The request's options.  Following
    ##   name/value pairs:
    ##
    ##     |url| : String : The request URL.  It must be an HTTP(S) URL.
    ##
    ##     |method| : String : The request method.  Either |GET| or
    ##     |POST|.  Defaulted to |GET|.
    ##
    ##     |params| : Object : The request's parameters.  Defaulted to
    ##     none.
    ##
    ##   |after| : Timestamp : The time after that the fetch can be
    ##   done.  Defaulted to now.
    ##
    ## Response.
    ##
    ##   |job_id| : ID : The fetch job's ID.
    my $options = $self->json_object_param ('options');
    
    my $url = Web::URL->parse_string ($options->{url});
    return $self->throw ({reason => 'Bad |url|'})
        unless defined $url and $url->is_http_s;

    my $job = {
      url => $url,
      options => {
        url => $url,
        method => $options->{method} // 'GET',
      },
    };
    return $self->throw ({reason => 'Bad |method|'})
        unless $job->{options}->{method} eq 'GET' or
               $job->{options}->{method} eq 'POST';

    my $now = time;
    my $after = 0+($self->{app}->bare_param ('after') || $now);
    my $expires = $after + 60*60*10; # XXX configurable
    return $self->insert_fetch_jobs
        ([$job],
         now => $now,
         after => $after,
         expires => $expires)->then (sub {
      return $self->json ({job_id => $job->{job_id}});
    });
  } elsif (@{$self->{path}} == 1 and
           $self->{path}->[0] eq 'cancel.json') {
    ## /{app_id}/fetch/cancel.json - Cancel a fetch job.
    ##
    ## Parameters.
    ##
    ##   |job_id| : ID : The job's ID.
    ##
    ## Response.
    ##
    ##   |running_since| : Timestamp? : The timestamp from which the
    ##   fetch job has started, if there is any fetch job.  Set to
    ##   zero if it has never executed.  Set to |null| if there is no
    ##   fetch job (either the |job_id| is invalid or the job has been
    ##   completed).
    my $job_id = $self->{app}->bare_param ('job_id') // '';

    return $self->db->transaction->then (sub {
      my $tr = $_[0];
      return $tr->select ('fetch_job', {
        ($self->app_id_columns),
        job_id => $job_id,
      }, lock => 'update', fields => ['running_since'], limit => 1)->then (sub {
        my $v = $_[0]->first;
        if (defined $v) {
          return $tr->delete ('fetch_job', {
            ($self->app_id_columns),
            job_id => $job_id,
          })->then (sub {
            return {running_since => $v->{running_since}};
          });
        } else {
          return {};
        }
      })->then (sub {
        my $r = $_[0];
        return $tr->commit->then (sub { return $r })
            if keys %$r;
        return $tr->rollback->then (sub { return $r });
      })->then (sub {
        return $self->json ($_[0]);
      });
    });
  }

  return $self->{app}->throw_error (404);
} # run_fetch

## Notifications (/prefix/) parameters.
##
##   NObj (|/prefix/topic|) : The nevent's topic.  Required when the
##   notification feature is used.
##
##   NObj (|/prefix/topic_fallback|) : The fallback topics.  Zero or
##   more parameters can be specified.
##
##   |/prefix/topic_fallback_nobj_key_template| : String : The
##   template to generate fallback topics.  Zero or more parameters
##   can be specified.  If any applicable topic subscription for NObj
##   (|/prefix/topic|) and NObj (|/prefix/topic_fallback|) remains
##   unresolved with the status of 4 (inherit), the topic chain is
##   further extended with the NObjs whose keys are replacements of
##   the templates where /{subscriber}/ is replaced with the topic
##   subscription's subscriber's NObj key.  If there is an "inherit"
##   topic subscription for the |apploach-any-channel| special
##   channel, any channel topic subscription (without explicit
##   overridden topic subscription) is applied.  Otherwise, only
##   explicitly "inherit"ed topic subscriptions are applied.
##
##   NObj (|/prefix/excluded_subscriber|) : The subscribers that
##   should be excluded to distribution of the nevent, even when there
##   are topic subscriotions whose subscriber are them.  Zero or more
##   parameters can be specified.  No exclusion by default.
##
##   |/prefix/nevent_key| : Key : The nevent's key.  If omitted, a new
##   random string is assigned.
##
##   |/prefix/replace| : Boolean : If false and there is another
##   nevent with same key, the new nevent is discarded.  If true and
##   there is another nevent with same key, the new event replaces the
##   old one.
##
## When an nevent is fired, applicable topic subscriptions are looked
## up by their topics.  First, the topic subscription whose topic is
## equal to the NObj (|/prefix/topic|) is searched.  If not found,
## NObj (|/prefix/topic_fallback|) are searched in order.  Any first
## matched topic subscription for each subscriber is used to determine
## who and whether the nevent is routed.
sub fire_nevent ($$$;%) {
  my ($self, $prefix, $data, %args) = @_;
  return Promise->resolve if length $prefix and
      not defined $self->{app}->bare_param ($prefix.'topic_nobj_key');
  my $nevent_id;
  my $now = time;
  my $timestamp = 0+($args{timestamp} || $now);
  my $expires = 0+($args{expires} || ($now + 30*24*60*60));
  my $m = 0;
  return Promise->all ([
    $self->new_nobj_list ([$prefix.'topic', \'apploach-any-channel']),
    $self->nobj_list_set ([$prefix.'topic_fallback', $prefix.'excluded_subscriber']),
    $self->ids (1),
  ])->then (sub {
    my ($topic, $any_channel) = @{$_[0]->[0]};
    my ($topic_fallbacks, $excluded_subscribers) = @{$_[0]->[1]};
    $nevent_id = $_[0]->[2]->[0];
    my $nevent_key = $self->{app}->bare_param ($prefix.'nevent_key')
                   // ('id-' . $nevent_id);
    my $replace = $self->{app}->bare_param ($prefix.'replace');
    
    my $done_subscribers = {};
    my $undecided_subscribers = {};

    my $excluded_ids = [map {
      $_->is_error ? () : ($_->nobj_id);
    } @$excluded_subscribers];

    my $write_for_topic = sub {
      my $current_topic = shift;
      return if $current_topic->is_error;
      my $ch_ids = shift; # or undef

        my $n = 0;
        my $ref;
        return promised_until {
          return 'done' if $n++ > 1000;
          my $where = {
            ($self->app_id_columns),
            ($current_topic->to_columns ('topic')),
          };
          $where->{updated} = {'>', $ref} if defined $ref;
          $where->{channel_nobj_id} = {-in => $ch_ids} if defined $ch_ids;
          $where->{subscriber_nobj_id} = {-not_in => $excluded_ids}
              if @$excluded_ids;
          return $self->db->select ('topic_subscription', $where, fields => [
            'subscriber_nobj_id', 'channel_nobj_id',
            'status', 'data', 'updated',
          ], source_name => 'master', limit => 10, order => ['updated', 'asc'])->then (sub {
            my $all = $_[0]->all;

            return 'done' unless @$all;
            return ((promised_for {
              my $v = $_[0];

              if ($done_subscribers->{$v->{subscriber_nobj_id}, $v->{channel_nobj_id}}) {
                return;
              } elsif ($v->{status} == 2) { # enabled
                $done_subscribers->{$v->{subscriber_nobj_id}, $v->{channel_nobj_id}} = 1;
                #
              } elsif ($v->{status} == 3) { # disabled
                $done_subscribers->{$v->{subscriber_nobj_id}, $v->{channel_nobj_id}} = 1;
                return;
              } elsif ($v->{status} == 4) { # inherit
                $undecided_subscribers->{$v->{subscriber_nobj_id}}->{$v->{channel_nobj_id}} = 1;
                return;
              } else {
                return;
              }

              $m++;
              return $self->db->insert ('nevent', [{
                ($self->app_id_columns),
                ($topic->to_columns ('topic')),
                subscriber_nobj_id => $v->{subscriber_nobj_id},
                nevent_id => $nevent_id,
                unique_nevent_key => sha1_hex ($nevent_key),
                data => Dongry::Type->serialize ('json', $data),
                timestamp => $timestamp,
                expires => $expires,
              }], duplicate => ($replace ? 'replace' : 'ignore'))->then (sub {
                my $w = $_[0];
                unless ($replace) {
                  return $self->db->select ('nevent', {
                    ($self->app_id_columns),
                    nevent_id => $nevent_id,
                  }, fields => ['timestamp'], source_name => 'master')->then (sub {
                    return $_[0]->first ? 1 : 0;
                  });
                }
                return 1;
              })->then (sub {
                return unless $_[0];

                return $self->db->insert ('nevent_queue', [{
                  ($self->app_id_columns),
                  subscriber_nobj_id => $v->{subscriber_nobj_id},
                  channel_nobj_id => $v->{channel_nobj_id},
                  nevent_id => $nevent_id,
                  topic_subscription_data => $v->{data},
                  result_done => 0,
                  result_data => '{}',
                  locked => 0,
                  timestamp => $timestamp,
                  expires => $expires,
                }], duplicate => ($replace ? 'replace' : 'ignore'));
              });
            } $all)->then (sub {
              $ref = $all->[-1]->{updated};
              return not 'done';
            }));
          });
        }; # promised_until
      }; # $write_for_topic
      
      return ((promised_for {
        return $write_for_topic->($_[0], undef);
      } [$topic, @$topic_fallbacks])->then (sub {
        my $templates = $self->{app}->bare_param_list
            ($prefix.'topic_fallback_nobj_key_template');
        return unless @$templates;
        return unless keys %$undecided_subscribers;
        return $self->_nobj_list_by_ids ($self->db, [keys %$undecided_subscribers])->then (sub {
          my $sub_map = $_[0];
          return promised_for {
            my $sub_id = $_[0];
            my $sub_key = $sub_map->{$sub_id}->nobj_key;
            my $ch_ids = $undecided_subscribers->{$sub_id}->{$any_channel->nobj_id} ? undef : [grep {
              not $done_subscribers->{$sub_id, $_};
            } keys %{$undecided_subscribers->{$sub_id}}];
            return if defined $ch_ids and not @$ch_ids;
            my $keys = [map {
              my $v = $_;
              $v =~ s/\{subscriber\}/$sub_key/g;
              $v;
            } @$templates];
            return $self->nobj_list_by_values ($keys)->then (sub {
              return promised_for {
                return $write_for_topic->($_[0], $ch_ids);
              } $_[0];
            });
          } [keys %$undecided_subscribers];
        });
      }));
    })->then (sub {
      return {
        nevent_id => '' . $nevent_id,
        timestamp => $timestamp,
        expires => $expires,
        queued_count => $m,
      };
    });
} # fire_nevent

sub expire_old_nevents ($) {
  my $self = $_[0];
  my $now = time;
  return Promise->all ([
    $self->db->delete ('nevent', {
      expires => {'<=', $now},
    }, source_name => 'master'),
    $self->db->delete ('nevent_queue', {
      expires => {'<=', $now},
    }, source_name => 'master'),
    $self->db->delete ('hook', {
      expires => {'<=', $now},
    }, source_name => 'master'),
  ]);
} # expire_old_nevents

sub done_queued_nevent ($$$$$) {
  my ($self, $subscriber, $channel, $nevent_id, $data) = @_;
  return if $subscriber->is_error or $channel->is_error;
  return unless defined $nevent_id and length $nevent_id;
  return $self->db->update ('nevent_queue', {
    result_done => 1,
    result_data => Dongry::Type->serialize ('json', $data),
  }, where => {
    ($self->app_id_columns),
    ($subscriber->to_columns ('subscriber')),
    ($channel->to_columns ('channel')),
    nevent_id => $nevent_id,
  }, source_name => 'master');
} # done_queued_nevent

sub get_hooks ($$$$) {
  my ($self, $subscriber, $types, $page) = @_;

  my $has_types = 0+@$types;
  $types = [grep { not $_->is_error } @$types];

  return [] if $subscriber->is_error;
  return [] if $has_types and not @$types;

  my $where = {
    ($self->app_id_columns),
    ($subscriber->to_columns ('subscriber')),
    expires => {'>', time},
  };
  $where->{type_nobj_id} = {-in => [map { $_->nobj_id } @$types]}
      if @$types;
  $where->{updated} = $page->{value} if defined $page->{value};

  return $self->db->select ('hook', $where, fields => [
    'subscriber_nobj_id', 'type_nobj_id', 'url', 'url_sha',
    'status', 'data', 'created', 'updated', 'expires',
  ], source_name => 'master',
    offset => $page->{offset}, limit => $page->{limit},
    order => ['updated', $page->{order_direction}],
  )->then (sub {
    return $_[0]->all->to_a;
  }); # url and data is not decoded!
} # get_hooks

sub run_stats ($) {
  my $self = $_[0];

  ## Stats of days.
  ##
  ## A day stats has item : NObj, day : Timestamp, value_all : Number,
  ## value_1 : Number, value_7 : Number, value_30 : Number.
  if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'list.json') {
    ## /{app_id}/stats/list.json - Get a set of data of a day.
    ##
    ## Parameters.
    ##
    ##   NObj (|item|) : The day stats' item NObj.  Zero or more
    ##   parameters can be specified.
    ##
    ##   |min| : Timestamp : The minimum day stats' day.  Defaulted to
    ##   -Inf.
    ##
    ##   |max| : Timestamp : The maximum day stats' day.  Defaulted to
    ##   Inf.
    ##
    ##   |limit| : Integer : The maximum number of data.  The only
    ##   first data from the |min| day is returned.  Note that the
    ##   value constraints the number of the day stats records, which
    ##   might be different from the number of the days.  Defaulted to
    ##   10000.
    ##
    ## List response of:
    ##
    ##   |day| : Timestamp : The day stats' day.
    ##
    ##   /The day stats' item NObj key/ : JSON object.
    ##
    ##     |value_all| : Number : The day stats' value_all.
    ##
    ##     |value_1| : Number : The day stats' value_1.
    ##
    ##     |value_7| : Number : The day stats' value_7.
    ##
    ##     |value_30| : Number : The day stats' value_30.
    return Promise->all ([
      $self->nobj_list ('item'),
    ])->then (sub {
      my ($items) = @{$_[0]};

      my $limit = $self->{app}->bare_param ('limit') || 10000;
      return $self->throw ({reason => 'Bad |limit|'}) if $limit > 10000;

      my @nobj_id;
      for (@$items) {
        push @nobj_id, $_->nobj_id unless $_->is_error;
      }
      return [] unless @nobj_id;
      
      my $min = $self->{app}->bare_param ('min');
      my $max = $self->{app}->bare_param ('max');
      my $day_range = {};
      $day_range->{'>='} = 0+$min if defined $min;
      $day_range->{'<='} = 0+$max if defined $max;

      return $self->db->select ('day_stats', {
        ($self->app_id_columns),
        item_nobj_id => {-in => \@nobj_id},
        (keys %$day_range ? (day => $day_range) : ()),
      }, fields => [
        'day', 'item_nobj_id',
        'value_all', 'value_1', 'value_7', 'value_30',
      ], order => ['day', 'asc'], limit => 0+$limit, source_name => 'master')->then (sub {
        return $_[0]->all;
      });
    })->then (sub {
      my $items = $_[0];
      return $self->replace_nobj_ids ($items, ['item']);
    })->then (sub {
      my $items = $_[0];
      my $result = [];
      my $last = {day => -"Inf", items => {}};
      for (@$items) {
        unless ($_->{day} == $last->{day}) {
          push @$result, $last = {day => $_->{day}};
        }
        $last->{items}->{$_->{item_nobj_key}} = {
          value_all => $_->{value_all},
          value_1 => $_->{value_1},
          value_7 => $_->{value_7},
          value_30 => $_->{value_30},
        };
      }
      return $self->json ({items => $result});
    });
  }
  
  if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'post.json') {
    ## /{app_id}/stats/post.json - Post a set of data of a day.
    ##
    ## Parameters.
    ##
    ##   NObj (|item|) : The day stats' item NObj.
    ##
    ##   |day| : Timestamp : The day stats' day.
    ##
    ##   |value_all| : Number : The day stats' value_all.  If
    ##   specified, value_1, value_7, and value_30 of this and related
    ##   day stats records are updated.
    ##
    ##   |value_1| : Number : The day stats' value_1.  If specified,
    ##   value_7 and value_30 of this and related day stats records
    ##   are updated.  Exactly one of |value_all| and |value_1| is
    ##   required.  Only one of them should be specified for a NObj
    ##   (|item|) among all |day| updates to not lost any original
    ##   data.
    ##
    ## Response.  No additional data.
    return Promise->all ([
      $self->new_nobj_list (['item']),
    ])->then (sub {
      my ($item) = @{$_[0]->[0]};
      my $day = $self->{app}->bare_param ('day') //
          return $self->throw ({reason => 'Bad |day|'});
      $day = Web::DateTime->new_from_unix_time ($day);
      $day = Web::DateTime->new_from_components
          ($day->utc_year, $day->utc_month, $day->utc_day);
      my $value_all = $self->{app}->bare_param ('value_all');
      my $value_1 = $self->{app}->bare_param ('value_1');
      return $self->throw ({reason => 'Bad |value_all|'})
          unless defined $value_all or defined $value_1;
      my $time = time;
      my @updated_1 = ($day->to_unix_integer);
      return $self->db->execute ('select get_lock(?, 100)', [
        join $;, 'apploach-stats-post', $item->nobj_id,
      ], source_name => 'master')->then (sub {
        ## If |value_1|
        return $self->db->insert ('day_stats', [{
          ($self->app_id_columns),
          ($item->to_columns ('item')),
          day => $day->to_unix_integer,
          value_all => 0,
          value_1 => $value_1,
          value_7 => $value_1, # to be updated
          value_30 => $value_1, # to be updated
          created => $time,
          updated => $time,
        }], duplicate => {
          value_1 => $self->db->bare_sql_fragment ('VALUES(`value_1`)'),
          updated => $self->db->bare_sql_fragment ('VALUES(`updated`)'),
        }, source_name => 'master') if defined $value_1;

        ## If |value_all|
        return Promise->all ([
          $self->db->select ('day_stats', {
            ($self->app_id_columns),
            ($item->to_columns ('item')),
            day => {'<', $day->to_unix_integer},
          }, fields => ['value_all'], order => ['day', 'desc'], limit => 1, source_name => 'master')->then (sub {
            return (($_[0]->first || {})->{value_all}); # or undef
          }),
          $self->db->select ('day_stats', {
            ($self->app_id_columns),
            ($item->to_columns ('item')),
            day => {'>', $day->to_unix_integer},
          }, fields => ['day'], order => ['day', 'asc'], limit => 1, source_name => 'master')->then (sub {
            return (($_[0]->first || {})->{day}); # or undef
          }),
        ])->then (sub {
          my ($prev_value_all, $next_day) = @{$_[0]};
          return $self->db->insert ('day_stats', [{
            ($self->app_id_columns),
            ($item->to_columns ('item')),
            day => $day->to_unix_integer,
            value_all => $value_all,
            value_1 => $value_all - ($prev_value_all || 0),
            value_7 => $value_all, # to be updated
            value_30 => $value_all, # to be updated
            created => $time,
            updated => $time,
          }], duplicate => {
            value_all => $self->db->bare_sql_fragment ('VALUES(`value_all`)'),
            value_1 => $self->db->bare_sql_fragment ('VALUES(`value_1`)'),
            updated => $self->db->bare_sql_fragment ('VALUES(`updated`)'),
          }, source_name => 'master')->then (sub {
            return unless defined $next_day;
            push @updated_1, $next_day;
            return $self->db->execute ('update `day_stats` set `value_1` = `value_all` - :prev_value_all, `updated` = :updated where `app_id` = :app_id and `item_nobj_id` = :item_nobj_id and `day` = :day', {
              prev_value_all => $value_all,
              updated => $time,
              
              ($self->app_id_columns),
              ($item->to_columns ('item')),
              day => $next_day,
            }, source_name => 'master');
          });
        }); # if |value_all|
      })->then (sub {
        return $self->db->execute ('select release_lock(?)', [
          join $;, 'apploach-stats-post', $item->nobj_id,
        ], source_name => 'master');
      })->then (sub {
        return promised_for {
          my $day_this = shift;
          my $day_after = $day_this + 24*60*60;
          my $day_before = $day_after - 7*24*60*60;
          return $self->db->execute (q{update `day_stats`, (
            select sum(`value_1`) as `sum` from `day_stats` where `app_id` = :app_id and `item_nobj_id` = :item_nobj_id and :day_before <= `day` and `day` < :day_after
          ) `sum` set `day_stats`.`value_7` = ifnull(`sum`.`sum`, 0), `day_stats`.`updated` = :updated where `app_id` = :app_id and `item_nobj_id` = :item_nobj_id and `day` = :day}, {
            ($self->app_id_columns),
            ($item->to_columns ('item')),
            day_before => $day_before,
            day_after => $day_after,
            day => $day_this,
            updated => $time,
          }, source_name => 'master');
        } [map { my $x = $_; map { $x+$_ } 0..6 } @updated_1];
      })->then (sub {
        return promised_for {
          my $day_this = shift;
          my $day_after = $day_this + 24*60*60;
          my $day_before = $day_after - 30*24*60*60;
          return $self->db->execute (q{update `day_stats`, (
            select sum(`value_1`) as `sum` from `day_stats` where `app_id` = :app_id and `item_nobj_id` = :item_nobj_id and :day_before <= `day` and `day` < :day_after
          ) `sum` set `day_stats`.`value_30` = ifnull(`sum`.`sum`, 0), `day_stats`.`updated` = :updated where `app_id` = :app_id and `item_nobj_id` = :item_nobj_id and `day` = :day}, {
            ($self->app_id_columns),
            ($item->to_columns ('item')),
            day_before => $day_before,
            day_after => $day_after,
            day => $day_this,
            updated => $time,
          }, source_name => 'master');
        } [map { my $x = $_; map { $x+$_ } 0..29 } @updated_1];
      });
    })->then (sub {
      return $self->json ({});
    });
  }
  
  return $self->{app}->throw_error (404);
} # run_stats

sub run_nobj ($) {
  my $self = $_[0];

  ## Logs.  An NObj can have zero or more logs.  A log has ID, which
  ## identifies the log, target NObj, which represents the NObj to
  ## which the log is associated, operator NObj, which is intended to
  ## represent who causes the log being recorded, verb NObj, which is
  ## intended to represent the type of the log, and data, which is a
  ## JSON object containing application-specific log data.

  if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'addlog.json') {
      ## /{app_id}/nobj/addlog.json - Add a log entry.
      ##
      ## Parameters.
      ##
      ##   NObj (|operator|) : The log's operator NObj.
      ##
      ##   NObj (|target| with index) : The log's target NObj.
      ##
      ##   NObj (|verb|) : The log's verb NObj.
      ##
      ##   |data| : JSON object : The log's data.  If it has a
      ##   name/value pair whose name is |timestamp|, its value,
      ##   interpreted as Timestamp, is used as the timestamp of the
      ##   log entry.
      ##
      ## Response.
      ##
      ##   |log_id| : ID : The log's ID.
      ##
      ##   |timestamp| : Timestamp : The log's data's |timestamp|.
    my $ti = $self->{app}->bare_param ('target_index_nobj_key') // 'apploach-null';
        ## Note that |target_index_nobj_id| column is added by
        ## R3.10.13 update of Apploach.  Any data inserted by previous
        ## versions would have the value of zero (i.e. the default
        ## column value specified in the |ALTER TABLE| statement or in
        ## |target_index_nobj_id|), which would not be resolved to
        ## |apploach-null|.
    return Promise->all ([
      $self->new_nobj_list (['operator', 'target', 'verb', \$ti]),
    ])->then (sub {
      my ($operator, $target, $verb, $target_index) = @{$_[0]->[0]};
      if ($ti eq 'apploach-null' and
          $self->{app}->bare_param ('test_no_target_index')) {
        undef $target_index;
      }
      my $data = $self->json_object_param ('data');
      return $self->write_log ($self->db, $operator, $target, $target_index, $verb, $data)->then (sub {
        return $self->json ($_[0]);
      });
    });
  } elsif (@{$self->{path}} == 1 and $self->{path}->[0] eq 'logs.json') {
    ## /{app_id}/nobj/logs.json - Get logs.
    ##
    ## Parameters.
    ##
    ##   |log_id| : ID : The log's ID.
    ##
    ##   NObj (|operator|) : The log's operator NObj.
    ##
    ##   NObj (|target| with index) : The log's object NObj.
    ##
    ##   NObj (|verb|) : The log's object NObj.  At least one of
    ##   these four parameters should be specified.  Logs matching
    ##   with these four parameters are returned in the response.
    ##
    ##   |target_index_distinct| : Boolean : If true and
    ##   |target_index_nobj_key| is not specified, only single log per
    ##   the log's object index NObj.
    ##
    ##   |without_data| : Boolean : If true, the logs' |data| is
    ##   omitted from the response.
    ##
    ##   Pages.
    ##
    ## List response of logs.
    ##
    ##   |log_id| : ID : The log's ID.
    ##
    ##   NObj (|operator|) : The log's operator NObj.
    ##
    ##   NObj (|target|) : The log's target NObj.
    ##
    ##   NObj (|verb|) : The log's verb NObj.
    ##
    ##   |data| : JSON Object : The log's data.  Omitted if
    ##   |without_data| parameter is set to true.
    ##
    my $s = $self->{app}->bare_param ('operator_nobj_key');
    my $o = $self->{app}->bare_param ('target_nobj_key');
    my $oi = $self->{app}->bare_param ('target_index_nobj_key');
    my $v = $self->{app}->bare_param ('verb_nobj_key');
    my $page = Pager::this_page ($self, limit => 10, max_limit => 10000);
    return Promise->all ([
      $self->_no ([$s, $o, $v, $oi]),
    ])->then (sub {
      my ($subj, $obj, $verb, $obj_index) = @{$_[0]->[0]};
      return [] if defined $v and $verb->is_error;
      return [] if defined $s and $subj->is_error;
      return [] if defined $o and $obj->is_error;
      return [] if defined $oi and $obj_index->is_error;

      my $where = {
        ($self->app_id_columns),
      };
      if (not $subj->is_error) {
        $where = {
          %$where,
          ($subj->to_columns ('operator')),
        };
      }
      if (not $verb->is_error) {
        $where = {
          %$where,
          ($verb->to_columns ('verb')),
        };
      }
      if (not $obj->is_error) {
        $where = {
          %$where,
          ($obj->to_columns ('target')),
        };
      }
      my @ti_field;
      if (defined $obj_index and not $obj_index->is_error) {
        $where = {
          %$where,
          ($obj_index->to_columns ('target_index')),
        };
      } else {
        if ($self->{app}->bare_param ('target_index_distinct')) {
          push @ti_field, 'target_index_nobj_id';
        }
      }
      my $id = $self->{app}->bare_param ('log_id');
      if (defined $id) {
        $where->{log_id} = $id;
        $page->{only_item} = 1;
      }
      $where->{timestamp} = $page->{value} if defined $page->{value};

      return $self->db->select ('log', $where, fields => [
        'operator_nobj_id', 'target_nobj_id', 'verb_nobj_id',
        'timestamp', 'log_id',
        ($self->{app}->bare_param ('without_data') ? () : ('data')),
        @ti_field,
      ], source_name => 'master',
        offset => $page->{offset}, limit => $page->{limit},
        order => ['timestamp', $page->{order_direction}],
        (@ti_field ? (group => ['target_index_nobj_id']) : ()),
      )->then (sub {
        return $self->replace_nobj_ids
            ($_[0]->all->to_a, ['operator', 'target', 'verb', (@ti_field ? ('target_index') : ())]);
      });
    })->then (sub {
      my $items = $_[0];
      my $next_page = Pager::next_page $page, $items, 'timestamp';
      for (@$items) {
        delete $_->{timestamp};
        $_->{log_id} .= '';
        $_->{data} = Dongry::Type->parse ('json', $_->{data})
            if defined $_->{data};
      }
      return $self->json ({items => $items, %$next_page});
    });
  }

  ## Revisions.  An NObj can have zero or more revisions.  A revision
  ## has target NObj, which is the revised NObj, revision ID : ID,
  ## statuses : Statuses, which is the statuses of the revision
  ## itself, timestamp : Timestamp, author NObj : NObj, operator NObj
  ## : NObj, summary data : Object, which can contain
  ## application-specific summary of the revision, data : Object,
  ## which can contain application-specific snapshot or delta of the
  ## revision, revision info : Object, which can contain
  ## application-specific metadata of the revision itself.

  if (@{$self->{path}} == 2 and $self->{path}->[0] eq 'revision' and
      $self->{path}->[1] eq 'create.json') {
    ## /{app_id}/nobj/revision/create.json - Create a new revision of an
    ## NObj.
    ##
    ## Parameters.
    ##
    ##   NObj (|target|) : The revision's target NObj.  Required.
    ##
    ##   NObj (|operator|) : The revision's operator NObj.  Required.
    ##
    ##   NObj (|author|) : The revision's author NObj.  Required.
    ##
    ##   Statuses : The revision's statuses.
    ##
    ##   |summary_data| : JSON object : The revision's summary data.
    ##   Required.
    ##
    ##   |data| : JSON object : The revision's data.  Required.
    ##
    ##   |revision_data| : JSON object : The revision's revision data.
    ##   Required.
    ##
    ## Created object response.
    ##
    ##   |revision_id| : ID : The revision's ID.
    ##
    ##   |timestamp| : Timestamp : The revision's data's timestamp.
    return Promise->all ([
      $self->new_nobj_list (['target', 'operator', 'author']),
      $self->ids (1),
    ])->then (sub {
      my (undef, $ids) = @{$_[0]};
      my ($target, $operator, $author) = @{$_[0]->[0]};
      my $time = time;
      my $summary_data = $self->json_object_param ('summary_data');
      my $data = $self->json_object_param ('data');
      my $revision_data = $self->json_object_param ('revision_data');
      return $self->db->insert ('revision', [{
        ($self->app_id_columns),
        ($target->to_columns ('target')),
        revision_id => $ids->[0],
        ($author->to_columns ('author')),
        ($operator->to_columns ('operator')),
        summary_data => Dongry::Type->serialize ('json', $summary_data),
        data => Dongry::Type->serialize ('json', $data),
        revision_data => Dongry::Type->serialize ('json', $revision_data),
        ($self->status_columns),
        timestamp => $time,
      }])->then (sub {
        return $self->json ({
          revision_id => ''.$ids->[0],
          timestamp => $time,
        });
      });
    });
  } elsif (@{$self->{path}} == 2 and $self->{path}->[0] eq 'revision' and
           $self->{path}->[1] eq 'list.json') {
    ## /{app_id}/nobj/revision/list.json - Get revisions.
    ##
    ## Parameters.
    ##
    ##   NObj (|target|) : The revision's target NObj.
    ##
    ##   |revision_id| : ID : The revision's ID.  Either the target
    ##   NObj or the revision ID, or both, is required.  If the target
    ##   NObj is specified, returned revisions are limited to those
    ##   for the target NObj.  If |revision_id| is specified, it is
    ##   further limited to one with that |revision_id|.
    ##
    ##   |with_summary_data| : Boolean : Whether |summary_data| should
    ##   be returned or not.
    ##
    ##   |with_data| : Boolean : Whether |data| should be returned or
    ##   not.
    ##
    ##   |with_revision_data| : Boolean : Whether |revision_data|
    ##   should be returned or not.
    ##
    ##   Status filters.
    ##
    ##   Pages.
    ##
    ## List response of revisions.
    ##
    ##   NObj (|target|) : The revision's target NObj.
    ##
    ##   |revision_id| : ID : The revision's revision ID.
    ##
    ##   |timestamp| : Timestamp : The revision's timestamp.
    ##
    ##   NObj (|author|) : The revision's author.
    ##
    ##   NObj (|operator|) : The revision's operator NObj.
    ##
    ##   |summary_data| : JSON object: The revision's summary data.
    ##   Only when |with_summary_data| is true.
    ##
    ##   |data| : JSON object: The revision's data.  Only when
    ##   |with_data| is true.
    ##
    ##   |revision_data| : JSON object: The revision's revision data.
    ##   Only when |with_revision_data| is true.
    ##
    ##   Statuses.
    my $page = Pager::this_page ($self, limit => 10, max_limit => 10000);
    return Promise->all ([
      $self->nobj ('target'),
    ])->then (sub {
      my $target = $_[0]->[0];
      return [] if $target->not_found;

      my $where = {
        ($self->app_id_columns),
        ($target->missing ? () : ($target->to_columns ('target'))),
        ($self->status_filter_columns),
      };
      $where->{timestamp} = $page->{value} if defined $page->{value};
      
      my $revision_id = $self->{app}->bare_param ('revision_id');
      if (defined $revision_id) {
        $where->{revision_id} = $revision_id;
        $page->{only_item} = 1;
      } else {
        return $self->throw
            ({reason => 'Either target or |revision_id| is required'})
            if $target->missing;
      }

      return $self->db->select ('revision', $where, fields => [
        'revision_id',
        'target_nobj_id',
        'author_nobj_id',
        'operator_nobj_id',
        ($self->{app}->bare_param ('with_summary_data') ? ('summary_data') : ()),
        ($self->{app}->bare_param ('with_data') ? ('data') : ()),
        ($self->{app}->bare_param ('with_revision_data') ? ('revision_data') : ()),
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
        $item->{revision_id} .= '';
        $item->{summary_data} = Dongry::Type->parse ('json', $item->{summary_data})
            if defined $item->{summary_data};
        $item->{data} = Dongry::Type->parse ('json', $item->{data})
            if defined $item->{data};
        $item->{revision_data} = Dongry::Type->parse ('json', $item->{revision_data})
            if defined $item->{revision_data};
      }
      return $self->replace_nobj_ids ($items, ['author', 'target', 'operator'])->then (sub {
        my $next_page = Pager::next_page $page, $items, 'timestamp';
        return $self->json ({items => $items, %$next_page});
      });
    });
  }

  # XXX revision status editing API

    ## Status info.  An NObj can have status info.  It is additional
    ## data on the current statuses of the NObj, such as reasons of
    ## admin's action of hiding the object from the public.  A status
    ## info has target NObj, which is an NObj to which the status info
    ## is associated, and data, author data, owner data, and admin
    ## data, which are JSON objects.  Author, owner, and admin data
    ## are intended to be used to have additional data associated with
    ## author, owner, and admin statuses.
    if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'setstatusinfo.json') {
      ## /{app_id}/nobj/setstatusinfo.json - Set status info of an
      ## NObj.
      ##
      ## Parameters.
      ##
      ##   NObj (|target|) : The status info's target NObj.
      ##
      ##   |data| : JSON object : The status info's data.  Its
      ##   |timestamp| is replaced by the time Apploach receives the
      ##   new status info.
      ##
      ##   |author_data| : JSON object : The status info's author
      ##   data.  Defaulted to the current author data, if any, or an
      ##   empty object.
      ##
      ##   |owner_data| : JSON object : The status info's owner data.
      ##   Defaulted to the current owner data, if any, or an empty
      ##   object.
      ##
      ##   |admin_data| : JSON object : The status info's admin data.
      ##   Defaulted to the current admin data, if any, or an empty
      ##   object.
      ##
      ##   NObj (|operator|) : The status info's log's operator NObj.
      ##
      ##   NObj (|verb|) : The status info's log's verb NObj.
      ##   Whenever the status info is set, a new log of NObj
      ##   (|target|), NObj (|operator|), NObj (|verb|), and |data| is
      ##   added.
      ##
      ## Response.
      ##
      ##   |log_id| : ID : The status info's log's ID.
      ##
      ##   |timestamp| : Timestamp : The status info's data's
      ##   |timestamp|.
      return Promise->all ([
        $self->new_nobj_list (['target', 'operator', 'verb']),
      ])->then (sub {
        my ($target, $operator, $verb) = @{$_[0]->[0]};
        my $data = $self->json_object_param ('data');
        my $data1 = $self->optional_json_object_param ('author_data');
        my $data2 = $self->optional_json_object_param ('owner_data');
        my $data3 = $self->optional_json_object_param ('admin_data');
        return $self->set_status_info
            ($self->db, $operator, $target, $verb,
             $data, $data1, $data2, $data3);
      })->then (sub {
        return $self->json ($_[0]);
      });
    } elsif (@{$self->{path}} == 1 and $self->{path}->[0] eq 'statusinfo.json') {
      ## /{app_id}/nobj/statusinfo.json - Get status info data of
      ## NObj.
      ##
      ## Parameters.
      ##
      ##   NObj list (|target|).  List of target NObj to get.
      ##
      ## Response.
      ##
      ##   |info| : Object.
      ##
      ##     {NObj (|target|) : The status info's target NObj} : Array.
      ##
      ##       |data| : JSON object : The status info's data.
      ##
      ##       |author_data| : JSON object : The status info's author
      ##       data.
      ##
      ##       |owner_data| : JSON object : The status info's owner
      ##       data.
      ##
      ##       |admin_data| : JSON object : The status info's admin
      ##       data.
      return Promise->all ([
        $self->nobj_list ('target'),
      ])->then (sub {
        my $targets = $_[0]->[0];

        my @nobj_id;
        for (@$targets) {
          push @nobj_id, $_->nobj_id unless $_->is_error;
        }
        return [] unless @nobj_id;

        return $self->db->select ('status_info', {
          ($self->app_id_columns),
          target_nobj_id => {-in => \@nobj_id},
        }, fields => [
          'target_nobj_id', 'data', 'author_data', 'owner_data', 'admin_data',
        ], source_name => 'master')->then (sub {
          return $self->replace_nobj_ids ($_[0]->all->to_a, ['target']);
        });
      })->then (sub {
        my $items = $_[0];
        for (@$items) {
          $_->{data} = Dongry::Type->parse ('json', $_->{data});
          $_->{author_data} = Dongry::Type->parse ('json', $_->{author_data});
          $_->{owner_data} = Dongry::Type->parse ('json', $_->{owner_data});
          $_->{admin_data} = Dongry::Type->parse ('json', $_->{admin_data});
        }
        return $self->json ({info => {map {
          (delete $_->{target_nobj_key}) => $_;
        } @$items}});
      });
    }

  if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'touch.json') {
    ## /{app_id}/nobj/touch.json - Update timestamp of an NObj.
    ##
    ## Parameters.
    ##
    ##   NObj (|target|) : The NObj.  Zero or more parameters can be
    ##   specified.
    ##
    ## Response.  No additional data.
    ##
    ## The timestamp is updated to the current time.
    return Promise->all ([
      $self->nobj_list ('target'),
    ])->then (sub {
      my ($targets) = ($_[0]->[0]);
      $targets = [grep { not $_->is_error } @$targets];
      return unless @$targets;
      return $self->db->update ('follow', {
        timestamp => time,
      }, where => {
        ($self->app_id_columns),
        object_nobj_id => {-in => [map { $_->nobj_id } @$targets]},
      })->then (sub {
        return $self->db->update ('tag_item', {
          timestamp => time,
        }, where => {
          ($self->app_id_columns),
          item_nobj_id => {-in => [map { $_->nobj_id } @$targets]},
        });
      });
    })->then (sub {
      return $self->json ({});
    });
  } elsif (@{$self->{path}} == 1 and $self->{path}->[0] eq 'setscore.json') {
    ## /{app_id}/nobj/setscore.json - Update score of an NObj.
    ##
    ## Parameters.
    ##
    ##   NObj (|target|) : The NObj.
    ##
    ##   NObj (|tag_context|) : The tag's context NObj.  Zero or more
    ##   parameters can be specified.
    ##
    ##   score : Integer : The score.
    ##
    ## Response.  No additional data.
    return Promise->all ([
      $self->nobj ('target'),
      $self->nobj_list ('tag_context'),
    ])->then (sub {
      my ($target) = ($_[0]->[0]);
      return if $target->is_error;
      my ($tag_contexts) = ($_[0]->[1]);
      $tag_contexts = [grep { not $_->is_error } @$tag_contexts];
      my $score = 0+($self->{app}->bare_param ('score') || 0);
      return unless @$tag_contexts;
      return $self->db->update ('tag_item', {
        score => $score,
      }, where => {
        ($self->app_id_columns),
        context_nobj_id => {-in => [map { $_->nobj_id } @$tag_contexts]},
        item_nobj_id => $target->nobj_id,
      });
    })->then (sub {
      return $self->json ({});
    });
  }

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

  ## Attachments.  An NObj can have zero or more attachments.  An
  ## attachment has target NObj, URL, public URL, MIME type, byte
  ## length : Integer, payload : Bytes?, open : Boolean, deleted :
  ## Boolean.  Attachments are stored on the storage server.  When the
  ## attachment's open is true, it is accessible via its public URL or
  ## its signed URL.  Otherwise, it is accessible via its signed URL.
  
  if (@{$self->{path}} == 1 and $self->{path}->[0] eq 'attachform.json') {
    ## /{app_id}/nobj/attachform.json - Create a form to add an
    ## attachment to the NObj.
    ##
    ## Parameters.
    ##
    ##   NObj (|target|) : ID : The attachment's NObj.  Required.
    ##
    ##   |path_prefix| : String : The path of the attachment's URL,
    ##   within the directory specified by the configuration, without
    ##   random string part assigned by the Apploach server.  It must
    ##   be a string matching to |(/[A-Za-z0-9]+)+|.  Required.
    ##
    ##   File upload parameters: |mime_type| and |byte_length|.
    ##   Required.
    ##
    ## Response.
    ##
    ##   File upload information.
    ##
    ## This end point creates a file upload form.  By uploading a file
    ## using the file, the file's content is set to the attachment's
    ## payload.
    my $target;
    my $path = $self->{app}->bare_param ('path_prefix') // '';
    return $self->throw ({reason => 'Bad |path_prefix|'})
        unless $path =~ m{\A(?:/[0-9A-Za-z]+)+\z} and
               512 > length $path;
    $path =~ s{^/}{};
    return Promise->all ([
      $self->new_nobj_list (['target']),
    ])->then (sub {
      ($target) = @{$_[0]->[0]};
      return $self->db->transaction;
    })->then (sub {
      my $tr = $_[0];
      return $self->prepare_upload ($tr,
        target => $target,
        mime_type => $self->{app}->bare_param ('mime_type'),
        byte_length => $self->{app}->bare_param ('byte_length'),
        prefix => $path,
      )->then (sub {
        my $result = $_[0];
        return $tr->commit->then (sub {
          undef $tr;
          return $self->json ($result);
        });
      })->finally (sub {
        return $tr->rollback if defined $tr;
      }); # transaction
    });
  } elsif (@{$self->{path}} == 1 and
           ($self->{path}->[0] eq 'setattachmentopenness.json' or
            $self->{path}->[0] eq 'hideunusedattachments.json')) {
    ## /{app_id}/nobj/setattachmentopenness.json - Set the
    ## attachments' open of an NObj.
    ##
    ## /{app_id}/nobj/hideunusedattachments.json - Set the
    ## attachments' deleted of an NObj.
    ##
    ## Parameters.
    ##
    ##   NObj (|target|) : ID : The NObj.  Required.
    ##
    ##   |open| : Boolean : The attachment's open.  If true, the
    ##   attachemnts of the NObj, whose open is false and payload is
    ##   not null, are set to true.  If false, the attachments of the
    ##   NObj, whose open is true, are set to false.  Defaulted to
    ##   false.  |setattachmentopenness.json| only.
    ##
    ##   |used_url| : String : The attachment's URL that is still in
    ##   use.  Zero or more parameters can be
    ##   specified. |hideunusedattachments.json| only.
    ##
    ## Response.
    ##
    ##   |items| : Array:
    ##
    ##     /{Attachment's URL}/ : Object:
    ##
    ##       |changed| : Boolean : Whether the attachment's open is
    ##       changed or not.

    my $where = {};

    my $pubcopy = 0;
    my $update;
    if ($self->{path}->[0] eq 'setattachmentopenness.json') {
      my $open = $self->{app}->bare_param ('open');
      $update = {modified => time};
      if ($open) {
        $pubcopy = 1;
        $where->{open} = 0;
        #$where->{deleted} = 0;
        $update->{open} = 1;
        $update->{deleted} = 0;
      } else {
        $where->{open} = 1;
        $update->{open} = 0;
      }
    } elsif ($self->{path}->[0] eq 'hideunusedattachments.json') {
      my $used_urls = $self->{app}->bare_param_list ('used_url');
      if (@$used_urls) {
        $where->{url} = {-not_in => $used_urls};
      }
      $where->{deleted} = 0;
      $where->{open} = 1;
      $update = {
        deleted => 1,
        modified => time,
      };
    } else {
      die;
    }

    my $target;
    return Promise->all ([
      $self->new_nobj_list (['target']),
    ])->then (sub {
      ($target) = @{$_[0]->[0]};
      return $self->db->transaction;
    })->then (sub {
      my $tr = $_[0];
      my $result = {};
      return $tr->select ('attachment', {
        ($self->app_id_columns),
        ($target->to_columns ('target')),
        %$where,
      }, source_name => 'master', fields => ['data'], lock => 'update')->then (sub {
        my $files = $_[0]->all->to_a;
        my $clients = {};
        return promised_cleanup {
          return Promise->all ([map { $_->close } values %$clients]);
        } promised_for {
          my $file = Dongry::Type->parse ('json', $_[0]->{data});
          my $url = Web::URL->parse_string ($file->{file_url});
          my $public_url = Web::URL->parse_string
              ("$self->{config}->{s3_form_url}public/$file->{key}");
          my $client = $clients->{$public_url->get_origin->to_ascii}
              ||= Web::Transport::BasicClient->new_from_url ($public_url, {debug => 2});
          return $client->request (
            url => $public_url,
            method => ($pubcopy ? 'PUT' : 'DELETE'),
            aws4 => $self->{config}->{s3_aws4},
            headers => ($pubcopy ? {
              'x-amz-copy-source' => "$self->{config}->{s3_bucket}/$file->{key}",
              'x-amz-acl' => 'public-read',
            } : {}),
          )->then (sub {
            my $res = $_[0];
            die $res unless $res->is_success;
            $result->{items}->{$url->stringify}->{changed} = 1;
          })->catch (sub {
            warn $_[0]; # XXX error_log
            if (UNIVERSAL::isa ($_[0], 'Web::Transport::Response')) {
              warn substr $_[0]->body_bytes, 0, 1024;
            }
            $result->{items}->{$url->stringify}->{changed} = 0;
          });
        } $files;
      })->then (sub {
        my $urls = [grep { $result->{items}->{$_}->{changed} } keys %{$result->{items}}];
        return unless @$urls;
        return $tr->update ('attachment', $update, where => {
          ($self->app_id_columns),
          ($target->to_columns ('target')),
          url => {-in => [map { Dongry::Type->serialize ('text', $_) } @$urls]},
        }, source_name => 'master');
      })->then (sub {
        return $tr->commit->then (sub { undef $tr });
      })->then (sub {
        return $self->json ($result);
      })->finally (sub {
        return $tr->rollback if defined $tr;
      });
    });
  }

  if (@{$self->{path}} == 1 and
      $self->{path}->[0] eq 'signedstorageurl.json') {
    ## /{app_id}/nobj/signedstorageurl.json - Get signed URLs for
    ## files on the storage server.
    ##
    ## Parameters.
    ##
    ##   |url| : String : The attachment's URL.  Zero or more
    ##   parameters can be specified.
    ##
    ##   |max_age| : Integer : The lifetime of the signed URL, in
    ##   seconds.  Defaulted to 300.
    ##
    ## Response.  A JSON object whose names are attachment's URLs and
    ## values are their signed URLs.
    my $urls = $self->{app}->bare_param_list ('url');
    my $max_age = 0+($self->{app}->bare_param ('max_age') // 60*5);

    my $result = {};
    for (@$urls) {
      my $signed = $self->signed_storage_url ($_, $max_age);
      $result->{$_} = $signed if defined $signed;
    }

    return $self->json ($result);
  }
  
  return $self->{app}->throw_error (404);
} # run_nobj

sub run ($) {
  my $self = $_[0];

  if ($self->{type} eq 'comment' or
      $self->{type} eq 'star' or
      $self->{type} eq 'blog' or
      $self->{type} eq 'follow' or
      $self->{type} eq 'tag' or
      $self->{type} eq 'notification' or
      $self->{type} eq 'alarm' or
      $self->{type} eq 'message' or
      $self->{type} eq 'stats' or
      $self->{type} eq 'nobj' or
      $self->{type} eq 'fetch') {
    my $method = 'run_'.$self->{type};
    return $self->$method;
  }
  
  return $self->{app}->throw_error (404);
} # run

sub close ($) {
  my $self = $_[0];
  return Promise->resolve;
} # close

1;

=head1 LICENSE

Copyright 2018-2023 Wakaba <wakaba@suikawiki.org>.

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
