use strict;
use FindBin;
use lib glob "$FindBin::Bin/../modules/*/lib";
use lib glob "$FindBin::Bin/../t_deps/modules/*/lib";
use lib "$FindBin::Bin/../lib";
use warnings;
use Path::Tiny;
use Test::More;
use Promise;
use Dongry::Database;

my $source = path (@ARGV ? shift : "$FindBin::Bin/../lib/Application.pm")->slurp;
my ($helper) = $source =~ /(sub _message_status_transaction \(\$\$\$\).*?\n\} # _message_status_transaction)/s;
die 'Missing candidate helper' unless defined $helper;
eval "package SMSBoundaries; use Promise; $helper";
die $@ if $@;
sub sql_error {
  return bless {error_text => "Artificial failure (Error code $_[0])"},
      'Dongry::Database::Executed::NotAvailable';
}
{
  package SMSBoundaryDB;
  sub transaction {
    my $self = shift;
    push @{$self->{calls}}, 'begin';
    return Promise->reject ($self->{begin_error}) if $self->{begin_error};
    return Promise->resolve ($self);
  }
  sub commit {
    my $self = shift;
    push @{$self->{calls}}, 'commit';
    return Promise->reject ($self->{commit_error}) if $self->{commit_error};
    return Promise->resolve ('committed');
  }
  sub rollback {
    my $self = shift;
    push @{$self->{calls}}, 'rollback';
    return Promise->reject ($self->{rollback_error}) if $self->{rollback_error};
    return Promise->resolve;
  }
}
sub run_case {
  my ($errors, %args) = @_;
  my $db = bless {calls => [], errors => $errors, %args}, 'SMSBoundaryDB';
  my ($result, $error);
  SMSBoundaries::_message_status_transaction ($db, sub {
    push @{$db->{calls}}, 'work';
    die $db->{sync_error} if defined $db->{sync_error};
    my $failure = shift @{$db->{errors}};
    return defined $failure ? Promise->reject ($failure) : Promise->resolve ('updated');
  }, 2)->then (sub {$result = $_[0]}, sub {$error = $_[0]})->to_cv->recv;
  return ($db, $result, $error);
}
my ($db, $result, $error) = run_case ([]);
is $result, 'committed', 'normal operation commits once';
is_deeply $db->{calls}, [qw(begin work commit)], 'normal transaction order is unchanged';
($db, $result, $error) = run_case ([sql_error (1213)]);
is $result, 'committed', 'confirmed deadlock is recovered';
is_deeply $db->{calls}, [qw(begin work rollback begin work commit)],
    'rollback finishes before the whole database operation is re-evaluated';
my $deadlock = sql_error (1213);
($db, $result, $error) = run_case ([$deadlock, $deadlock, $deadlock]);
is $error, $deadlock, 'exhaustion propagates the original typed failure';
is_deeply $db->{calls}, [(qw(begin work rollback)) x 3], 'only three attempts are allowed';
for my $failure ((map {sql_error ($_)} 1205, 1062, 2006, 2013), "HTTP failure (Error code 1213)\n") {
  ($db, $result, $error) = run_case ([$failure]);
  is $error, $failure, 'other failures propagate unchanged';
  is_deeply $db->{calls}, [qw(begin work rollback)],
      'timeouts, duplicates, connection failures and untyped strings cannot repeat';
}
for my $phase (qw(begin commit rollback)) {
  my $failure = sql_error (1213);
  ($db, $result, $error) = run_case ($phase eq 'rollback' ? [sql_error (1213)] : [],
      $phase.'_error' => $failure);
  is $error, $failure, "$phase errors propagate unchanged";
  is scalar (grep {$_ eq 'begin'} @{$db->{calls}}), 1,
      "$phase errors cannot start another transaction";
}
($db, $result, $error) = run_case ([], sync_error => 'synchronous failure');
like "$error", qr/synchronous failure/, 'synchronous errors retain their reason';
is_deeply $db->{calls}, [qw(begin work rollback)], 'synchronous errors are rolled back, not repeated';
is scalar (() = $source =~ /return _message_status_transaction \(\$db, sub \{/g), 2,
    'only response and callback status bookkeeping use the helper';
unlike $helper, qr/SET TRANSACTION|SET SESSION|request\s*\(|sleep|ENV\{CI\}/,
    'isolation, HTTP transmission and CI policy are unchanged';
my ($fetch) = $source =~ /(sub run_fetch_job \(\$\$\$\$\).*?\n\} # run_fetch_job)/s;
if (defined $fetch) {
  is scalar (() = $fetch =~ /\$client->request \(/g), 1, 'fetch retains one outbound request';
  like $fetch, qr/\$client->request \([\s\S]+\$result->\{time\} = \$now;\s+return _message_status_transaction/,
      'response and timestamp are captured before database recovery begins';
  like $fetch, qr/my \$tr = \$_\[0\];\s+delete \$ret->\{retry_after\};/,
      'a fresh state read also clears a stale failed-attempt retry decision';
}
my ($stats) = $source =~ /(sub update_request_set_stats \(\$\$\$\$\$\).*?\n\} # update_request_set_stats)/s;
die 'Missing statistics method' unless defined $stats;
eval "package SMSBoundaries; $stats";
die $@ if $@;
{
  package SMSStatsRows;
  sub all { $_[0]->{rows} }
  package SMSStatsDB;
  sub select {
    my ($self, @args) = @_;
    push @{$self->{calls}}, ['select', @args];
    return Promise->resolve;
  }
  sub execute {
    my ($self, @args) = @_;
    push @{$self->{calls}}, ['execute', @args];
    return Promise->resolve (bless {rows => $self->{rows}}, 'SMSStatsRows');
  }
  sub update {
    my ($self, @args) = @_;
    push @{$self->{calls}}, ['update', @args];
    return Promise->resolve ('statistics updated');
  }
}
for my $rows ([], [{status => 2, item_count => 3}, {status => 4, item_count => 5},
                   {status => 9, item_count => 2}, {status => 1, item_count => 99}]) {
  my $db = bless {rows => $rows, calls => []}, 'SMSStatsDB';
  my $result = SMSBoundaries->update_request_set_stats ($db, 11, 22, 33)->to_cv->recv;
  is $result, 'statistics updated', 'returns the database update result';
  is_deeply [map {$_->[0]} @{$db->{calls}}], [qw(select execute update)],
      'locks the target aggregate row before creating the count snapshot';
  is_deeply $db->{calls}->[0], ['select', 'request_set', {app_id => 11, request_set_id => 22},
                              fields => ['request_set_id'], lock => 'update'],
      'serializes only the same request set, within the existing transaction';
  like $db->{calls}->[1]->[1], qr/^\s*select status, count\(\*\) as item_count from request_status\s+where app_id = :app_id and request_set_id = :request_set_id\s+group by status\s*$/,
      'counts through a plain consistent read, not a locking update subquery';
  is_deeply $db->{calls}->[1]->[2], {app_id => 11, request_set_id => 22},
      'the snapshot uses the same app and request-set scope';
  my $expected = {map {('status_'.$_.'_count' => 0)} 2..9};
  if (@$rows) { @{$expected}{qw(status_2_count status_4_count status_9_count)} = (3,5,2) }
  is_deeply $db->{calls}->[2], ['update', 'request_set', {%$expected, updated => 33},
                              where => {app_id => 11, request_set_id => 22}],
      'preserves all eight counters, zeros and the original update timestamp';
}
unlike $stats, qr/transaction\s*\(|commit|rollback|ENV\{|sleep|request\s*\(/,
    'statistics neither change transaction boundaries nor repeat HTTP work';
done_testing;
