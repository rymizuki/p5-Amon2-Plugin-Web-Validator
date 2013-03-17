use strict;
use warnings;
use 5.010_000;
our $VERSION = '0.02';

package Amon2::Validator;
use Carp ();
use Data::Validator;
use JSON::XS;
use Plack::Util ();
use String::CamelCase qw(decamelize);

use Mouse;

has module => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);
has opt => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { +{} },
);
has message => (
    is       => 'rw',
    isa      => 'HashRef',
    required => 1,
);
has namespace => (
    is      => 'ro',
    isa     => 'Str',
    default => 'Amon2::Validator',
);
has rule => (
    is       => 'rw',
    isa      => 'HashRef',
    required => 0,
);
has data => (
    is       => 'rw',
    isa      => 'HashRef',
    required => 0,
    default  => sub { +{} },
);
has errors => (
    is       => 'rw',
    isa      => 'ArrayRef',
    default  => sub { [] },
);
has validator => (
    is         => 'ro',
    lazy_build => 1,
);
has json => (
    is         => 'ro',
    isa        => 'JSON::XS',
    lazy_build => 1,
);

no Mouse;

sub _initialize {
    my ($self, $rule) = @_;
    $self->rule($rule);
    $self->errors([]);
    $self->data(+{});
    $self;
}

sub validate {
    my ($self, $input, $rule) = @_;

    $self->_initialize($rule);

    my %param;
    my %file;

    if (ref $input eq 'HASH') {
        %param = %$input;
    } elsif ($input->isa('Plack::Request')) {
        my $result = $self->_parse_plack_request($input);
        %param = %{ $result->{param} };
        %file  = %{ $result->{file}  };
    } else {
        Carp::croak('Missmatch references, Plack::Request or HashRef');
    }

    # Valdiation specified by Module
    my $validator = $self->validator;
    my %data   = $self->_parse_input_params(%param);
    my $result = $validator->validate($self->get_rule, %data);

    if (!$validator->is_success) {
        $self->_register_valid_errors($validator->errors);
    }

    # Plack::Request::Upload file validation
    if (%{ $self->get_rule(for_file => 1) }) {
        $self->_validate_upload_files(%file);
    }

    $self->data({ %$result, %file });
    $self;
}

sub get_rule {
    my $self = shift;
    state $v = Data::Validator->new(
        for_file => {isa => 'Bool', default => 0},
    );
    my $args = $v->validate(@_);

    my %rule = %{ $self->rule };
    my %result;

    if ($args->{for_file}) {
        %result = map {
            $_ => $rule{$_}
        } grep {
            ref $rule{$_} eq 'HASH' && exists $rule{$_}{is_upload} && $rule{$_}{is_upload}
        } keys %rule;
    } else {
        %result = map {
            $_ => $rule{$_}
        } grep {
            ref $rule{$_} ne 'HASH' || !exists $rule{$_}{is_upload}
        } keys %rule;
    }

    \%result;
}

sub valid_data {
    my $self = shift;
    my $data   = $self->data;
    my %result = $self->_parse_valid_data(%$data);
    \%result;
}

sub has_error {
    my $self = shift;
    @{$self->errors} > 0 ? 1 : 0;
}

sub is_success {
    my $self = shift;
    $self->has_error ? 0 : 1;
}

sub get_errors {
    my $self = shift;
    $self->errors;
}

sub get_error_messages {
    my $self = shift;
    state $v = Data::Validator->new(
        name => 'Str',
    )->with(qw(Sequenced));
    my $args = $v->validate(@_);
    my $name = $args->{name};

    my @messages = map {
        $_->{message}
    } grep {
        $_->{name} eq $name
    } @{ $self->errors };

    \@messages;
}

sub has_error_by_name {
    my $self = shift;
    state $v = Data::Validator->new(
        name => 'Str',
    )->with(qw(Sequenced));
    my $args = $v->validate(@_);
    my $name = $args->{name};
    (grep { $_->{name} eq $name } @{$self->errors}) ? 1 : 0;
}

sub set_error {
    my $self = shift;
    state $v = Data::Validator->new(
        name => 'Str',
        key  => 'Str',
    )->with(qw(Sequenced));
    my $args = $v->validate(@_);
    my $name    = $args->{name};
    my $key     = $args->{key};
    my $message = $self->message->{$key};

    $self->_push_error(
        name    => $name,
        key     => $key,
        message => $message,
    );

    $self;
}

sub _register_valid_errors {
    my ($self, $errors) = @_;
    my %rule    = %{ $self->rule };
    my %message = %{ $self->message };

    for my $e (@$errors) {
        my $name      = $e->{name};
        my $rule_type = $rule{$name};
        my $key = decamelize(ref $rule_type eq 'HASH' ? $rule_type->{isa} : $rule_type);

        $self->_push_error(
            name    => $name,
            key     => $key,
            message => $message{$key},
        );
    }
}

sub _validate_upload_files {
    my ($self, %file) = @_;
    my %rule = %{ $self->get_rule(for_file => 1) };

    for my $name (keys %rule) {
        my $rule = $rule{$name};
        my $file = $file{$name};

        unless ($file) {
            $self->set_error($name, 'file_not_found');
        }
        unless (($file->{size} || 0) <= $rule->{size}) {
            $self->set_error($name, 'file_sizeover');
        }
        unless (($file->{headers}{'content-type'} || '') eq $rule->{content_type}) {
            $self->set_error($name, 'content_type_unmached');
        }
    }

    %file;
}

sub _push_error {
    my ($self, %error) = @_;
    push @{ $self->{errors} }, \%error;
}

sub _parse_plack_request {
    my ($self, $input) = @_;

    my $param = {};
    if (($input->content_type || '') eq 'application/json') {
        $param = $self->json->decode($input->content);
    } else {
        $param = $input->parameters->as_hashref_mixed;
    }

    my $file = $input->uploads || +{};

    return +{
        param => $param,
        file  => $file,
    };
}

sub _parse_input_params {
    my ($self, %param) = @_;

    my %data = map {
        $_ => $param{$_}
    } grep {
        length((defined $param{$_}) ? $param{$_} : '')
    } keys %{ $self->get_rule };

    %data;
}

sub _parse_valid_data {
    my ($self, %data) = @_;

    my %valid_data = map {
        $_ => $data{$_}
    } grep {
        length((defined $data{$_}) ? $data{$_} : '')
    } keys %{ $self->rule };

    %valid_data;
}

sub _build_validator {
    my $self = shift;
    my $vclass = Plack::Util::load_class($self->module, $self->namespace)
        or Carp::croak('Cannot load ValidatorClass. module: '.$self->module);
    $vclass->new(%{ $self->opt });
}

sub _build_json {
    my $self = shift;
    JSON::XS->new->utf8;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Amon2::Validator

=head1 SYNOPSIS

=head1 METHODS

=head2 $v->validate(\%param, \%rule) :Amon2::Validator

=head2 $v->is_success :Bool

=head2 $v->valid_data :HashRef

=head2 $v->has_error :Bool

=head2 $v->has_error_by_name($name) :Bool

=head2 $v->is_success :Bool

=head2 $v->get_errors :ArrayRef

=head2 $v->get_error_message($name) :ArrayRef

=head2 $v->set_error($name, $key) :Amon2::Validator

=cut
