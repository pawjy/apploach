package Migration;
use strict;
use warnings;
use Time::HiRes qw(time);
use Promise;
use Promised::Flow;
use Dongry::Database;

sub run ($$$;%) {
  my ($class, $sqls, $dsn, %args) = @_;
  my $db = Dongry::Database->new (
    sources => {
      master => {dsn => $dsn, writable => 1, anyevent => 1},
    },
  );
  return Promise->resolve->then (sub {
    $sqls =~ s/--.*$//gm;
    my @sql = grep { length } map { s/^\s+//; s/\s+$//; $_ } split /;/, $sqls;
    return unless @sql;

    $db->execute ('select * from mysql.user', {}, source_name => 'master')->then (sub {


                                                                                    use Data::Dumper;
                                                                                    warn Dumper $_[0]->all->to_a;

                                                                                  });
    
    my $done = {};
    return $db->execute (q{
      create table `__migration` (
        `sql` varbinary(2048) not null,
        `timestamp` double not null,
        primary key (`sql`),
        key (`timestamp`)
      ) default charset=binary engine=innodb
    }, undef, source_name => 'master')->then (sub {
      return $db->select ('__migration', {
        sql => {-in => \@sql},
      }, fields => ['sql'], source_name => 'master');
    })->then (sub {
      $done->{$_->{sql}} = 1 for @{$_[0]->all};
      return promised_for {
        my $sql = shift;
        return $db->transaction->then (sub {
          my $tr = $_[0];
          return Promise->resolve->then (sub {
            return $tr->execute ($sql, undef, source_name => 'master');
          })->then (sub {
            return $tr->insert ('__migration', [{
              sql => $sql,
              timestamp => time,
            }], source_name => 'master');
          })->then (sub {
            return $tr->commit;
            ## Note that `create` statements are not rollbacked by failure.
          });
        });
      } [grep { not $done->{$_} } @sql];
    });
  })->then (sub {
    return undef unless $args{dump};
    return $db->execute ('show tables', undef, source_name => 'master')->then (sub {
      return promised_map {
        my $name = $_[0];
        return $db->execute ('show create table :name:id', {name => $name}, source_name => 'master')->then (sub {
          my $w = $_[0]->first;
          return $w->{'Create Table'};
        });
      } [sort { $a cmp $b } map { [values %$_]->[0] } @{$_[0]->all}];
    })->then (sub {
      return join ";\x0A\x0A", @{$_[0]};
    });
  })->finally (sub {
    return $db->disconnect;
  });
} # run

1;

=head1 LICENSE

Copyright 2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
