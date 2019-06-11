package ApploachSS;
use strict;
use warnings;
use Path::Tiny;
use Promise;
use ServerSet;

my $RootPath = path (__FILE__)->parent->parent->parent->absolute;

sub run ($%) {
  ## Arguments:
  ##   app_port       The port of the main application server.  Optional.
  ##   data_root_path Path::Tiny of the root of the server's data files.  A
  ##                  temporary directory (removed after shutdown) if omitted.
  ##   mysqld_database_name_suffix Name's suffix used in mysql database.
  ##                  Optional.
  ##   signal         AbortSignal canceling the server set.  Optional.
  my $class = shift;
  return ServerSet->run ({
    proxy => {
      handler => 'ServerSet::ReverseProxyHandler',
      prepare => sub {
        my ($handler, $self, $args, $data) = @_;
        return {
          client_urls => [],
        };
      }, # prepare
    }, # proxy
    mysqld => {
      handler => 'ServerSet::MySQLServerHandler',
    },
    storage => {
      handler => 'ServerSet::MinioHandler',
    },
    app_config => {
      requires => ['mysqld', 'storage'],
      keys => {
        app_bearer => 'key',
      },
      start => sub ($$%) {
        my ($handler, $self, %args) = @_;
        my $data = {};
        return Promise->all ([
          $self->read_json (\($args{app_config_path})),
          $args{receive_storage_data},
          $args{receive_mysqld_data},
        ])->then (sub {
          my ($config, $storage_data, $mysqld_data) = @{$_[0]};
          $data->{config} = $config;
          $config->{bearer} = $self->key ('app_bearer');

          $data->{app_docker_image} = $args{app_docker_image}; # or undef
          my $use_docker = defined $data->{app_docker_image};

          my $dsn_key = $use_docker ? 'docker_dsn' : 'local_dsn';
          $config->{dsn} = $mysqld_data->{$dsn_key}->{apploach};

          $config->{s3_aws4} = $storage_data->{aws4};
          #"s3_sts_role_arn"
          $config->{s3_bucket} = $storage_data->{bucket_domain};
          $config->{s3_form_url} = $storage_data->{form_client_url}->stringify;
          $config->{s3_file_url_prefix} = $storage_data->{file_root_client_url}->stringify;

          $data->{envs} = my $envs = {};
          if ($use_docker) {
            $self->set_docker_envs ('proxy' => $envs);
          } else {
            $self->set_local_envs ('proxy' => $envs);
          }

          $data->{config_path} = $self->path ('app-config.json');
          return $self->write_json ('app-config.json', $config);
        })->then (sub {
          return [$data, undef];
        });
      },
    }, # app_envs
    app => {
      handler => 'ServerSet::SarzeProcessHandler',
      requires => ['app_config', 'proxy'],
      prepare => sub {
        my ($handler, $self, $args, $data) = @_;
        return Promise->resolve ($args->{receive_app_config_data})->then (sub {
          my $config_data = shift;
          return {
            envs => {
              %{$config_data->{envs}},
              APP_CONFIG => $config_data->{config_path},
            },
            command => [
              $RootPath->child ('perl'),
              $RootPath->child ('bin/sarze.pl'),
            ],
            local_url => $self->local_url ('app'),
          };
        });
      }, # prepare
    }, # app
    app_docker => {
      handler => 'ServerSet::DockerHandler',
      requires => ['app_config', 'proxy'],
      prepare => sub {
        my ($handler, $self, $args, $data) = @_;
        return Promise->resolve ($args->{receive_app_config_data})->then (sub {
          my $config_data = shift;
          my $net_host = $args->{docker_net_host};
          my $port = $self->local_url ('app')->port; # default: 8080
          return {
            image => $config_data->{app_docker_image},
            volumes => [
              $config_data->{config_path}->absolute . ':/app-config.json',
            ],
            net_host => $net_host,
            ports => ($net_host ? undef : [
              $self->local_url ('app')->hostport . ":" . $port,
            ]),
            environment => {
              %{$config_data->{envs}},
              PORT => $port,
              APP_CONFIG => '/app-config.json',
            },
            command => ['/server'],
          };
        });
      }, # prepare
      wait => sub {
        my ($handler, $self, $args, $data, $signal) = @_;
        return $self->wait_for_http (
          $self->local_url ('app'),
          signal => $signal, name => 'wait for app',
          check => sub {
            return $handler->check_running;
          },
        );
      }, # wait
    }, # app_docker
    xs => {
      handler => 'ServerSet::SarzeHandler',
      prepare => sub {
        my ($handler, $self, $args, $data) = @_;
        return {
          hostports => [
            [$self->local_url ('xs')->host->to_ascii,
             $self->local_url ('xs')->port],
          ],
          psgi_file_name => $RootPath->child ('t_deps/bin/xs.psgi'),
          max_worker_count => 1,
          #debug => 2,
        };
      }, # prepare
    }, # xs
    _ => {
      requires => ['app_config'],
      start => sub {
        my ($handler, $self, %args) = @_;
        my $data = {};

        ## app_client_url Web::URL of the main application server for clients.
        ## app_local_url Web::URL the main application server is listening.
        ## local_envs   Environment variables setting proxy for /this/ host.
        
        $data->{app_local_url} = $self->local_url ('app');
        $data->{app_client_url} = $self->client_url ('app');
        $data->{app_bearer} = $self->key ('app_bearer');
        $self->set_local_envs ('proxy', $data->{local_envs} = {});

        return [$data, undef];
      },
    }, # _
  }, sub {
    my ($ss, $args) = @_;
    my $result = {};

    $result->{exposed} = {
      proxy => [$args->{proxy_host}, $args->{proxy_port}],
      app => [$args->{app_host}, $args->{app_port}],
    };

    my $app_docker_image = $args->{app_docker_image} // '';
    $result->{server_params} = {
      proxy => {
      },
      mysqld => {
        databases => {
          apploach => $RootPath->child ('db/apploach.sql'),
        },
        database_name_suffix => $args->{mysqld_database_name_suffix},
      },
      storage => {
        docker_net_host => $args->{docker_net_host},
        no_set_uid => $args->{no_set_uid},
        public_prefixes => [
          '/public',
        ],
      },
      app_config => {
        app_config_path => $RootPath->child ('t_deps/app_config.json'),
        app_docker_image => $app_docker_image || undef,
      },
      app => {
        disabled => !! $app_docker_image,
      },
      app_docker => {
        disabled => ! $app_docker_image,
        docker_net_host => $args->{docker_net_host},
      },
      xs => {
        disabled => $args->{dont_run_xs},
      },
      _ => {},
    }; # $result->{server_params}

    return $result;
  }, @_);
} # run

1;

=head1 LICENSE

Copyright 2018-2019 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
