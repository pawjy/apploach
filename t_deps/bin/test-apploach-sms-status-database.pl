use strict;
use warnings;
use Path::Tiny;
use Test::More;
use Promise;
use Dongry::Database;
use Dongry::Type::JSONPS;
use JSON::PS;
use Web::URL;
use Web::Transport::Base64;

# Run inside the built Apploach image against a new empty disposable database.
# Arguments: Application.pm apploach.sql host port database fetch|callback
my ($source_path, $schema_path, $host, $port, $name, $mode) = @ARGV;
die 'Source, schema and a new disposable database are required' unless @ARGV == 6 &&
    $host =~ /\A[a-zA-Z0-9.-]+\z/ && $port =~ /\A[0-9]+\z/ &&
    $name =~ /\Arabbit_sms_status_test_[a-z0-9_]+\z/ &&
    $mode =~ /\A(?:fetch|callback)\z/;
my $callback = $mode eq 'callback';
alarm 120;
my $source = path ($source_path)->slurp;
my ($fetch) = $source =~ /(sub run_fetch_job \(\$\$\$\$\).*?\n\} # run_fetch_job)/s;
my ($stats) = $source =~ /(sub update_request_set_stats \(\$\$\$\$\$\).*?\n\} # update_request_set_stats)/s;
my ($callback_code) = $source =~ /(sub run_fetch_callback_job \(\$\$\$\$\).*?\n\} # run_fetch_callback_job)/s;
die 'Missing runtime methods' unless defined $fetch && defined $stats && defined $callback_code;
my ($helper) = $source =~ /(sub _message_status_transaction \(\$\$\$\).*?\n\} # _message_status_transaction)/s;
my $candidate = defined $helper;
my $snapshot_counts = $stats =~ /group by status/;
$helper //= '';
eval "package SMSFetchProbe; use Promise; use JSON::PS; use Web::Transport::Base64; $helper\n$fetch\n$callback_code\n$stats";
die $@ if $@;
sub await_result { Promise->resolve ($_[0])->to_cv->recv }
sub database {
  return Dongry::Database->new (
    sources => {master => {
      dsn => "dbi:mysql:dbname=$name;host=$host;port=$port;user=root",
      anyevent => 1, writable => 1,
    }}, master_only => 1, onerror => sub {},
  );
}
{
  package SMSFetchProbe;
  sub error_log {
    my ($class, $config, $important, $error) = @_;
    my ($code) = "$error" =~ /\(Error code (\d+)\)/;
    push @{$config->{errors}}, {code => $code // 0, important => !!$important};
  }
  package SMSProbeResponse;
  sub status { 200 }
  sub header { undef }
  package SMSProbeClient;
  sub request {
    my ($self, %args) = @_;
    $self->{calls}++;
    die 'Unexpected request' unless $args{method} eq 'POST';
    return Promise->resolve (bless {}, 'SMSProbeResponse');
  }
  package SMSProbeDB;
  sub transaction {
    my $self = shift;
    $self->{attempts}++;
    return $self->{db}->transaction->then (sub {
      return bless {tr => $_[0], barrier => $self->{barrier}}, 'SMSProbeTransaction';
    });
  }
  package SMSProbeTransaction;
  sub select { my $self = shift; $self->{tr}->select (@_) }
  sub update {
    my ($self, @args) = @_;
    return $self->{tr}->update (@args)->then (sub {
      my $result = $_[0];
      return $result unless $args[0] eq 'request_status';
      return $self->{barrier}->()->then (sub { return $result });
    });
  }
  sub execute { my $self = shift; $self->{tr}->execute (@_) }
  sub commit { my $self = shift; $self->{tr}->commit (@_) }
  sub rollback { my $self = shift; $self->{tr}->rollback (@_) }
}
my $db = database;
die 'Private database is not empty' if await_result ($db->execute ('SHOW TABLES'))->row_count;
my $version = await_result ($db->execute ('SELECT VERSION() AS version, @@tx_isolation AS isolation'))->first;
diag "private_db_version=$version->{version} isolation=$version->{isolation}";
my $schema = path ($schema_path)->slurp;
for my $table_name (qw(request_status request_set)) {
  my ($table) = $schema =~ /(create table if not exists `$table_name` \([\s\S]*?engine=innodb;)/i;
  die 'Missing schema' unless defined $table;
  await_result ($db->execute ($table));
  while ($schema =~ /(alter table `$table_name`\s[\s\S]*?;)/ig) {
    await_result ($db->execute ($1));
  }
}
for my $separate (0, 1) {
  for my $round (1..3) {
    await_result ($db->execute ('TRUNCATE TABLE request_status'));
    await_result ($db->execute ('TRUNCATE TABLE request_set'));
    await_result ($db->insert ('request_status', [map {+{
      app_id => 1, request_set_id => 1000 + ($separate ? $_ : 0),
      request_id => 101+$_, station_nobj_id => 500+($separate ? $_ : 0),
      request_data => '{}', response_log => '{"items":[]}', callback_log => '{"items":[]}',
      status => ($callback ? 4 : 2), created => 1, updated => 1, expires => 2000000000,
    }} (0, 1)]));
    await_result ($db->insert ('request_set', [map {+{
      app_id => 1, request_set_id => 1000+$_, station_nobj_id => 500+$_,
      data => '{}', created => 1, updated => 1, size_for_cost => 1,
      (map {('status_'.$_.'_count' => ($_ == ($callback ? 4 : 2) ? ($separate ? 1 : 2) : 0))} 2..9),
    }} (0..($separate ? 1 : 0))]));
    my ($release, $ready);
    $ready = 0;
    my $barrier = Promise->new (sub { ($release) = @_ });
    my @connections;
    my @clients;
    my @errors;
    my @observed;
    my @runs = map {
      my $slot = $_;
      my $connection = database;
      push @connections, $connection;
      await_result ($connection->execute ('SET SESSION innodb_lock_wait_timeout=5'));
      my $client = bless {calls => 0}, 'SMSProbeClient';
      push @clients, $client;
      my $observed = bless {db => $connection, barrier => sub {
        $release->() if ++$ready == 2;
        return $barrier;
      }}, 'SMSProbeDB';
      push @observed, $observed;
      my $errors = [];
      push @errors, $errors;
      my $obj = {
        clients => {'http://sms.invalid' => $client}, config => {errors => $errors},
      };
      my $job = {
        app_id => 1, options => {
          url => 'http://sms.invalid/send', method => 'POST',
          request_id => 101+$slot, name => 'private-sms-fetch',
          json => {to => 'artificial-'.$slot, text => 'private test'},
          callback_channel => 'vonage',
          callback_body => encode_web_base64 (perl2json_bytes {
            client_ref => 'r'.(101+$slot), status => 'delivered',
          }),
        },
      };
      $callback ? SMSFetchProbe->run_fetch_callback_job ($obj, $job, $observed)
          : SMSFetchProbe->run_fetch_job ($obj, $job, $observed);
    } (0, 1);
    my $outcomes = await_result (Promise->all (\@runs));
    my @codes = map {map {$_->{code}} @$_} @errors;
    my $rows = await_result ($db->select ('request_status', {app_id => 1}))->all;
    my @statuses = sort map {$_->{status}} @$rows;
    my $sets = await_result ($db->select ('request_set', {app_id => 1}))->all;
    my $counted = 0;
    $counted += $_->{'status_'.($callback ? 6 : 4).'_count'} for @$sets;
    diag 'separate_sets='.$separate.' callback='.!!$callback.' round='.$round.' errors='.join(',',@codes).
        ' statuses='.join(',',@statuses).' counted='.$counted;
    is_deeply [map {$_->{calls}} @clients], ($callback ? [0,0] : [1,1]), 'no HTTP request is replayed';
    is_deeply $outcomes, [{},{}], 'existing method resolves without asking for a job retry';
    is_deeply \@codes, ($candidate ? [] : [1213]), 'candidate completes without logged database failures';
    is_deeply \@statuses, ($callback ? ($candidate ? [6,6] : [4,6]) : ($candidate ? [4,4] : [2,4])),
        'both request states finish with the protected update path';
    is $counted, ($candidate ? 2 : 1), 'completed count agrees with committed updates';
    if ($candidate) {
      is_deeply [sort map {$_->{attempts}} @observed], ($snapshot_counts ? [1,1] : [1,2]),
          'snapshot aggregation avoids the deadlock without another transaction';
      is_deeply [map {scalar @{JSON::PS::json_bytes2perl($_->{$callback ? 'callback_log' : 'response_log'})->{items}}} @$rows],
          [1,1], 'each response is logged exactly once after commit';
      is await_result ($connections[0]->execute ('SELECT @@tx_isolation AS v'))->first->{v},
          'REPEATABLE-READ', 'transaction isolation remains unchanged';
    }
    await_result ($_ ->disconnect) for @connections;
  }
}
undef $version;
await_result ($db->disconnect);
done_testing;
