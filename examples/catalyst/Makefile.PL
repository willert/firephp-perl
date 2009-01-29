# IMPORTANT: if you delete this file your app will not work as
# expected.  you have been warned
use inc::Module::Install;

name 'FirePHP-Example-Catalyst';
all_from 'lib/FirePHP/Example/Catalyst.pm';

requires 'Catalyst::Runtime' => '5.70000';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Log::Log4perl';
requires 'parent';
requires 'FirePHP::Catalyst::Plugin';
requires 'MRO::Compat';

catalyst;
auto_install;

WriteAll;
