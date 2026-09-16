use strict;
use warnings;
use Path::Tiny;
use Test::More;
use Promise;
use Dongry::Database;
use Application;

# This standalone regression test truncates both notification tables.
# Only use a disposable database; never point it at a shared environment.
my $dsn = $ENV{APPLOACH_LOCK_TEST_DSN} // die 'APPLOACH_LOCK_TEST_DSN is required';
die 'Use the isolated apploach_lock_test database'
    unless $dsn =~ /dbname=apploach_lock_test(?:;|$)/;
my $root = path (__FILE__)->parent->parent->parent;
my $db = Dongry::Database->new (
  sources => {master => {dsn => $dsn, anyevent => 1, writable => 1}},
  master_only => 1, onerror => sub {},
);
sub await_result { Promise->resolve ($_[0])->to_cv->recv }
my $schema = $root->child ('db/apploach.sql')->slurp;
for my $table (qw(nevent nevent_queue)) {
  my ($sql) = $schema =~ /(create table if not exists `$table` \([\s\S]*?engine=innodb;)/;
  die "No schema for $table" unless defined $sql;
  await_result ($db->execute ($sql));
}

sub seed {
  my ($rows) = @_;
  await_result ($db->execute ('TRUNCATE TABLE nevent_queue'));
  await_result ($db->execute ('TRUNCATE TABLE nevent'));
  for my $row (@$rows) {
    my %key = (app_id => $row->{app} // 1, nevent_id => $row->{id},
               subscriber_nobj_id => $row->{subscriber} // 8);
    await_result ($db->insert ('nevent', [{
      %key, topic_nobj_id => 7, unique_nevent_key => 'synthetic-' . $row->{id},
      data => '{"synthetic":true}', timestamp => $row->{timestamp} // 100,
      expires => $row->{expires} // 2000000000,
    }]));
    await_result ($db->insert ('nevent_queue', [{
      %key, channel_nobj_id => $row->{channel} // 2,
      topic_subscription_data => '{"setting":1}', result_data => '{}',
      result_done => $row->{done} // 0, locked => $row->{locked} // 0,
      timestamp => $row->{timestamp} // 100, expires => $row->{expires} // 2000000000,
    }]));
  }
}

seed ([{id => 10, locked => 1788698100}]);
my ($migration) = $schema =~ /(alter table `nevent_queue`[\s\S]*?;)/;
die 'No lock identity migration' unless defined $migration;
my $column = await_result ($db->execute (q{SHOW COLUMNS FROM nevent_queue LIKE 'lock_id'}))->first;
await_result ($db->execute ($migration)) unless $column;
my $migrated = await_result ($db->select ('nevent_queue', {nevent_id => 10}))->first;
is $migrated->{locked}, 1788698100, 'migration preserves the existing lease timestamp';
is $migrated->{lock_id}, 0, 'existing queue rows have no claim identity';

{
  package LockIdentityApp;
  our @ISA = qw(Application);
  sub replace_nobj_ids { Promise->resolve ($_[1]) }
  package LockIdentityChannel;
  sub to_columns { ($_[1] . '_nobj_id' => $_[0]->{id}) }
}
my $app = bless {db => $db, app_id => 1}, 'LockIdentityApp';
my $channel1 = bless {id => 2}, 'LockIdentityChannel';
my $channel2 = bless {id => 3}, 'LockIdentityChannel';
my $subscriber = bless {id => 9}, 'LockIdentityChannel';
my $clock = 1788698144.123451;
{
  no warnings 'redefine';
  local *Application::time = sub { $clock };

  seed ([{id => 10}, {id => 11, channel => 3}]);
  my $first = await_result ($app->lock_queued_nevent ($channel1, 1));
  is_deeply [map { $_->{nevent_id} } @$first], [10], 'first channel claims its own notification';
  my $old_clock = $clock;
  $clock = 1788698144.123452;
  cmp_ok $old_clock, '<', $clock, 'clock readings differ';
  is "$old_clock", "$clock", 'decimal representation can still collide';
  my $second = await_result ($app->lock_queued_nevent ($channel2, 1));
  is_deeply [map { $_->{nevent_id} } @$second], [11], 'colliding timestamp cannot mix channels';
  is $second->[0]->{topic_subscription_data}, '{"setting":1}', 'subscription data is unchanged';
  is $second->[0]->{data}, '{"synthetic":true}', 'notification data is unchanged';
  ok !exists $second->[0]->{lock_id}, 'claim identity is not an API response field';

  seed ([{id => 10}, {id => 11}]);
  $first = await_result ($app->lock_queued_nevent ($channel1, 1));
  await_result ($db->update ('nevent_queue', {result_done => 1}, where => {
    app_id => 1, nevent_id => $first->[0]->{nevent_id}, subscriber_nobj_id => 8, channel_nobj_id => 2,
  }));
  $second = await_result ($app->lock_queued_nevent ($channel1, 1));
  is scalar @$second, 1, 'second batch respects the limit at the exact same time';
  isnt $first->[0]->{nevent_id}, $second->[0]->{nevent_id}, 'completed first batch is not returned again';
  is_deeply await_result ($app->lock_queued_nevent ($channel1, 1)), [], 'exhausted queue remains empty';

  seed ([{id => 10}]);
  $clock = 1788698200;
  $first = await_result ($app->lock_queued_nevent ($channel1, 1));
  $clock += 600;
  is_deeply await_result ($app->lock_queued_nevent ($channel1, 1)), [], 'lease is not released at the existing strict 600-second boundary';
  $clock += 0.001;
  $second = await_result ($app->lock_queued_nevent ($channel1, 1));
  is_deeply [map { $_->{nevent_id} } @$second], [10], 'expired unfinished notification is reclaimable';

  seed ([{id => 10, app => 2}, {id => 11, subscriber => 9}, {id => 12},
         {id => 13, subscriber => 9, done => 1},
         {id => 14, subscriber => 9, timestamp => $clock + 1},
         {id => 15, subscriber => 9, expires => $clock}]);
  $first = await_result ($app->lock_queued_nevent ($channel1, 10, subscriber => $subscriber));
  is_deeply [map { $_->{nevent_id} } @$first], [11], 'app, subscriber, future, expired and completed filters are retained';

  seed ([map { {id => $_, timestamp => $_} } 20..27]);
  my $batches = await_result (Promise->all ([map {
    $app->lock_queued_nevent ($channel1, 2);
  } 1..4]));
  is_deeply [map { scalar @$_ } @$batches], [2, 2, 2, 2], 'concurrent callers each obtain their own two rows';
  my @ids = map { map { $_->{nevent_id} } @$_ } @$batches;
  is_deeply [sort { $a <=> $b } @ids], [20..27], 'concurrent batches neither duplicate nor lose notifications';
  my $leases = await_result ($db->select ('nevent_queue', {app_id => 1}))->all;
  my %identities = map { $_->{lock_id} => 1 } @$leases;
  is scalar keys %identities, 4, 'four claims have distinct database-generated identities';

  seed ([map { {id => $_, timestamp => $_} } 30..37]);
  my @connections = map {
    Dongry::Database->new (
      sources => {master => {dsn => $dsn, anyevent => 1, writable => 1}},
      master_only => 1, onerror => sub {},
    );
  } 1..4;
  my @apps = map { bless {db => $_, app_id => 1}, 'LockIdentityApp' } @connections;
  $batches = await_result (Promise->all ([map {
    $_->lock_queued_nevent ($channel1, 2);
  } @apps]));
  is_deeply [map { scalar @$_ } @$batches], [2, 2, 2, 2], 'independent DB connections each claim two notifications';
  @ids = map { map { $_->{nevent_id} } @$_ } @$batches;
  is_deeply [sort { $a <=> $b } @ids], [30..37], 'independent connections neither duplicate nor lose notifications';
  await_result (Promise->all ([map { $_->disconnect } @connections]));
}

await_result ($db->disconnect);
undef $app;
undef $db;
done_testing;

=head1 実行方法

依存関係を準備したリポジトリのルートから実行します。
使い捨ての MySQL に空の C<apploach_lock_test> データベースを作り、
その接続先だけを C<APPLOACH_LOCK_TEST_DSN> に指定してください。

  APPLOACH_LOCK_TEST_DSN='dbi:mysql:dbname=apploach_lock_test;host=127.0.0.1;port=3306;user=test' \
    ./perl -Ilib t_deps/bin/nevent-lock-identity-test.pl

この検査は C<nevent> と C<nevent_queue> を作成し、各ケースで両テーブルを
TRUNCATE します。共有 DB や本番 DB では実行しないでください。
DB 名の検査は接続先の安全性を保証するものではありません。
実行後は使い捨て DB 自体を破棄してください。

時計だけを固定し、実際の C<Application::lock_queued_nevent> と
C<ids>、実 DB 接続を使います。通知オブジェクト名への変換は stub です。
既存の C<t/http/*.t> とは別の検査で、通常の CI にはまだ組み込んでいません。

=cut
