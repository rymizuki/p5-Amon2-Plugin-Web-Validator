use strict;
use warnings;
use 5.010_000;

package Amon2::Validator::Data::Validator;
use Mouse;

has no_throw => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);
has allow_extra => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

has is_success => (
    is  => 'rw',
    isa => 'Bool',
);
has error => (
    is  => 'rw',
    isa => 'ArrayRef',
);

no Mouse;

sub validate {
    my ($self, $rule, %data) = @_;

    my $validator = Data::Validator->new(%$rule)->with($self->_with);
    my $result_args = $validator->validate(%data);

    $self->is_success($validator->has_errors ? 0 : 1);
    $self->errors($validator->clear_errors)

    $result_args;
}

sub _with {
    my $self = shift;
    my @roles;

    # XXX: 指定刷る順番で挙動変わるので注意
    push @roles => 'NoThrow'    if $self->no_throw;
    push @roles => 'AllowExtra' if $self->allow_extra;

    if (my @set_roles = @{$self->roles}) {
        push @roles, @set_roles;
    }

    @roles;
}

1;
