use Test::More tests => 5;

use_ok('FirePHP::Dispatcher');
use_ok('FirePHP::LogConnector');
use_ok('FirePHP::LogConnector::Null');

SKIP: {
  eval { require Log::Log4perl };
  skip "Log::Log4perl not installed", 2 if $@;
  use_ok('FirePHP::Log4perl::Appender');
  use_ok('FirePHP::Log4perl::Layout');
}
