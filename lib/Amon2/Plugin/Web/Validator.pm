package Amon2::Plugin::Web::Validator;
use strict;
use warnings;
use 5.010_000;
our $VERSION = '0.01';

use Amon2::Util();
use Amon2::Validator;

sub init {
    my ($class, $c, $conf) = @_;

    my $on_success = $conf->{on_success};
    my $on_error   = $conf->{on_error};
    
    my %config = (
        module  => $conf->{module},
        message => $conf->{message},
    );

    my $validator = Amon2::Validator->new(%config);

    Amon2::Util::add_method($c, 'validator', sub {
        my ($self, %opt) = @_;

        my $rule = exists $opt{rule} ? $opt{rule} : $conf->{rule}{$self->req->path};
        my $result = $validator->validate($self->req, $rule);

        if ($result->is_success) {
            $on_success->($self, $result) if $on_success;
        } else {
            $on_error->($self, $result)   if $on_error;
        }

        $result;
    });
}

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Amon2::Plugin::Web::Validator

=head1 SYNOPSIS

package YourApp::Web;
use Amon2::Lite;

get '/' => sub {
    my $c = shift;
    my $result = $c->validator(rule => +{
        page  => 'Int',
        limit => {isa => 'Int', default => 1},
    })->validate();

    if ($result->is_success) {
        my $data = $result->valid_data;

        ...
    } else {
        return $c->redirect('/error');
    }
};

post '/' => sub {
    my $c = shift;
    my $data = $c->validator(+{
        page => {isa => 'Int', default => 1},
    })->valid_data;
    my $result = $c->model('hoge')->huga(%$data);
    return $c->render($result);
};

__PACKAGE__->load_plugins(
    'Web::Validator' => +{
        module  => 'Data::Validator',
        message => \%error_messages,
    },
);

1;
