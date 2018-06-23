use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->json (['nobj', 'signedstorageurl.json'], {
    url => [
      $current->generate_text (t1 => {}),
      rand,
      '',
      53262352233,
      'mailto:' . rand,
      'ftp://gaw.egaw.test/533535',
      'http://hoge.fuga.test/aegfwee',
      'https://hoge.fuga.test/aegfwee',
    ],
  })->then (sub {
    my $result = $_[0];
    test {
      is 0+keys %{$result->{json}}, 0;
    } $current->c;
  });
} n => 1, name => 'bad values';

Test {
  my $current = shift;
  return Promise->resolve->then (sub {
    return $current->json (['nobj', 'attachform.json'], {
      target_nobj_key => rand,
      path_prefix => '/abc/DEF24t224',
      mime_type => 'application/octet-stream',
      byte_length => length ($current->generate_key (k1 => {})),
    });
  })->then (sub {
    my $result = $_[0];
    $current->set_o (file1 => $result->{json}->{file});
    my $url = Web::URL->parse_string ($result->{json}->{form_url});
    return $current->client_for ($url)->request (
      url => $url,
      method => 'POST',
      params => $result->{json}->{form_data},
      files => {
        file => {body_ref => \($current->o ('k1')), mime_filename => rand},
      },
    );
  })->then (sub {
    my $res = $_[0];
    die $res unless $res->is_success;
    return $current->json (['nobj', 'signedstorageurl.json'], {
      url => [
        $current->o ('file1')->{file_url},
      ],
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{$current->o ('file1')->{file_url}};
    } $current->c;
    my $url = Web::URL->parse_string ($result->{json}->{$current->o ('file1')->{file_url}});
    return $current->client_for ($url)->request (url => $url);
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->status, 200;
      is $res->header ('content-type'), 'application/octet-stream';
      is $res->body_bytes, $current->o ('k1');
    } $current->c, name => 'signed URL';
    return $current->json (['nobj', 'signedstorageurl.json'], {
      url => [
        $current->o ('file1')->{file_url},
      ],
      max_age => 2,
    });
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->{json}->{$current->o ('file1')->{file_url}};
    } $current->c;
    my $url = Web::URL->parse_string ($result->{json}->{$current->o ('file1')->{file_url}});
    return promised_sleep (5)->then (sub {
      return $current->client_for ($url)->request (url => $url);
    });
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->status, 403, 'timeout';
    } $current->c, name => 'signed URL';
  });
} n => 6, name => 'signed';

RUN;
