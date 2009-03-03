use inc::Module::Install 0.70;
use version;

name 'Catalyst-Plugin-FirePHP';
all_from 'lib/Catalyst/Plugin/FirePHP.pm';

requires 'FirePHP::Dispatcher' => '0.02';
requires 'Catalyst';

requires 'Scope::Guard';
requires 'Class::BlackHole';

recommends 'Catalyst::Log::Log4perl';
recommends 'DBIx::Class::Storage::Statistics::SimpleTable';

WriteAll;
