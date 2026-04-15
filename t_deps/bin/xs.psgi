# -*- perl -*-
use strict;
use warnings;
use Path::Tiny;
use Promised::Flow;
use Web::URL;
use Wanage::HTTP;
use JSON::PS;
use Web::Encoding;
use Web::Transport::Base64;
use Web::Transport::BasicClient;

my $Counts = {};
my $Messages = [];
my $Bearer = $ENV{APP_BEARER};

return sub {
  my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);

  warn sprintf "xs: Access: [%s] %s %s\n",
      scalar gmtime, $http->request_method, $http->url->stringify;

  $http->send_response (onready => sub {
    my $path = $http->url->{path};

    if ($path eq '/robots.txt') {
      $http->set_status (200);
      $http->send_response_body_as_ref (\"");
      return $http->close_response_body;
    }

    if ($path =~ m{^/push/([0-9A-Za-z._-]+)$}) {
      my $key = $1;
      if ($http->request_method eq 'POST') {
        $Counts->{'POST', $key}++;
        $http->set_status (200);
        return $http->close_response_body;
      } elsif (not $http->get_request_header ('x-test')) {
        $Counts->{'GET', $key}++;
        $http->set_status (200);
        return $http->close_response_body;
      }
      $http->set_status (200);
      my $json = {
        get_count => $Counts->{'GET', $key} || 0,
        post_count => $Counts->{'POST', $key} || 0,
      };
      $json->{count} = $json->{get_count} + $json->{post_count};
      $http->send_response_body_as_ref (\perl2json_bytes $json);
      return $http->close_response_body;
    }

    if ($path =~ m{^/vonage/send$}) {
      my $json = {};
      my $status = {};
      push @$Messages, my $message = {
        channel => 'vonage',
        %{json_bytes2perl ${ $http->request_body_as_ref }},
        api_key => $http->request_auth->{userid},
        api_secret => $http->request_auth->{password},
      };
      if (($http->get_request_header ('authorization') // '') =~ /^Bearer (.+)$/) {
        $message->{jwt} = $1;
      }
      if ($message->{text} =~ /RFAILURE/) {
        $http->set_status (400);
        delete $status->{status};
      } elsif ($message->{text} =~ /R500/) {
        $http->set_status (500);
        delete $status->{status};
      } elsif ($message->{text} =~ /CFAILURE/) {
        $status->{status} = 'unknownstatus';
      } else {
        $status->{status} = 'submitted';
      }
      $status->{client_ref} = $message->{client_ref};
      warn "SMS To: |$message->{to}|\n";
      $message->{to} =~ /^([0-9]*)/;
      my $app_id = $1;
      $http->send_response_body_as_ref (\perl2json_bytes $json);
      $http->close_response_body;

      return if not defined $status->{status};
      return promised_sleep (1)->then (sub {
        my $url = Web::URL->parse_string
            (qq<http://app.server.test/$app_id/message/callback.json>);
        my $client = Web::Transport::BasicClient->new_from_url ($url);
        return $client->request (
          method => 'POST',
          url => $url,
          bearer => $Bearer,
          params => {
            channel => 'vonage',
            body => encode_web_base64 (perl2json_bytes $status),
          },
        )->then (sub {
          return unless $status->{status} eq 'submitted';
          return promised_sleep (1)->then (sub {
            $status->{status} = 'delivered';
            return $client->request (
              method => 'POST',
              url => $url,
              bearer => $Bearer,
              params => {
                channel => 'vonage',
                body => encode_web_base64 (perl2json_bytes $status),
              },
            );
          });
        })->finally (sub {
          return $client->close;
        });
      });
    } elsif ($path =~ m{^/vonage/get$}) {
      my $to = decode_web_utf8 ($http->query_params->{to}->[0] // '');
      $http->send_response_body_as_ref (\perl2json_bytes [grep { $_->{to} eq $to } @$Messages]);
      return $http->close_response_body;
    }

    if ($path =~ m{^/soracom(?:-invalid)?/v1/auth$}) {
      if ($path =~ /invalid/) {
        $http->set_status (404);
        return $http->close_response_body;
      }
      my $json = json_bytes2perl ${ $http->request_body_as_ref };
      if ($json->{authKeyId} eq 'test_auth_key_id' and
          $json->{authKey} eq 'test_auth_key') {
        $http->set_status (200);
        $http->send_response_body_as_ref (\perl2json_bytes {
          apiKey => 'test_api_key',
          token => 'test_token',
          operatorId => 'OP001',
        });
      } else {
        $http->set_status (401);
        $http->send_response_body_as_ref (\perl2json_bytes {
          code => 'AUTH_FAILED',
          message => 'Authentication failed',
        });
      }
      return $http->close_response_body;
    }

    if ($path =~ m{^/soracom/v1/subscribers/([0-9]+)$}) {
      my $imsi = $1;
      if ($http->get_request_header ('x-soracom-api-key') eq 'test_api_key' and
          $http->get_request_header ('x-soracom-token') eq 'test_token') {
        if ($imsi eq '123456789012345') {
          $http->set_status (200);
          $http->send_response_body_as_ref (\perl2json_bytes {
            imsi => $imsi,
            previousSession => {imei => '123456789012345'},
            status => 'active',
          });
        } elsif ($imsi eq '111111111111111') {
          $http->set_status (200);
          $http->send_response_body_as_ref (\perl2json_bytes {
            imsi => $imsi,
            # imei missing
            status => 'active',
          });
        } elsif ($imsi eq '222222222222222') {
          $http->set_status (200);
          $http->send_response_body_as_ref (\perl2json_bytes {
            imsi => $imsi,
            sessionStatus => {imei => 'mismatch_imei'},
            status => 'active',
          });
        } elsif ($imsi eq '500500500500500') {
          $http->set_status (500);
          $http->send_response_body_as_ref (\perl2json_bytes {
            code => 'SERVER_ERROR',
            message => 'Simulated server error',
          });
        } else {
          $http->set_status (404);
          $http->send_response_body_as_ref (\perl2json_bytes {
            code => 'SUBSCRIBER_NOT_FOUND',
            message => 'Subscriber not found',
          });
        }
      } else {
        $http->set_status (401);
      }
      return $http->close_response_body;
    }

    if ($path =~ m{^/soracom/v1/subscribers/([0-9]+)/(activate|deactivate|terminate)$}) {
      my ($imsi, $mode) = ($1, $2);
      if ($http->get_request_header ('x-soracom-api-key') eq 'test_api_key' and
          $http->get_request_header ('x-soracom-token') eq 'test_token') {
        $http->set_status (200);
        $http->send_response_body_as_ref (\perl2json_bytes {
          imsi => $imsi,
          status => $mode eq 'terminate' ? 'terminated' : ($mode eq 'activate' ? 'active' : 'inactive'),
        });
      } else {
        $http->set_status (401);
      }
      return $http->close_response_body;
    }
    
    $http->set_status (404);
    return $http->close_response_body;
  });
};

=head1 LICENSE

Copyright 2018-2026 Wakaba <wakaba@suikawiki.org>.

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
