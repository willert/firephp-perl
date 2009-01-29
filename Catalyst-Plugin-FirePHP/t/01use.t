use Test::More tests => 4;

use_ok('Catalyst::Plugin::FirePHP');
use_ok('FirePHP::LogConnector::Catalyst');
use_ok('FirePHP::LogConnector::Catalyst::Log');

SKIP: {
  eval { require Log::Log4perl };
  skip "Log::Log4perl not installed", 1 if $@;
  use_ok('FirePHP::LogConnector::Catalyst::Log::Log4perl');
}
