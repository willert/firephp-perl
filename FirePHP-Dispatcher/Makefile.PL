use inc::Module::Install 0.70;
use version;

name 'FirePHP-Dispatcher';
all_from 'lib/FirePHP/Dispatcher.pm';

include  'Module::AutoInstall';

requires 'JSON::Any';
requires 'Class::Accessor::Fast';
requires 'version';

recommends 'Log::Log4perl';

build_requires 'Test::Perl::Critic';

auto_install();
WriteAll;
