use inc::Module::Install 0.70;
use version;

name 'Catalyst-Plugin-FirePHP';
all_from 'lib/Catalyst/Plugin/FirePHP.pm';

include  'Module::AutoInstall';

requires 'FirePHP::Dispatcher';
requires 'Catalyst';

requires 'Scope::Guard';
requires 'Class::BlackHole';

recommends 'Catalyst::Log::Log4perl';

auto_install();
WriteAll;
