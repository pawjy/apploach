package Devices;
use strict;
use warnings;
use Time::HiRes qw(time);
use JSON::PS;
use Promised::Flow;
use Web::URL;
use Web::Transport::BasicClient;

#use Application;
push our @ISA, qw(Application);

sub run_devices ($) {
  my ($self) = @_;

  if (@{$self->{path}} >=2 and $self->{path}->[0] eq 'soracom') {
    # {}/devices/soracom/{}
    return $self->run_devices_soracom;
  }

  return $self->{app}->throw_error (404);
} # run_devices

sub run_devices_soracom ($) {
  my ($self) = @_;

  if (@{$self->{path}} == 2 and $self->{path}->[1] eq 'editstatus.json') {
    ## /{app_id}/devices/soracom/editstatus.json - Change SORACOM SIM status
    ##
    ## Parameters.
    ##
    ##   |imsi| : String - IMSI of the SIM.
    ##   |imei| : String - IMEI of the device associated with the SIM.
    ##   |mode| : "activate" | "deactivate" | "terminate" - Action.
    ##   NObj (|operator|) - The logged operator.
    ##   NObj (|verb|) - The logged action name.
    ##   NObj (|target|) - The logged target.
    ##
    ## Returns,
    ##
    ##  |log_id| : ID? : The log's ID.
    ##
    my $imsi = $self->{app}->bare_param ('imsi') // '';
    return $self->throw ({reason => 'Bad |imsi|'}) unless $imsi =~ /\A[0-9]{15}\z/;
    my $imei = $self->{app}->bare_param ('imei') // '';
    return $self->throw ({reason => 'Bad |imei|'}) unless $imei =~ /\A[0-9]{15}\z/;
    my $mode = $self->{app}->bare_param ('mode') // '';
    return $self->throw ({reason => 'Bad |mode|'}) unless $mode =~ /\A(?:activate|deactivate|terminate)\z/;

    my $endpoints = [@{$self->{config}->{devices_soracom_endpoints} || []}];
    my $auth_key_id = $self->{config}->{devices_soracom_auth_key_id};
    my $auth_key = $self->{config}->{devices_soracom_auth_key};

    my $operator;
    my $verb;
    my $target;
    my $log_data = {
      imsi => $imsi,
      imei => $imei,
      mode => $mode,
      responses => [],
    };

    my $resolved;
    return Promise->all ([
      $self->new_nobj_list (['operator', 'verb', 'target']),
    ])->then (sub {
      ($operator, $verb, $target) = @{$_[0]->[0]};

      return promised_wait_until {
        my $endpoint = shift @$endpoints;
        return 'done' unless defined $endpoint;

        my $url = Web::URL->parse_string ($endpoint);
        my $client = Web::Transport::BasicClient->new_from_url ($url);
        
        return $client->request (
          method => 'POST',
          path => ['v1', 'auth'],
          body => perl2json_bytes {
            authKeyId => $auth_key_id,
            authKey => $auth_key,
          },
          headers => { 'content-type' => 'application/json' },
        )->then (sub {
          my $res = $_[0];
          if ($res->status == 200) {
            my $res_payload = json_bytes2perl $res->body_bytes;
            my $api_key = eval { $res_payload->{apiKey} };
            my $token = eval { $res_payload->{token} };
            return not 'done' unless defined $api_key and defined $token;

            return $client->request (
              method => 'GET',
              path => ['v1', 'subscribers', $imsi],
              headers => {
                'x-soracom-api-key' => $api_key,
                'x-soracom-token' => $token,
              },
            )->then (sub {
              my $res2 = $_[0];
              my $res2_payload = ($res2->status == 200) ? json_bytes2perl $res2->body_bytes : undef;
              push @{$log_data->{responses}}, {
                step => 'get_subscriber',
                endpoint => $endpoint,
                status => $res2->status,
                body => $res2_payload,
              };

              if ($res2->status == 200) {
                $resolved = {
                  endpoint => $endpoint,
                  api_key => $api_key,
                  token => $token,
                  subscriber => $res2_payload,
                  status => $res2->status,
                };
                return 'done';
              } elsif ($res2->status == 404 or $res2->status >= 500) {
                return not 'done';
              } else {
                $resolved = { error => 1, status => $res2->status };
                return 'done';
              }
            });
          } elsif ($res->status == 404 or $res->status >= 500) {
            return not 'done';
          } else {
            $resolved = { error => 1, status => $res->status };
            return 'done';
          }
        })->finally (sub {
          return $client->close;
        });
      };
    })->then (sub {
      if (not defined $resolved) {
        return $self->throw ({
          reason => 'SUBSCRIBER_NOT_FOUND_ANY_REGION',
        });
      }
      
      if ($resolved->{error}) {
        return $self->throw ({
          reason => 'SORACOM_API_ERROR',
          status => $resolved->{status},
        });
      }

      my $sub_imei = eval { ($resolved->{subscriber}->{sessionStatus} || $resolved->{subscriber}->{previousSession})->{imei} };
      push @{$log_data->{responses}}, {
        step => 'verify_imei',
        status => $resolved->{status},
        expected => $sub_imei,
        actual => $imei,
      };

      if (not defined $sub_imei) {
        return $self->throw ({
          reason => 'IMEI_NOT_FOUND',
        });
      }

      if ($sub_imei ne $imei) {
        return $self->throw ({
          reason => 'IMEI_MISMATCH',
          expected => $sub_imei,
          actual => $imei,
        });
      }

      my $url = Web::URL->parse_string ($resolved->{endpoint});
      my $client = Web::Transport::BasicClient->new_from_url ($url);
      # XXX enableSimTermination
      return $client->request (
        method => 'POST',
        path => ['v1', 'subscribers', $imsi, $mode],
        headers => {
          'x-soracom-api-key' => $resolved->{api_key},
          'x-soracom-token' => $resolved->{token},
        },
      )->then (sub {
        my $res = $_[0];
        my $res_payload = ($res->status == 200) ? json_bytes2perl $res->body_bytes : undef;
        push @{$log_data->{responses}}, {
          step => 'action',
          mode => $mode,
          status => $res->status,
          body => $res_payload,
        };

        if ($res->status == 200) {
          return $res_payload;
        } else {
          return $self->throw ({
            reason => 'ACTION_FAILED',
          });
        }
      })->finally (sub {
        return $client->close;
      });
    })->catch (sub {
      my $error = $_[0];
      if (ref $error eq 'HASH' and defined $error->{status}) {
        return $self->throw ({
          reason => 'SORACOM_API_ERROR',
        });
      }
      die $error;
    })->then (sub {
      my $result = $_[0];
      return $self->write_log ($self->db, $operator, $target, undef, $verb, $log_data)->then (sub {
        $result->{log_id} = $_[0]->{log_id};
        return $self->json ($result);
      });
    }, sub {
      my $error = $_[0];
      if (defined $target and @{$log_data->{responses}}) {
        return $self->write_log ($self->db, $operator, $target, undef, $verb, $log_data)->then (sub {
          die $error;
        });
      }
      die $error;
    });
  }

  return $self->{app}->throw_error (404);
} # run_devices_soracom

1;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

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
