package Tests;
use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/modules/*/lib');
use Carp;
use JSON::PS;
use AbortController;
use Promise;
use Promised::Flow;
use ServerSet;
use CurrentTest;
use Test::X1;
use Test::More;
use Time::HiRes qw(time);

our @EXPORT = grep { not /^\$/ } (
  @Test::More::EXPORT,
  @Test::X1::EXPORT,
  @JSON::PS::EXPORT,
  @Promised::Flow::EXPORT,
  'time',
);

sub import ($;@) {
  my $from_class = shift;
  my ($to_class, $file, $line) = caller;
  no strict 'refs';
  for (@_ ? @_ : @{$from_class . '::EXPORT'}) {
    my $code = $from_class->can ($_)
        or croak qq{"$_" is not exported by the $from_class module at $file line $line};
    *{$to_class . '::' . $_} = $code;
  }
} # import

our $ServerData;
push @EXPORT, qw(RUN);
sub RUN () {
  note "Servers...";
  my $ac = AbortController->new;
  my $v = ServerSet->run (
    signal => $ac->signal,
    mysqld_database_name_suffix => '_test',
  )->to_cv->recv;

  note "Tests...";
  local $ServerData = $v->{data};
  run_tests;

  note "Done";
  $ac->abort;
  $v->{done}->to_cv->recv;
} # RUN

push @EXPORT, qw(Test);
sub Test (&%) {
  my $code = shift;
  test {
    my $c = shift;
    my $current = bless {
      c => $c,
      server_data => $ServerData,
    }, 'CurrentTest';
    $current->generate_id (app_id => {});
    Promise->resolve ($current)->then ($code)->finally (sub {
      return $current->close;
    })->catch (sub {
      my $e = $_[0];
      test {
        ok 0, 'Exception is thrown?';
        is $e, undef, 'No exception?';
      } $c, name => 'Test should not throw';
    })->finally (sub {
      done $c;
      undef $c;
    });
  } @_;
} # Test

push @EXPORT, qw(has_json_string);
sub has_json_string ($$;$) {
  my ($result, $key, $name) = @_;
  like $result->{res}->body_bytes, qr{"\Q$key\E"\s*:\s*"}, $name;
} # has_json_string

1;

=head1 LICENSE

Copyright 2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
