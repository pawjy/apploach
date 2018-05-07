package ServerSet;
use strict;
use warnings;
use Path::Tiny;
use File::Temp qw(tempdir);
use AbortController;
use Promise;
use Promised::Flow;
use Promised::File;
use Promised::Command::Signals;
use JSON::PS;
use DockerStack;
use Web::Host;
use Web::URL;
use Web::Transport::BasicClient;

my $RootPath = path (__FILE__)->parent->parent->parent->absolute;

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
  return $self->{keys}->{$name} ||= random_string (30);
} # _key

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
    $host //= Web::Host->parse_string ('127.0.0.1');
    my $local_url = Web::URL->parse_string
        ("http://".$host->to_ascii.":$port");

    my $data = {local_url => $local_url};

    if ($name eq 'proxy') {
      my $docker_url = Web::URL->parse_string ("http://dockerhost:$port");
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
  my $my_cnf = join "\n", '[mysqld]',
      'user=mysql',
      #'skip-networking',
      'bind-address=0.0.0.0',
      'port=3306',
      'innodb_lock_wait_timeout=2',
      'max_connections=1000',
      #'sql_mode=', # old default
      #'sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES', # 5.6 default
  ;
  return Promise->all ([
    Promised::File->new_from_path ($self->_path ('minio_config'))->mkpath,
    Promised::File->new_from_path ($self->_path ('minio_data'))->mkpath,
    $self->_write_file ('my.cnf', $my_cnf),
  ])->then (sub {
    $data->{storage}->{aws4} = [undef, undef, undef, 's3'];

    $data->{mysqld}->{local_dsn_options} = {
      user => $self->_key ('mysql_user'),
      password => $self->_key ('mysql_password'),
      host => $self->_local_url ('mysqld')->host,
      port => $self->_local_url ('mysqld')->port,
      dbname => $args{mysql_database},
    };
    $data->{mysqld}->{docker_dsn_options} = {
      %{$data->{mysqld}->{local_dsn_options}},
      host => Web::Host->parse_string ('dockerhost'),
    };
    $data->{mysqld}->{local_dsn} = mysql_dsn $data->{mysqld}->{local_dsn_options};
    $data->{mysqld}->{docker_dsn} = mysql_dsn $data->{mysqld}->{docker_dsn_options};
    
    $stack = DockerStack->new ({
      services => {
        mysqld => {
          image => 'mysql/mysql-server',
          volumes => [
            $self->_path ('my.cnf')->absolute . ':/etc/my.cnf',
          ],
          ports => [
            $self->_local_url ('mysqld')->hostport . ':3306',
          ],
          environment => {
            MYSQL_USER => $self->_key ('mysql_user'),
            MYSQL_PASSWORD => $self->_key ('mysql_password'),
            MYSQL_DATABASE => $args{mysql_database},
            MYSQL_LOG_CONSOLE => 1,
          },
        },
        minio => {
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
        },
      },
    });
    $stack->propagate_signal (1);
    $stack->signal_before_destruction ('TERM');
    $stack->stack_name ($args{docker_stack_name} // __PACKAGE__);
    $stack->use_fallback (1);
    my $out = '';
    $stack->logs (sub {
      my $v = $_[0];
      return unless defined $v;
      $v =~ s/^/docker: start: /gm;
      $v .= "\x0A" unless $v =~ /\x0A\z/;
      $out .= $v;
    });
    $args{signal}->manakai_onabort (sub { return $stack->stop });
    return $stack->start->catch (sub {
      warn $out;
      die $_[0];
    });
  })->then (sub {
    my $config_path = $self->_path ('minio_config')->child ('config.json');
    my $ac = AbortController->new;
    $args{signal}->manakai_onabort (sub {
      $stack->stop;
      $ac->abort;
    });
    return promised_wait_until {
      return Promised::File->new_from_path ($config_path)->read_byte_string->then (sub {
        my $config = json_bytes2perl $_[0];
        $data->{storage}->{aws4}->[0] = $config->{credential}->{accessKey};
        $data->{storage}->{aws4}->[1] = $config->{credential}->{secretKey};
        $data->{storage}->{aws4}->[2] = $config->{region};
        return defined $data->{storage}->{aws4}->[0] &&
               defined $data->{storage}->{aws4}->[1] &&
               defined $data->{storage}->{aws4}->[2];
      })->catch (sub { return 0 });
    } timeout => 60*3, signal => $ac->signal;
  })->then (sub {
    my $ac = AbortController->new;
    $args{signal}->manakai_onabort (sub {
      $stack->stop;
      $ac->abort;
    });
    return wait_for_http $self->_local_url ('storage'), $ac->signal;
  })->then (sub {
    my ($r_s, $s_s) = promised_cv;
    $args{signal}->manakai_onabort (sub {
      $s_s->($stack->stop);
    });
    return [$data, $r_s];
  })->catch (sub {
    my $e = $_[0];
    $args{signal}->manakai_onabort (sub { });
    return $stack->stop->then (sub { die $e }) if defined $stack;
    die $e;
  });
} # _docker

sub _app ($%) {
  my ($self, %args) = @_;

  # XXX docker mode
  my $sarze = Promised::Command->new
      ([$RootPath->child ('perl'),
        $RootPath->child ('bin/sarze.pl'),
        $self->_local_url ('app')->host->to_ascii,
        $self->_local_url ('app')->port]);
  $sarze->propagate_signal (1);

  return Promise->all ([
    $args{receive_docker_data},
#XXX    Promised::File->new_from_path ($args{config_template_path})->read_byte_string,
  ])->then (sub {
    my ($docker_data) = @{$_[0]};
    my $config = {};

    # XXX if docker mode
    $config->{dsn} = $docker_data->{mysqld}->{local_dsn};
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
  ##   mysql_database The database name in MySQL.  Optional.
  ##   signal         AbortSignal canceling the server set.  Optional.

  ## Return a promise resolved into a hash reference of:
  ##   data
  ##     app_client_url Web::URL of the main application server for clients.
  ##     app_local_url Web::URL the main application server is listening.
  ##     local_envs   Environment variables setting proxy for /this/ host.
  ##   done           Promise fulfilled after the servers' shutdown.
  ## or rejected.

  my $self = bless {
    proxy_map => {},
    data_root_path => $args{data_root_path},
  }, $class;
  unless (defined $args{data_root_path}) {
    my $tempdir = tempdir (CLEANUP => 1);
    $self->{data_root_path} = path ($tempdir);
    $self->{_tempdir} = $tempdir;
  }

  $self->_set_hostport ('app', $args{app_host}, $args{app_port});
  my $database = $args{mysql_database} // random_string (30);

  my $servers = {
    proxy => {
    },
    docker => {
      mysql_database => $database,
      #docker_stack_name
    },
    app => {
      port => $args{app_port},
      requires => ['docker'],
    },
  }; # $servers

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
    my $started = $self->$method (%{$servers->{$name}})->then (sub {
      my ($data, $done) = @{$_[0]};
      $data_send->{$name}->($data) if defined $data_send->{$name};
      push @done, $done;
      return undef;
    })->catch (sub {
      $error //= $_[0];
      $stop->();
    });
    push @started, $started;
    push @done, $started;
  } # $name

  return Promise->all (\@started)->then (sub {
    die $error // "Stopped" if $stopped;

    my $data = {};
    $data->{app_local_url} = $self->_local_url ('app');
    $data->{app_client_url} = $self->_client_url ('app');
    $self->_set_local_envs ('proxy', $data->{local_envs} = {});

    return {data => $data, done => Promise->all (\@done)};
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
