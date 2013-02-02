use strict;
use warnings;
use Test::More;

use Plack::Request;
use Plack::Test;
use Test::Requires 'HTTP::Request::Common';

use Amon2::Lite;

__PACKAGE__->load_plugins(
    'Web::JSON',
    'Web::Validator' => +{
        module => 'Data::Validator',
        message => +{
            'str' => 'invalid string',
            'int' => 'invalid integer',
        },
        rule => +{
            '/is_success' => +{
                huga => 'Str',
            },
            '/failed-case' => +{
                huga => 'Str',
            },
            '/errors' => +{
                invalid => 'Int',
                string  => 'Str',
            },
            '/query-param' => +{
                huga => 'Str',
                foo  => 'Str',
            },
            '/query-body' => +{
                huga => 'Str',
                foo  => 'Str',
            },
            '/json' => +{
                huga => 'Str',
                foo  => 'Str',
            },
        },
    },
);

use Log::Minimal;

get  '/' => sub {
    my $c = shift;
    my $data = $c->validator(rule => +{
            hoo => 'Str',
            bar => 'Str',
    })->valid_data;
    $c->render_json($data);
};
get  '/is_success'  => sub { $_[0]->render_json({is_success => $_[0]->validator->is_success}) };
get  '/failed-case' => sub { $_[0]->render_json($_[0]->validator->valid_data) };
get  '/errors'      => sub { $_[0]->render_json($_[0]->validator->get_errors) };
get  '/query-param' => sub { $_[0]->render_json($_[0]->validator->valid_data) };
post '/query-body'  => sub { $_[0]->render_json($_[0]->validator->valid_data) };
post '/json'        => sub { $_[0]->render_json($_[0]->validator->valid_data) };

my $app = __PACKAGE__->to_app;

test_psgi($app, sub {
    my $cb = shift;

    {
        my $res = $cb->(GET '/?hoo=hello&bar=world');
        is $res->content => '{"bar":"world","hoo":"hello"}';
    }
    {
        my $res = $cb->(GET '/is_success');
        is $res->content => '{"is_success":0}';
    }
    {
        my $res = $cb->(GET '/is_success?huga=hoge');
        is $res->content => '{"is_success":1}';
    }
    {
        my $res = $cb->(GET '/failed-case');
        is $res->content => '{}';
    }
    {
        my $res = $cb->(GET '/errors');
        is $res->content => '[{"name":"string","message":"invalid string","key":"str"},{"name":"invalid","message":"invalid integer","key":"int"}]';
    }
    {
        my $res = $cb->(GET '/query-param?huga=hoge&foo=bar&and=more');
        is $res->content => '{"huga":"hoge","foo":"bar"}';
    }
    {
        my $res = $cb->(POST '/query-body', [huga => 'hoge', foo => 'bar', and => 'more']);
        is $res->content => '{"huga":"hoge","foo":"bar"}';
    }

    {
        my $res = $cb->(
            POST '/json',
                Content_Type => 'application/json',
                Content      => '{"foo":"bar", "huga":"hoge"}',
        );
        is $res->content => '{"huga":"hoge","foo":"bar"}';
    }
});

done_testing;
