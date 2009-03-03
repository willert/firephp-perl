use inc::Module::Install 0.70;
use version;

name 'DBIx-Class-Storage-Statistics-SimpleTable';
all_from './lib/DBIx/Class/Storage/Statistics/SimpleTable.pm';

requires 'DBIx::Class' => '0.08';
requires 'Text::SimpleTable';

requires 'version';
requires 'MRO::Compat';

WriteAll;
