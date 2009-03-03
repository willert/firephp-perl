use inc::Module::Install 0.70;
use version;

name 'Catalyst-Plugin-FirePHP';
all_from 'lib/Catalyst/Plugin/FirePHP.pm';

requires 'FirePHP::Dispatcher' => '0.02';

# these are provided by 'FirePHP::Dispatcher' and just
# noted here to keep Test::Prereq happy
requires 'FirePHP::Log4perl::Appender';
requires 'FirePHP::Log4perl::Layout';
requires 'FirePHP::SimpleTable';

requires 'Catalyst';

requires 'Scope::Guard';
requires 'Class::BlackHole';

requires 'MRO::Compat';
requires 'Sub::Uplevel';
requires 'version';

recommends 'Catalyst::Log::Log4perl';
recommends 'DBIx::Class::Storage::Statistics::SimpleTable';

WriteAll;
