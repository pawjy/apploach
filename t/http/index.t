use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->client->request (path => [])->then (sub {
    my $res = $_[0];
    test {
      is $res->status, 404;
    } $current->c;
  });
} n => 1, name => '/';

Test {
  my $current = shift;
  return $current->client->request (path => ['robots.txt'])->then (sub {
    my $res = $_[0];
    test {
      is $res->status, 200;
      is $res->body_bytes, "User-agent: *\nDisallow: /";
    } $current->c;
  });
} n => 2, name => '/robots.txt';

RUN;

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
