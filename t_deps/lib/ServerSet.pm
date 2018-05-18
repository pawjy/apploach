package ServerSet;
use strict;
use warnings;
use Path::Tiny;
use File::Temp qw(tempdir);
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use AbortController;
use Promise;
use Promised::Flow;
use Promised::File;
use Promised::Command::Signals;
use Promised::Command::Docker;
use JSON::PS;
use Dongry::SQL qw(quote);
use Web::Host;
use Web::URL;
use Web::Transport::BasicClient;
use DockerStack;
use Migration;

my $RootPath = path (__FILE__)->parent->parent->parent->absolute;
my $dockerhost = Web::Host->parse_string
    (Promised::Command::Docker->dockerhost_host_for_container);

{
  use Socket;
  sub is_listenable_port ($) {
    my $port = $_[0] or return 0;
    socket(my $svr,PF_INET,SOCK_STREAM,getprotobyname('tcp'))||die"socket: $!";
    setsockopt($svr,SOL_SOCKET,SO_REUSEADDR,pack("l",1))||die "setsockopt: $!";
    bind($svr, sockaddr_in($port, INADDR_ANY)) || return 0;
    listen($svr, SOMAXCONN) || return 0;
    close($svr);
    return 1;
  } # is_listenable_port
  my $EphemeralStart = 1024; my $EphemeralEnd = 5000; my $not = {};
  sub find_listenable_port () {
    for (1..10000) {
      my$port=int rand($EphemeralEnd-$EphemeralStart);next if$not->{$port}++;
      if (is_listenable_port $port) { $not->{$port}++; return $port }
    }
    die "Listenable port not found";
  } # find_listenable_port
}

sub wait_for_http ($$) {
  my ($url, $signal) = @_;
  my $client = Web::Transport::BasicClient->new_from_url ($url, {
    last_resort_timeout => 1,
  });
  return promised_cleanup {
    return $client->close;
  } promised_wait_until {
    die Promise::AbortError->new if $signal->aborted; # XXX abortsignal
    return (promised_timeout {
      return $client->request (url => $url)->then (sub {
        return not $_[0]->is_network_error;
      });
    } 1)->catch (sub {
      $client->abort;
      $client = Web::Transport::BasicClient->new_from_url ($url);
      return 0;
    });
  } timeout => 60, interval => 0.3, signal => $signal;
} # wait_for_http

my @KeyChar = ('0'..'9', 'A'..'Z', 'a'..'z', '_');
sub random_string ($) {
  my $n = shift;
  my $key = '';
  $key .= $KeyChar[rand @KeyChar] for 1..$n;
  return $key;
} # random_string

sub mysql_dsn ($) {
  my $v = $_[0];
  return 'dbi:mysql:' . join ';', map {
    if (UNIVERSAL::isa ($v->{$_}, 'Web::Host')) {
      $_ . '=' . $v->{$_}->to_ascii;
    } else {
      $_ . '=' . $v->{$_};
    }
  } keys %$v;
} # mysql_dsn

sub _key ($$) {
  my ($self, $name) = @_;
  die "Key |$name| is not ready"
      if exists $self->{keys}->{$name} and not defined $self->{keys}->{$name};
  return $self->{keys}->{$name} //= random_string (30);
} # _key

sub _set_persistent_key ($$) {
  my ($self, $name) = @_;
  return if defined $self->{keys}->{$name};
  $self->{keys}->{$name} = undef;
  my $path = $self->_path ('key-' . $name . '.txt');
  my $file = Promised::File->new_from_path ($path);
  return $file->read_byte_string->then (sub {
    return $_[0];
  }, sub {
    my $v = random_string (30);
    return $file->write_byte_string ($v)->then (sub { return $v });
  })->then (sub {
    $self->{keys}->{$name} = $_[0];
  });
} # _set_persistent_key

sub _path ($$) {
  return $_[0]->{data_root_path}->child ($_[1]);
} # _path

sub _write_file ($$$) {
  my $self = $_[0];
  my $path = $self->_path ($_[1]);
  my $file = Promised::File->new_from_path ($path);
  return $file->write_byte_string ($_[2]);
} # _write_file

sub _write_json ($$$) {
  my $self = $_[0];
  return $self->_write_file ($_[1], perl2json_bytes $_[2]);
} # _write_json

sub _set_hostport ($$$$) {
  my ($self, $name, $host, $port) = @_;
  die "Can't set |$name| hostport anymore"
      if defined $self->{servers}->{$name};
  $self->_register_server ($name, $host, $port);
} # _set_hostport

sub _register_server ($$;$$) {
  my ($self, $name, $host, $port) = @_;
  $self->{servers}->{$name} ||= do {
    $port //= find_listenable_port;
    #$host //= Web::Host->parse_string ('127.0.0.1');
    $host //= Web::Host->parse_string ('0'); # need to bind all for container->port accesses
    my $local_url = Web::URL->parse_string
        ("http://".$host->to_ascii.":$port");

    my $data = {local_url => $local_url};

    if ($name eq 'proxy') {
      my $docker_url = Web::URL->parse_string ("http://".$dockerhost->to_ascii.":$port");
      $data->{local_envs} = {
        http_proxy => $local_url->get_origin->to_ascii,
      };
      $data->{docker_envs} = {
        http_proxy => $docker_url->get_origin->to_ascii,
      };
    } else {
      my $client_url = Web::URL->parse_string ("http://$name.server.test");
      $data->{client_url} = $client_url;
      $self->{proxy_map}->{"$name.server.test"} = $local_url;
    }
    
    $data;
  };
} # _register_server

sub _client_url ($$) {
  my ($self, $name) = @_;
  $self->_register_server ($name);
  return $self->{servers}->{$name}->{client_url} // die "No |$name| client URL";
} # _client_url

sub _local_url ($$) {
  my ($self, $name) = @_;
  $self->_register_server ($name);
  return $self->{servers}->{$name}->{local_url};
} # _local_url

sub _set_local_envs ($$$) {
  my ($self, $name, $dest) = @_;
  $self->_register_server ($name);
  my $envs = $self->{servers}->{$name}->{local_envs} // die "No |$name| envs";
  $dest->{$_} = $envs->{$_} for keys %$envs;
} # _set_local_envs

sub _set_docker_envs ($$$) {
  my ($self, $name, $dest) = @_;
  $self->_register_server ($name);
  my $envs = $self->{servers}->{$name}->{docker_envs} // die "No |$name| envs";
  $dest->{$_} = $envs->{$_} for keys %$envs;
} # _set_docker_envs

use AnyEvent;
use AnyEvent::Socket;
use Web::Transport::ProxyServerConnection;
sub _proxy ($%) {
  my ($self, %args) = @_;
  return Promise->resolve->then (sub {
    my $cv = AE::cv;
    $cv->begin;

    my $map = $self->{proxy_map};
    my $lurl = $self->_local_url ('proxy');
    my $server = tcp_server $lurl->host->to_ascii, $lurl->port, sub {
      $cv->begin;
      my $con = Web::Transport::ProxyServerConnection->new_from_aeargs_and_opts
          (\@_, {
            handle_request => sub {
              my $args = $_[0];
              my $url = $args->{request}->{url};
              my $mapped = $map->{$url->host->to_ascii};
              if (defined $mapped) {
                $args->{client_options}->{server_connection}->{url} = $mapped;
                return $args;
              } else {
                warn "proxy: ERROR: Unknown host in <@{[$url->stringify]}>\n";
                my $body = 'Host not registered: |'.$url->host->to_ascii.'|';
                return {response => {
                  status => 504,
                  status_text => $body,
                  headers => [['content-type', 'text/plain;charset=utf-8']],
                  body => $body,
                }} unless $args{allow_forwarding};
              }
              return $args;
            }, # handle_request
          });
      $con->closed->finally (sub { $cv->end });
    }; # $server

    $args{signal}->manakai_onabort (sub { $cv->end; undef $server });
    return [undef, Promise->from_cv ($cv)];
  });
} # _proxy

sub _docker ($%) {
  my ($self, %args) = @_;
  my $stack;
  my $data = {};

  my $servers = {
    mysqld => {
      prepare => sub {
        my ($self, $data) = @_;
        my $my_cnf = join "\n", '[mysqld]',
            'user=mysql',
            'default_authentication_plugin=mysql_native_password', # XXX
            #'skip-networking',
            'bind-address=0.0.0.0',
            'port=3306',
            'innodb_lock_wait_timeout=2',
            'max_connections=1000',
            #'sql_mode=', # old default
            #'sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES', # 5.6 default
        ;

        my @dsn = (
          user => $self->_key ('mysqld_user'),
          password => $self->_key ('mysqld_password'),
          host => $self->_local_url ('mysqld')->host,
          port => $self->_local_url ('mysqld')->port,
        );
        my @dbname = @{$args{mysqld_database_names}};
        @dbname = ('test') unless @dbname;
        $data->{_dbname_suffix} = $args{mysqld_database_name_suffix} // '';
        for my $dbname (@dbname) {
          $data->{local_dsn_options}->{$dbname} = {
            @dsn,
            dbname => $dbname . $data->{_dbname_suffix},
          };
          $data->{docker_dsn_options}->{$dbname} = {
            @dsn,
            host => $dockerhost,
            dbname => $dbname . $data->{_dbname_suffix},
          };
          $data->{local_dsn}->{$dbname}
              = mysql_dsn $data->{local_dsn_options}->{$dbname};
          $data->{docker_dsn}->{$dbname}
              = mysql_dsn $data->{docker_dsn_options}->{$dbname};
        } # $dbname

        $data->{_data_path} = $args{mysqld_data_path} // $self->_path ('mysqld-data');

        return Promise->all ([
          Promised::File->new_from_path ($data->{_data_path})->mkpath,
          $self->_write_file ('my.cnf', $my_cnf),
        ])->then (sub {
          return {
            image => ($ENV{CIRCLECI} ? 'mysql/mysql-server:5.7' : 'mysql/mysql-server'), # XXX
            volumes => [
              $self->_path ('my.cnf')->absolute . ':/etc/my.cnf',
              $data->{_data_path}->absolute . ':/var/lib/mysql',
            ],
            ports => [
              $self->_local_url ('mysqld')->hostport . ':3306',
            ],
            environment => {
              MYSQL_USER => $self->_key ('mysqld_user'),
              MYSQL_PASSWORD => $self->_key ('mysqld_password'),
              MYSQL_ROOT_PASSWORD => $self->_key ('mysqld_root_password'),
              MYSQL_ROOT_HOST => $dockerhost->to_ascii,
              MYSQL_DATABASE => $dbname[0] . $data->{_dbname_suffix},
              MYSQL_LOG_CONSOLE => 1,
            },
          };
        });
      }, # prepare
      wait => sub {
        my ($self, $data, $signal) = @_;
        my $client;
        return Promise->resolve->then (sub {
          require AnyEvent::MySQL::Client;
          require AnyEvent::MySQL::Client::ShowLog if $ENV{SQL_DEBUG};
          my $dsn = $data->{local_dsn_options}->{$args{mysqld_database_names}->[0] // 'test'};
          return promised_wait_until {
            die "Aborted" if $signal->aborted; # XXX
            $client = AnyEvent::MySQL::Client->new;
            return $client->connect (
              hostname => $dsn->{host}->to_ascii,
              port => $dsn->{port},
              username => 'root',
              password => $self->_key ('mysqld_root_password'),
              database => 'mysql',
            )->then (sub {
              return 1;
            })->catch (sub {
              return $client->disconnect->catch (sub { })->then (sub { 0 });
            });
          } timeout => 60*3, signal => $signal;
        })->then (sub {
          return $client->query (
            sprintf q{create user '%s'@'%s' identified by '%s'},
                $self->_key ('mysqld_user'), '%',
                $self->_key ('mysqld_password'),
          );
        })->then (sub {
          return promised_for {
            my $name = shift . $data->{_dbname_suffix};
            return $client->query ('create database if not exists ' . quote $name)->then (sub {
              return $client->query (
                sprintf q{grant all on %s.* to '%s'@'%s'},
                    quote $name,
                    $self->_key ('mysqld_user'), '%',
              );
            });
          } $args{mysqld_database_names};
        })->finally (sub {
          return $client->disconnect if defined $client;
        })->then (sub {
          return promised_for {
            my $name = shift;
            return Promised::File->new_from_path ($args{mysqld_database_schema_path}->child ("$name.sql"))->read_byte_string->then (sub {
              return Migration->run ($_[0] => $data->{local_dsn}->{$name}, dump => 1);
            })->then (sub {
              return $self->_write_file ("mysqld-$name.sql" => $_[0]);
            });
          } $args{mysqld_database_names};
        });
      }, # wait
      cleanup => sub {
        my ($self, $data) = @_;
        return unless defined $data->{_data_path};
        my $cmd = Promised::Command->new ([
          'docker',
          'run',
          '-v', $data->{_data_path}->absolute . ':/var/lib/mysql',
          'mysql/mysql-server',
          'chown', '-R', $<, '/var/lib/mysql',
        ]);
        return $cmd->run->then (sub { return $cmd->wait });
      }, # cleanup
    }, # mysqld
    storage => {
      prepare => sub {
        my ($self, $data) = @_;
        $data->{aws4} = [undef, undef, undef, 's3'];
        return Promise->all ([
          Promised::File->new_from_path ($self->_path ('minio_config'))->mkpath,
          Promised::File->new_from_path ($self->_path ('minio_data'))->mkpath,
        ])->then (sub {
          return {
            image => 'minio/minio',
            volumes => [
              $self->_path ('minio_config')->absolute . ':/config',
              $self->_path ('minio_data')->absolute . ':/data',
            ],
            user => "$<:$>",
            command => [
              'server',
              #'--address', "0.0.0.0:9000",
              '--config-dir', '/config',
              '/data'
            ],
            ports => [
              $self->_local_url ('storage')->hostport . ":9000",
            ],
          };
        });
      }, # prepare
      wait => sub {
        my ($self, $data, $signal) = @_;
        return Promise->resolve->then (sub {
          my $config_path = $self->_path ('minio_config')->child ('config.json');
          return promised_wait_until {
            return Promised::File->new_from_path ($config_path)->read_byte_string->then (sub {
              my $config = json_bytes2perl $_[0];
              $data->{aws4}->[0] = $config->{credential}->{accessKey};
              $data->{aws4}->[1] = $config->{credential}->{secretKey};
              $data->{aws4}->[2] = $config->{region};
              return defined $data->{aws4}->[0] &&
                     defined $data->{aws4}->[1] &&
                     defined $data->{aws4}->[2];
            })->catch (sub { return 0 });
          } timeout => 60*3, signal => $signal;
        })->then (sub {
          return wait_for_http $self->_local_url ('storage'), $signal;
        });
      }, # wait
    }, # storage
  }; # $servers

  my $stop = sub {
    return Promise->all ([
      defined $stack ? $stack->stop : undef,
      map {
        my $name = $_;
        Promise->resolve->then (sub {
          return (($servers->{$name}->{cleanup} or sub {})->($self, $data->{$name}));
        });
      } keys %$servers,
    ]);
  }; # $stop

  my $services = {};
  my $out = '';
  return Promise->all ([
    map {
      my $name = $_;
      Promise->resolve->then (sub {
        return $servers->{$name}->{prepare}->($self, $data->{$name} ||= {});
      })->then (sub {
        my $service = $_[0];
        $services->{$name} = $service if defined $service;
      });
    } keys %$servers,
  ])->then (sub {
    $stack = DockerStack->new ({
      services => $services,
    });
    $stack->propagate_signal (1);
    $stack->signal_before_destruction ('TERM');
    $stack->stack_name ($args{docker_stack_name} // __PACKAGE__);
    $stack->use_fallback (1);
    $stack->logs (sub {
      my $v = $_[0];
      return unless defined $v;
      $v =~ s/^/docker: start: /gm;
      $v .= "\x0A" unless $v =~ /\x0A\z/;
      $out .= $v;
    });
    $args{signal}->manakai_onabort ($stop);
    return $stack->start;
  })->then (sub {
    my $acs = [];
    my $waits = [
      map {
        my $ac = AbortController->new;
        ($servers->{$_}->{wait} or sub { })->($self, $data->{$_}, $ac->signal),
      } keys %$servers,
    ];
    $args{signal}->manakai_onabort (sub {
      $_->abort for @$acs;
      $stop->();
    });
    return Promise->all ($waits)->catch (sub {
      $_->abort for @$acs;
      die $_[0];
    });
  })->then (sub {
    my ($r_s, $s_s) = promised_cv;
    $args{signal}->manakai_onabort (sub {
      $s_s->($stop->());
    });
    return [$data, $r_s];
  })->catch (sub {
    my $e = $_[0];
    warn $out;
    $args{signal}->manakai_onabort (sub { });
    return $stop->()->then (sub { die $e });
  });
} # _docker

sub _docker_app ($%) {
  my ($self, %args) = @_;
  my $stack;
  my $data = {};

  my $servers = {
    app => {
      prepare => sub {
        my ($self, $data) = @_;
        my $envs = {};
        return Promise->all ([
          $args{receive_docker_data},
        ])->then (sub {
          my ($docker_data) = @{$_[0]};
          my $config = {};

          $config->{bearer} = $self->_key ('app_bearer');
          
          $config->{dsn} = $docker_data->{mysqld}->{docker_dsn}->{apploach};
          $self->_set_docker_envs ('proxy' => $envs);
          
          return $self->_write_json ('app-config.json', $config);
        })->then (sub {
          return {
            image => 'quay.io/wakaba/apploach',
            volumes => [
              $self->_path ('app-config.json')->absolute . ':/app-config.json',
            ],
            environment => {
              %$envs,
              APP_CONFIG => '/app-config.json',
            },
            ports => [
              $self->_local_url ('app')->hostport . ":8080",
            ],
          };
        });
      }, # prepare
      wait => sub {
        my ($self, $data, $signal) = @_;
        return wait_for_http $self->_local_url ('app'), $signal;
      }, # wait
    }, # storage
  }; # $servers

  my $stop = sub {
    return Promise->all ([
      defined $stack ? $stack->stop : undef,
      map {
        my $name = $_;
        Promise->resolve->then (sub {
          return (($servers->{$name}->{cleanup} or sub {})->($self, $data->{$name}));
        });
      } keys %$servers,
    ]);
  }; # $stop

  my $services = {};
  my $out = '';
  my $started = 0;
  return Promise->all ([
    map {
      my $name = $_;
      Promise->resolve->then (sub {
        return $servers->{$name}->{prepare}->($self, $data->{$name} ||= {});
      })->then (sub {
        my $service = $_[0];
        $services->{$name} = $service if defined $service;
      });
    } keys %$servers,
  ])->then (sub {
    $stack = DockerStack->new ({
      services => $services,
    });
    $stack->propagate_signal (1);
    $stack->signal_before_destruction ('TERM');
    $stack->stack_name (($args{docker_stack_name} // __PACKAGE__) . '-app');
    $stack->use_fallback (1);
    $stack->logs (sub {
      my $v = $_[0];
      return unless defined $v;
      $v =~ s/^/docker: app: /gm;
      $v .= "\x0A" unless $v =~ /\x0A\z/;
      $out .= $v;

      if ($started) {
        warn $out;
        $out = '';
      }
    });
    $args{signal}->manakai_onabort ($stop);
    return $stack->start;
  })->then (sub {
    my $acs = [];
    $started = 1;
    my $waits = [
      map {
        my $ac = AbortController->new;
        ($servers->{$_}->{wait} or sub { })->($self, $data->{$_}, $ac->signal),
      } keys %$servers,
    ];
    $args{signal}->manakai_onabort (sub {
      $_->abort for @$acs;
      $stop->();
    });
    return Promise->all ($waits)->catch (sub {
      $_->abort for @$acs;
      die $_[0];
    });
  })->then (sub {
    my ($r_s, $s_s) = promised_cv;
    $args{signal}->manakai_onabort (sub {
      $s_s->($stop->());
    });
    return [$data, $r_s];
  })->catch (sub {
    my $e = $_[0];
    warn $out;
    $args{signal}->manakai_onabort (sub { });
    return $stop->()->then (sub { die $e });
  });
} # _docker_app

sub _app ($%) {
  my ($self, %args) = @_;

  if ($args{use_docker_app}) {
    return $self->_docker_app (%args);
  }

  my $sarze = Promised::Command->new
      ([$RootPath->child ('perl'),
        $RootPath->child ('bin/sarze.pl'),
        $self->_local_url ('app')->host->to_ascii,
        $self->_local_url ('app')->port]);
  $sarze->propagate_signal (1);

  return Promise->all ([
    $args{receive_docker_data},
  ])->then (sub {
    my ($docker_data) = @{$_[0]};
    my $config = {};

    $config->{bearer} = $self->_key ('app_bearer');
    
    $config->{dsn} = $docker_data->{mysqld}->{local_dsn}->{apploach};
    $self->_set_local_envs ('proxy' => $sarze->envs);
    
    $sarze->envs->{APP_CONFIG} = $self->_path ('app-config.json');
    return $self->_write_json ('app-config.json', $config);
  })->then (sub {
    $args{signal}->manakai_onabort (sub { $sarze->send_signal ('TERM') });
    return $sarze->run;
  })->then (sub {
    my $ac = AbortController->new;
    $sarze->wait->finally (sub { $ac->abort });
    return wait_for_http
        (Web::URL->parse_string ('/robots.txt', $self->_local_url ('app')),
         $ac->signal);
  })->then (sub {
    return [undef, $sarze->wait];
  })->catch (sub {
    my $e = $_[0];
    $sarze->send_signal ('TERM');
    return $sarze->wait->then (sub { die $e });
  });
} # _app

sub run ($%) {
  my ($class, %args) = @_;

  ## Arguments:
  ##   app_port       The port of the main application server.  Optional.
  ##   data_root_path Path::Tiny of the root of the server's data files.  A
  ##                  temporary directory (removed after shutdown) if omitted.
  ##   mysqld_database_name_suffix Name's suffix used in mysql database.
  ##                  Optional.
  ##   signal         AbortSignal canceling the server set.  Optional.

  ## Return a promise resolved into a hash reference of:
  ##   data
  ##     app_client_url Web::URL of the main application server for clients.
  ##     app_local_url Web::URL the main application server is listening.
  ##     local_envs   Environment variables setting proxy for /this/ host.
  ##   done           Promise fulfilled after the servers' shutdown.
  ## or rejected.

  if (defined $ENV{SS_ENV_FILE}) {
    return Promised::File->new_from_path (path ($ENV{SS_ENV_FILE}))->read_byte_string->then (sub {
      no strict;
      my $data = eval $_[0];
      die "$ENV{SS_ENV_FILE}: $@" if $@;
      my ($r, $s) = promised_cv;
      $args{signal}->manakai_onabort ($s);
      return {data => $data, done => $r};
    });
  }

  my $self = bless {
    proxy_map => {},
    data_root_path => $args{data_root_path},
  }, $class;
  unless (defined $args{data_root_path}) {
    my $tempdir = tempdir (CLEANUP => 1);
    $self->{data_root_path} = path ($tempdir);
    $self->{_tempdir} = $tempdir;
  }

  my $servers = {
    proxy => {
    },
    docker => {
      mysqld_database_name_suffix => $args{mysqld_database_name_suffix},
      mysqld_database_names => ['apploach'],
      mysqld_database_schema_path => $RootPath->child ('db'),
      #docker_stack_name
      persistent_keys => [qw(
        mysqld_user mysqld_password mysqld_root_password
      )],
    },
    app => {
      use_docker_app => $ENV{CIRCLECI},
      port => $args{app_port},
      requires => ['docker'],
      exposed_hostports => [['app', $args{app_host}, $args{app_port}]],
      persistent_keys => [qw(app_bearer)],
    },
  }; # $servers

  my $registered = Promise->resolve->then (sub {
    return Promise->all ([
      (map {
        $self->_set_hostport (@$_) for @{$_->{exposed_hostports} or []};
      } values %$servers),
      (map {
        map { $self->_set_persistent_key ($_) } @{$_->{persistent_keys} or []};
      } values %$servers),
    ]);
  });

  my $acs = {};
  my $data_send = {};
  my $data_receive = {};
  for (keys %$servers) {
    $acs->{$_} = AbortController->new;
    $servers->{$_}->{signal} = $acs->{$_}->signal;
    for my $other (@{$servers->{$_}->{requires} or []}) {
      die "Bad server |$other|" unless defined $servers->{$other};
      unless (defined $data_send->{$other}) {
        ($data_receive->{$other}, $data_send->{$other}) = promised_cv;
      }
      $servers->{$_}->{'receive_' . $other . '_data'} = $data_receive->{$other};
    }
  }

  my @started;
  my @done;
  my @signal;
  my $stopped;
  my $stop = sub {
    my $cancel = $_[0] || sub { };
    $cancel->();
    $stopped = 1;
    @signal = ();
    $_->abort for values %$acs;
  }; # $stop
  
  $args{signal}->manakai_onabort (sub { $stop->() }) if defined $args{signal};
  push @signal, Promised::Command::Signals->add_handler (INT => $stop);
  push @signal, Promised::Command::Signals->add_handler (TERM => $stop);
  push @signal, Promised::Command::Signals->add_handler (KILL => $stop);

  my $error;
  for my $name (keys %$servers) {
    my $method = '_' . $name;
    my $started = $registered->then (sub {
      return $self->$method (%{$servers->{$name}});
    })->then (sub {
      my ($data, $done) = @{$_[0]};
      $data_send->{$name}->($data) if defined $data_send->{$name};
      push @done, $done;
      return undef;
    })->catch (sub {
      $error //= $_[0];
      $stop->();
      $data_send->{$name}->(Promise->reject ($_[0]))
          if defined $data_send->{$name};
    });
    push @started, $started;
    push @done, $started;
  } # $name

  return Promise->all (\@started)->then (sub {
    die $error // "Stopped" if $stopped;

    my $data = {};
    $data->{app_local_url} = $self->_local_url ('app');
    $data->{app_client_url} = $self->_client_url ('app');
    $data->{app_bearer} = $self->_key ('app_bearer');
    $self->_set_local_envs ('proxy', $data->{local_envs} = {});

    $data->{artifacts_path} = defined $ENV{CIRCLE_ARTIFACTS}
        ? path ($ENV{CIRCLE_ARTIFACTS})
        : $self->_path ('artifacts');
    $data->{ss_env_file_path} = $data->{artifacts_path}->child ('env.pl');
    $data->{ss_env_pid_path} = $data->{artifacts_path}->child ('pid');

    my $pid_file = Promised::File->new_from_path ($data->{ss_env_pid_path});
    return Promise->all ([
      Promised::File->new_from_path ($data->{ss_env_file_path})->write_byte_string (Dumper $data),
      $pid_file->write_byte_string ($$),
    ])->then (sub {
      return {data => $data, done => Promise->all (\@done)->finally (sub {
        return $pid_file->remove_tree;
      })};
    })->catch (sub {
      my $e = $_[0];
      return $pid_file->remove_tree->then (sub { die $e });
    });
  })->catch (sub {
    my $e = $_[0];
    $stop->();
    return Promise->all (\@done)->then (sub { die $e });
  });
} # run

1;

=head1 LICENSE

Copyright 2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
