use inc::Module::Install 0.70;
use version;

name 'DBIx-Class-Storage-Statistics-SimpleTable';
all_from './lib/DBIx/Class/Storage/Statistics/SimpleTable.pm';

include  'Module::AutoInstall';

requires 'DBIx::Class' => '0.08';
requires 'Text::SimpleTable';

auto_install();
WriteAll;
