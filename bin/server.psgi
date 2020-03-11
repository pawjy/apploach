# -*- perl -*-
use strict;
use warnings;
use Path::Tiny;
use Wanage::HTTP;
use Warabe::App;
use Promise;
use Promised::Flow;

use Application;
use WorkerState;

my $RootPath = path (__FILE__)->parent->parent;
my $Rev = $RootPath->child ('rev')->slurp;

sub main ($$) {
  my ($class, $app) = @_;

  my $path = $app->path_segments;
  
  if (@$path == 1 and $path->[0] eq 'robots.txt') {
    # /robots.txt
    $app->http->set_response_header ('x-rev', $Rev);
    return $app->send_plain_text ("User-agent: *\nDisallow: /");
  }

  if (@$path > 2 and $path->[0] =~ /\A[1-9][0-9]*\z/) {
    my $config = $app->http->server_state->data->{config};
    my $auth = $app->http->get_request_header ('authorization') // '';
    unless (defined $config->{bearer} and
            $auth eq 'Bearer ' . $config->{bearer}) {
      $app->http->set_response_header ('www-authenticate', 'Bearer');
      return $app->throw_error (401);
    }

    my $app_id = 0+shift @$path;
    my $type = shift @$path;
    my $application = Application->new (
      config => $config,
      app => $app,
      path => $path,
      app_id => $app_id,
      type => $type,
    );
    return Promise->resolve->then (sub {
      return $application->run;
    })->finally (sub {
      return $application->close;
    });
  }
  
  return $app->throw_error (404);
} # main

return sub {
  my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
  my $app = Warabe::App->new_from_http ($http);

  warn sprintf "Access: [%s] %s %s\n",
      scalar gmtime, $app->http->request_method, $app->http->url->stringify;

  return $app->execute_by_promise (sub {
    return Promise->resolve->then (sub {
      return __PACKAGE__->main ($app);
    })->catch (sub {
      my $e = $_[0];
      return if UNIVERSAL::isa ($e, 'Warabe::App::Done');
      if (UNIVERSAL::isa ($e, 'Web::Transport::Response')) {
        $e = $e . "\n" . substr $e->body_bytes, 0, 1024;
      }
      Application->error_log ($http->server_state->data->{config}, 'important', $e);
      return $app->send_error (500);
    });
  });
};

=head1 LICENSE

Copyright 2018-2020 Wakaba <wakaba@suikawiki.org>.

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
