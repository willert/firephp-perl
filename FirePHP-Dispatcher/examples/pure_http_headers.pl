#!/usr/bin/perl

use strict;
use warnings;

use HTTP::Headers;

my $http_headers = HTTP::Headers->new();

$http_headers->push_header(
  'X-Wf-Protocol-1'     => 'http://meta.wildfirehq.org/' .
    'Protocol/JsonStream/0.2',
  'X-Wf-1-Plugin-1'     => 'http://meta.firephp.org/' .
    'Wildfire/Plugin/FirePHP/Library-FirePHPCore/0.2.0',
  'X-Wf-1-Structure-1'  => 'http://meta.firephp.org/' .
    'Wildfire/Structure/FirePHP/FirebugConsole/0.1',
);

$http_headers->push_header(
  'X-Wf-1-1-1-1' => '30|[{"Type":"LOG"},"Hell|\\',
  'X-Wf-1-1-1-2' => '|o Wo|\\',
  'X-Wf-1-1-1-3' => '|rld"]|',
);

$http_headers->push_header(
  'X-Wf-1-1-1-4' => '43|[{"Type":"GROUP_START","Label":"Foo"},null]|',
);

$http_headers->push_header(
  'X-Wf-1-1-1-6' => '33|[{"Type":"LOG"},"Hell|\\',
  'X-Wf-1-1-1-7' => '|o Wo|\\',
  'X-Wf-1-1-1-8' => '|rld!!!"]|',
);

$http_headers->push_header(
  'X-Wf-1-1-1-9' => '33|[{"Type":"LOG"},"Hell|\\',
  'X-Wf-1-1-1-10' => '|o again!!!"]|',
);

$http_headers->header(
  'X-Wf-1-1-1-11' => '27|[{"Type":"GROUP_END"},null]|',
);

$http_headers->header(
  'X-Wf-1-Structure-2'  => 'http://meta.firephp.org/' .
    'Wildfire/Structure/FirePHP/Dump/0.1',
);

$http_headers->push_header(
  'X-Wf-1-2-1-12' => '24|{"Dump":{"i":10,"j":20}}|',
);

$http_headers->header('X-Wf-1-Index', 12 );
