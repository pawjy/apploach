package CurrentTest;
use strict;
use warnings;
use Web::URL;
use Web::Transport::ENVProxyManager;
use Web::Transport::BasicClient;

sub c ($) {
  return $_[0]->{c};
} # c

sub url ($$) {
  my ($self, $rel) = @_;
  return Web::URL->parse_string ($rel, $self->{server_data}->{app_client_url});
} # url

sub client ($) {
  my ($self) = @_;
  $self->{client} ||= Web::Transport::BasicClient->new_from_url ($self->url ('/'), {
    proxy_manager => Web::Transport::ENVProxyManager->new_from_envs ($self->{server_data}->{local_envs}),
  });
} # client

sub close ($) {
  my $self = $_[0];
  return Promise->all ([
    defined $self->{client} ? $self->{client}->close : undef,
  ]);
} # close

1;
