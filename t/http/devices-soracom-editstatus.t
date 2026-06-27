use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $imsi = '123456789012345';
  my $imei = '123456789012345';
  my $mode = 'activate';
  
  return $current->json (['devices', 'soracom', 'editstatus.json'], {
    imsi => $imsi,
    imei => $imei,
    mode => $mode,
    operator_nobj_key => 'test_op',
    verb_nobj_key => 'test_verb',
    target_nobj_key => 'test_target',
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->{json}->{imsi}, $imsi;
      ok $result->{json}->{log_id};
      like $result->{res}->body_bytes, qr{"log_id":"};
    } $current->c;
    
    return $current->json (['nobj', 'logs.json'], {
      target_nobj_key => 'test_target',
      verb_nobj_key => 'test_verb',
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $log = $result->{json}->{items}->[0];
      is $log->{data}->{imsi}, $imsi;
      is $log->{data}->{imei}, $imei;
      is $log->{data}->{mode}, $mode;
      is 0+@{$log->{data}->{responses}}, 3; 
      is $log->{data}->{responses}->[0]->{step}, 'get_subscriber';
      is $log->{data}->{responses}->[0]->{status}, 200;
      is $log->{data}->{responses}->[1]->{step}, 'verify_imei';
      is $log->{data}->{responses}->[1]->{status}, 200;
      is $log->{data}->{responses}->[2]->{step}, 'action';
      is $log->{data}->{responses}->[2]->{status}, 200;
    } $current->c;
  });
} n => 14, name => 'success (search second endpoint)';

Test {
  my $current = shift;
  return $current->are_errors (
    [['devices', 'soracom', 'editstatus.json'], {
      imsi => '123456789012345',
      imei => '123456789012345',
      mode => 'activate',
      operator_nobj_key => 'test_op',
      verb_nobj_key => 'test_verb',
      target_nobj_key => 'test_target',
    }],
    [
      {p => {imsi => undef}, reason => 'Bad |imsi|'},
      {p => {imsi => ''}, reason => 'Bad |imsi|'},
      {p => {imsi => 'abc'}, reason => 'Bad |imsi|'},
      {p => {imsi => '123'}, reason => 'Bad |imsi|'},
      {p => {imei => undef}, reason => 'Bad |imei|'},
      {p => {imei => ''}, reason => 'Bad |imei|'},
      {p => {mode => undef}, reason => 'Bad |mode|'},
      {p => {mode => 'invalid'}, reason => 'Bad |mode|'},
      ['new_nobj', 'operator'],
      ['new_nobj', 'verb'],
      ['new_nobj', 'target'],
    ],
    'invalid params',
  );
} n => 1, name => 'invalid params';

Test {
  my $current = shift;
  my $imsi = '222222222222222'; # IMEI mismatch in mock
  my $imei = '123456789012345';
  
  return $current->client->request (
    method => 'POST',
    path => [$current->o ('app_id'), 'devices', 'soracom', 'editstatus.json'],
    bearer => $current->bearer,
    params => {
      imsi => $imsi,
      imei => $imei,
      mode => 'activate',
      operator_nobj_key => 'test_op',
      verb_nobj_key => 'test_verb_mismatch',
      target_nobj_key => 'test_target_mismatch',
    },
  )->then (sub {
    my $res = $_[0];
    test {
      is $res->status, 400;
      my $json = json_bytes2perl $res->body_bytes;
      is $json->{reason}, 'IMEI_MISMATCH';
    } $current->c;

    return $current->json (['nobj', 'logs.json'], {
      target_nobj_key => 'test_target_mismatch',
      verb_nobj_key => 'test_verb_mismatch',
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      my $log = $result->{json}->{items}->[0];
      is $log->{data}->{imsi}, $imsi;
      is $log->{data}->{responses}->[-1]->{step}, 'verify_imei';
      is $log->{data}->{responses}->[-1]->{expected}, $imei;
      is $log->{data}->{responses}->[-1]->{actual}, 'mismatch_imei';
    } $current->c;
  });
} n => 7, name => 'IMEI mismatch';

Test {
  my $current = shift;
  my $imsi = '000000000000000'; # Not found in mock
  my $imei = '123456789012345';
  
  return $current->client->request (
    method => 'POST',
    path => [$current->o ('app_id'), 'devices', 'soracom', 'editstatus.json'],
    bearer => $current->bearer,
    params => {
      imsi => $imsi,
      imei => $imei,
      mode => 'activate',
      operator_nobj_key => 'test_op',
      verb_nobj_key => 'test_verb_nf',
      target_nobj_key => 'test_target_nf',
    },
  )->then (sub {
    my $res = $_[0];
    test {
      is $res->status, 400;
      my $json = json_bytes2perl $res->body_bytes;
      is $json->{reason}, 'SUBSCRIBER_NOT_FOUND_ANY_REGION';
    } $current->c;

    return $current->json (['nobj', 'logs.json'], {
      target_nobj_key => 'test_target_nf',
      verb_nobj_key => 'test_verb_nf',
    });
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+@{$result->{json}->{items}}, 1;
      is $result->{json}->{items}->[0]->{data}->{responses}->[-1]->{step}, 'get_subscriber';
    } $current->c;
  });
} n => 4, name => 'not found any region';

RUN;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

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
