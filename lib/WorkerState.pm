package WorkerState;
use strict;
use warnings;
use Promise;
use Promised::Flow;

sub start ($%) {
  my ($class, %args) = @_;
  my ($r, $s) = promised_cv;
  my $obj = {clients => {}, dbs => {}};
  $args{signal}->manakai_onabort (sub {
    return Promise->all ([
      (map { $_->close } values %{$obj->{clients}}),
      (map { $_->disconnect } values %{$obj->{dbs}}),
    ])->finally ($s);
  });
  return [$obj, $r];
} # start

1;
