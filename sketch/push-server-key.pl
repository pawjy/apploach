use strict;
use warnings;
use Web::Transport::PKI::Generator;
use Web::Transport::Base64;

my $gen = Web::Transport::PKI::Generator->new;

$gen->create_ec_key (curve => 'prime256v1')->then (sub {
  my $key = $_[0];

  my $private_key = $key->to_pem;
  $private_key = $1 if $private_key =~ /--([^-]+)-+END/;
  $private_key = decode_web_base64 $private_key;
  warn join ',', map { ord $_ } split //, $private_key;

  return $gen->create_certificate (ca_ec => $key, ec => $key);
})->then (sub {
  my $cert = $_[0];

  my $pub_key = $cert->{parsed}->{tbsCertificate}->{subjectPublicKeyInfo}->{subjectPublicKey}->[1];
  warn join ',', map { ord $_ } split //, $pub_key;

})->to_cv->recv;
