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
        my ($self, ) = @_;

        my $result = $validator->validate($self->req, $conf->{rule}{$self->req->path});

        if ($result->is_success) {
            $on_success->($self, $result) if $on_success;
        } else {
            $on_error->($self, $result)   if $on_error;
        }

        $result;
    });
}

1;
