use strict;
use warnings;
use Web::URL;
use Web::Transport::BasicClient;
use Promise;
use Promised::Flow;

my $origin = q<http://0:6315>;

sub send_push () {
my $url = Web::URL->parse_string ($origin);
my $client = Web::Transport::BasicClient->new_from_url ($url);
return $client->request (
  method => 'POST',
  path => ['32543', 'notification', 'send', 'push.json'],
  bearer => "wpD5ZCEe3EJ8T7w5QUoC0AL3evtAgh",
  params => {
    url => q<https://suikawiki.org/>,
  },
)->then (sub {
  my $res = $_[0];
  warn $res;
})->finally (sub {
  return $client->close;
});
} # send_push

my $i = 0;
Promise->resolve->then (sub {
  return promised_wait_until {
    return send_push->then (sub {
      return $i++ > 100;
    });
  };
})->to_cv->recv;
