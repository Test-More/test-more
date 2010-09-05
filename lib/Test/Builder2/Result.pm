package Test::Builder2::Result;

use strict;

use Carp;
use Test::Builder2::Mouse;
use Test::Builder2::Mouse::Util::TypeConstraints qw(enum);


=head1 NAME

Test::Builder2::Result - A factory to generate results.

=head1 SYNOPSIS

    use Test::Builder2::Result;

    my $result = Test::Builder2::Result->new_result(%test_data);


=head1 DESCRIPTION

A factory to generate results.  See L<Test::Builder2::Result::Base>
for information about the real result objects.

An object to store the result of a test.  Used to keep test history,
format the results of tests, and build up diagnostics about a test.

B<NOTE>: Results are currently in a high state of flux with regard to
directives, what determines if it "passed" or "failed", their
internal structure and this even being a factory.


=head3 Overloading

Result objects are overloaded to return true or false in boolean
context to indicate if they passed or failed.


=head3 new_result

  my $result = Test::Builder2::Result->new_result(%test_data);

new_result() is a method which returns a $result based on your test data.

$result will be a L<Test::Builder2::Result::Base> object.

=cut


my %Types = (
    pass        => [qw(pass)],
    fail        => [qw(fail)],
    todo_pass   => [qw(pass todo)],
    todo_fail   => [qw(fail todo)],
    skip_pass   => [qw(pass skip)],
    skip_fail   => [qw(fail skip)],
    todo_skip   => [qw(fail skip todo)],
    unknown     => [qw(unknown)],
    unknown_fail=> [qw(fail unknown)],
    unknown_pass=> [qw(pass unknown)],
);

my %Roles2Type;
for my $type (keys %Types) {
    my $roles = $Types{$type};

    my $key = _roles_key(@$roles);
    $Roles2Type{$key} = $type;
}

sub _roles_key {
    return join ",", sort { $a cmp $b } @_;
}

sub types {
    return keys %Types;
}


# Generate the result classes as combinations of roles.
for my $type (keys %Types) {
    my $roles = $Types{$type};

    Test::Builder2::Mouse::Meta::Class->create(
        "Test::Builder2::Result::$type",
        superclasses => ["Test::Builder2::Result::Base"],
        roles        => [map { "Test::Builder2::Result::Role::$_" } @$roles],
        methods      => {
            type        => sub { return $type }
        }
    );
}

sub new {
    croak "There is no new(), perhaps you meant new_result?";
}

sub new_result {
    my $class = shift;
    my %args  = @_;

    # Figure out the roles associated with the given arguments
    my @roles;
    my @directives = map { lc $_ } @{$args{directives} || []};
    push @roles, @directives;

    push @roles, !exists $args{pass} ? "unknown" : 
                         $args{pass} ? "pass"    : "fail";

    my $roles_key = _roles_key(@roles);
    my $type = $Roles2Type{$roles_key};
    if( !$type ) {
        carp "Unknown result roles: @roles";
        $type = 'unknown_fail';
    }

    return "Test::Builder2::Result::$type"->new(%args);
}

no Test::Builder2::Mouse;

1;


=head1 SEE ALSO

L<Test::Builder2::Result::Base> for the result objects generated.

=cut

