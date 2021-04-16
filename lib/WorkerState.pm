package WorkerState;
use strict;
use warnings;
use Path::Tiny;
use Time::HiRes qw(time);
use AbortController;
use Promise;
use Promised::Flow;
use JSON::PS;
use Dongry::Type;
use Dongry::Database;

use Application;

my $config_path = path ($ENV{APP_CONFIG} // die "No |APP_CONFIG|");
my $Config = json_bytes2perl $config_path->slurp;

sub start ($%) {
  my ($class, %args) = @_;
  my ($r, $s) = promised_cv;

  my $obj = {config => $Config, clients => {}, dbs => {}};
  $obj->{dbs}->{main} ||= Dongry::Database->new (
    sources => {
      master => {
        dsn => Dongry::Type->serialize ('text', $obj->{config}->{dsn}),
        writable => 1, anyevent => 1,
      },
    },
  );
  
  my $ac = new AbortController;
  my $t = $class->run_jobs ($obj, signal => $ac->signal)->catch (sub { });
  $args{signal}->manakai_onabort (sub {
    $ac->abort;
    return $t->then (sub {
      return Promise->all ([
        (map { $_->close } values %{$obj->{clients}}),
        (map { $_->disconnect } values %{$obj->{dbs}}),
      ]);
    })->finally ($s);
  });
  return [$obj, $r];
} # start

my $JobSleep1 = $Config->{fetch_job_interval} || 30;
my $JobSleep2 = $Config->{fetch_job_sleep} || 60;
sub run_jobs ($$%) {
  my ($class, $obj, %args) = @_;
  my $ac1 = new AbortController;
  my $ac2 = new AbortController;
  $args{signal}->manakai_onabort (sub {
    $ac1->abort;
    $ac2->abort;
  });
  return promised_wait_until {
    return promised_sleep (rand ($JobSleep1), signal => $ac1->signal)->then (sub {
      return $class->run_a_job ($obj);
    })->then (sub {
      my $job_found = shift;
      if ($job_found) {
        return promised_sleep ($JobSleep1, signal => $ac1->signal)->then (sub {
          return not 'done';
        });
      }
      return $obj->{dbs}->{main}->delete ('fetch_job', {
        expires => {'<', time},
      })->then (sub {
        return promised_sleep ($JobSleep2, signal => $ac1->signal)->then (sub { return not 'done' });
      });
    }, sub {
      my $e = $_[0];
      Application->error_log ($obj->{config}, 'important', $e)
          unless UNIVERSAL::can ($e, 'name') and $e->name eq 'AbortError';
      return not 'done';
    });
  } signal => $ac2->signal;
} # run_jobs

my $FetchJobTimeout = 60*5;
sub run_a_job ($$) {
  my ($class, $obj) = @_;
  my $db = $obj->{dbs}->{main};

  my $now = time;
  return $db->update ('fetch_job', {
    running_since => $now,
  }, where => {
    run_after => {'<=' => $now},
    running_since => {'<', $now - $FetchJobTimeout},
  }, limit => 1, order => [
    'run_after', 'asc', 'running_since', 'asc', 'inserted', 'asc',
  ])->then (sub {
    return $db->select ('fetch_job', {
      running_since => $now,
    }, fields => ['origin'], source_name => 'master', limit => 1);
  })->then (sub {
    my $v = $_[0]->first;
    return not 'job found' unless defined $v;
    return $db->update ('fetch_job', {
      running_since => $now,
    }, where => {
      run_after => {'<=' => $now},
      running_since => {'<', $now - $FetchJobTimeout},
      origin => $v->{origin},
    }, limit => 10, order => [
      'run_after', 'asc', 'running_since', 'asc', 'inserted', 'asc',
    ])->then (sub {
      return $db->select ('fetch_job', {
        running_since => $now,
      }, fields => ['job_id', 'options'], source_name => 'master',
      limit => 10);
    })->then (sub {
      my $jobs = $_[0]->all;
      return promised_for {
        my $job = shift;
        $job->{options} = Dongry::Type->parse ('json', $job->{options});
        return Application->run_fetch_job ($obj, $job)->then (sub {
          return $db->delete ('fetch_job', {
            job_id => $job->{job_id},
          });
        });
      } $jobs;
    })->then (sub {
      return 'job found';
    });
  });
} # run_a_job

1;

=head1 LICENSE

Copyright 2019-2021 Wakaba <wakaba@suikawiki.org>.

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
