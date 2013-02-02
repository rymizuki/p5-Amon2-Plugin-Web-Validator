use inc::Module::Install;
use Module::Install::AuthorTests;

name 'Amon2-Plugin-Web-Validator';
all_from 'lib/Amon2/Plugin/Web/Validator.pm';

requires 'Amon2';
requires 'Amon2::Util';
requires 'Data::Validator';
requires 'Carp';
requires 'JSON::XS';
requires 'Mouse';
requires 'Plack::Util';
requires 'String::CamelCase';

tests 't/*.t';
test_requires 'Test::More' => ;
author_tests('xt');
WriteAll;
