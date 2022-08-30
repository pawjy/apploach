# -*- perl -*-
use strict;
use warnings;
use Path::Tiny;
use Wanage::HTTP;
use JSON::PS;

my $Counts = {};

return sub {
  my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);

  warn sprintf "Access: [%s] %s %s\n",
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
    
    $http->set_status (404);
    return $http->close_response_body;
  });
};

=head1 LICENSE

Copyright 2018-2019 Wakaba <wakaba@suikawiki.org>.

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
