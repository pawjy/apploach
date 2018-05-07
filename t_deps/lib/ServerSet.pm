package ServerSet;
use strict;
use warnings;
use Path::Tiny;
use File::Temp qw(tempdir);
use DockerStack;
use Promise;
use Promised::Flow;
use Promised::File;
use Promised::Command::Signals;
use JSON::PS;
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

sub wait_for_http ($) {
  my ($url) = @_;
  my $client = Web::Transport::BasicClient->new_from_url ($url, {
    last_resort_timeout => 1,
  });
  return promised_cleanup {
    return $client->close;
  } promised_wait_until {
    return (promised_timeout {
      return $client->request (url => $url)->then (sub {
        return not $_[0]->is_network_error;
      });
    } 1)->catch (sub {
      $client->abort;
      $client = Web::Transport::BasicClient->new_from_url ($url);
      return 0;
    });
  } timeout => 60, interval => 0.3;
} # wait_for_http

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

sub _register_server ($$) {
  my ($self, $name) = @_;
  $self->{servers}->{$name} ||= do {
    my $port = find_listenable_port;
    my $listen_url = Web::URL->parse_string ("http://0:$port");
    my $client_url = Web::URL->parse_string ("$name.server.test");
    #XXX $proxy_data->{register}->("$name.server.test" => $listen_url);
    {listen_url => $listen_url, client_url => $client_url};
  };
} # _register_server

sub _listen_url ($$) {
  my ($self, $name) = @_;
  $self->_register_server ($name);
  return $self->{servers}->{$name}->{listen_url};
} # _listen_url

sub _listen_hostport ($$) {
  my ($self, $name) = @_;
  $self->_register_server ($name);
  return $self->{servers}->{$name}->{listen_url}->hostport;
} # _listen_hostport

sub _docker ($%) {
  my ($self, %args) = @_;
  # XXX abortsignal
  my $storage_data = {};
  my $stop;
  return Promise->all ([
    Promised::File->new_from_path ($self->_path ('minio_config'))->mkpath,
    Promised::File->new_from_path ($self->_path ('minio_data'))->mkpath,
  ])->then (sub {
    $storage_data->{aws4} = [undef, undef, undef, 's3'];

    my $stack = DockerStack->new ({
      services => {
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
            $self->_listen_hostport ('storage') . ":9000",
          ],
        },
      },
    });
    $stack->propagate_signal (1);
    $stack->signal_before_destruction ('TERM');
    $stack->stack_name ($args{stack_name} // __PACKAGE__);
    $stack->use_fallback (1);
    my $out = '';
    $stack->logs (sub {
      my $v = $_[0];
      return unless defined $v;
      $v =~ s/^/docker: start: /gm;
      $v .= "\x0A" unless $v =~ /\x0A\z/;
      $out .= $v;
    });
    $stop = sub { return $stack->stop };
    return $stack->start->catch (sub {
      warn $out;
      die $_[0];
    });
  })->then (sub {
    my $config_path = $self->_path ('minio_config')->child ('config.json');
    return promised_wait_until {
      return Promised::File->new_from_path ($config_path)->read_byte_string->then (sub {
        my $config = json_bytes2perl $_[0];
        $storage_data->{aws4}->[0] = $config->{credential}->{accessKey};
        $storage_data->{aws4}->[1] = $config->{credential}->{secretKey};
        $storage_data->{aws4}->[2] = $config->{region};
        return defined $storage_data->{aws4}->[0] &&
               defined $storage_data->{aws4}->[1] &&
               defined $storage_data->{aws4}->[2];
      })->catch (sub { return 0 });
    } timeout => 60*3;
  })->then (sub {
    return wait_for_http $self->_listen_url ('storage');
  })->then (sub {
    return [$storage_data, $stop, undef];
  });
} # _docker

sub run ($%) {
  my ($class, %args) = @_;

  my $self = bless {data_root_path => $args{data_root_path}}, $class;
  unless (defined $args{data_root_path}) {
    my $tempdir = tempdir (CLEANUP => 1);
    $self->{data_root_path} = path ($tempdir);
    $self->{_tempdir} = $tempdir;
  }

  # XXX abortsignal
  return Promise->all ([
    $self->_docker (
      #stack_name
    ),
  ])->then (sub {
    my @server = @{$_[0]};

    my @stopper;
    my @ended;
    for (@server) {
      my ($data, $stop, $done) = @$_;
      my ($r_s, $s_s) = promised_cv;
      my $stopper = sub { $s_s->(($stop or sub { })->()) };
      my $ended = Promise->all ([$done, $r_s]);
      push @stopper, $stopper;
      push @ended, $ended;
    }
    
    my @signal;
    my $stop = sub {
      my $cancel = $_[0] || sub { };
      $cancel->();
      @signal = ();
      return Promise->all ([map {
        Promise->resolve->then ($_)->catch (sub { });
      } @stopper]);
    }; # $stop

    push @signal, Promised::Command::Signals->add_handler (INT => $stop);
    push @signal, Promised::Command::Signals->add_handler (TERM => $stop);
    push @signal, Promised::Command::Signals->add_handler (KILL => $stop);

    return {stop => $stop, done => Promise->all ([map {
      $_->catch (sub {
        warn "$$: ERROR: $_[0]";
      });
    } @ended])};
  });
} # run

1;

=head1 LICENSE

Copyright 2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
