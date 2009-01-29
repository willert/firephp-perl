use inc::Module::Install 0.70;
use version;

name 'FirePHP-Dispatcher';
all_from 'lib/FirePHP/Dispatcher.pm';

include  'Module::AutoInstall';

requires 'JSON::Any';
requires 'Class::Accessor::Fast';

recommends 'Log::Log4perl';

auto_install();
WriteAll;
