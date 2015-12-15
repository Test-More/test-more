package Test2::Util::HashBase;
use strict;
use warnings;

my %META;

sub import {
    my ($class, @accessors) = @_;

    my $into = caller;
    my $meta = $META{$into} = \@accessors;

    # Use the comment to change the filename slightly so that Devel::Cover does
    # not try to cover the contents of the string eval.
    my $file = __FILE__;
    my $eval = "# line 1 \"$file.eval\"\npackage $into;\n";

    no strict 'refs';
    my $isa = \@{"$into\::ISA"};
    use strict 'refs';

    if(my @bmetas = map { $META{$_} or () } @$isa) {
        $eval .= "sub " . uc($_) . "() { '$_' };\n" for map { @{$_} } @bmetas;
    }

    {
        $eval .= join '' => map {
            my $const = uc($_);
            <<"            EOT"
sub $const() { '$_' }
sub $_       { \$_[0]->{'$_'} }
sub set_$_   { \$_[0]->{'$_'} = \$_[1] }
sub clear_$_ { delete \$_[0]->{'$_'} }
            EOT
        } @$meta;
    }

    eval "${eval}1;" || die $@;

    no strict 'refs';
    *{"$into\::new"} = \&_new;
}

sub _new {
    my ($class, %params) = @_;
    my $self = bless \%params, $class;
    $self->init if $self->can('init');
    $self;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Util::HashBase - Base class for classes that use a hashref
of a hash.

=head1 EXPERIMENTAL RELEASE

This is an experimental release. Using this right now is not recommended.

=head1 SYNOPSIS

A class:

    package My::Class;
    use strict;
    use warnings;

    # Generate 3 accessors
    use Test2::Util::HashBase qw/foo bar baz/;

    # Chance to initialize defaults
    sub init {
        my $self = shift;    # No other args
        $self->{+FOO} ||= "foo";
        $self->{+BAR} ||= "bar";
        $self->{+BAZ} ||= "baz";
    }

    sub print {
        print join ", " => map { $self->{$_} } FOO, BAR, BAZ;
    }

Subclass it

    package My::Subclass;
    use strict;
    use warnings;

    # Note, you should subclass before loading HashBase.
    use base 'My::Class';
    use Test2::Util::HashBase qw/bat/;

    sub init {
        my $self = shift;

        # We get the constants from the base class for free.
        $self->{+FOO} ||= 'SubFoo';
        $self->{+BAT} || = 'bat';

        $self->SUPER::init();
    }

use it:

    package main;
    use strict;
    use warnings;
    use My::Class;

    my $one = My::Class->new(foo => 'MyFoo', bar => 'MyBar');

    # Accessors!
    my $foo = $one->foo;    # 'MyFoo'
    my $bar = $one->bar;    # 'MyBar'
    my $baz = $one->baz;    # Defaulted to: 'baz'

    # Setters!
    $one->set_foo('A Foo');
    $one->set_bar('A Bar');
    $one->set_baz('A Baz');

    # Clear!
    $one->clear_foo;
    $one->clear_bar;
    $one->clear_baz;

    $one->{+FOO} = 'xxx';

=head1 DESCRIPTION

This package is used to generate classes based on hashrefs. Using this class
will give you a C<new()> method, as well as generating accessors you request.
Generated accessors will be getters, C<set_ACCESSOR> setters will also be
generated for you. You also get constants for each accessor (all caps) which
return the key into the hash for that accessor. Single inheritence is also
supported.

=head1 METHODS

=head2 PROVIDED BY HASH BASE

=over 4

=item $it = $class->new(@VALUES)

Create a new instance using key/value pairs.

=back

=head2 HOOKS

=over 4

=item $self->init()

This gives you the chance to set some default values to your fields. The only
argument is C<$self> with its indexes already set from the constructor.

=back

=head1 ACCESSORS

To generate accessors you list them when using the module:

    use Test2::Util::HashBase qw/foo/;

This will generate the following subs in your namespace:

=over 4

=item foo()

Getter, used to get the value of the C<foo> field.

=item set_foo()

Setter, used to set the value of the C<foo> field.

=item clear_foo()

Clearer, used to completely remove the 'foo' key from the object hash.

=item FOO()

Constant, returs the field C<foo>'s key into the class hashref. Subclasses will
also get this function as a constant, not simply a method, that means it is
copied into the subclass namespace.

The main reason for using these constants is to help avoid spelling mistakes
and similar typos. It will not help you if you forget to prefix the '+' though.

=back

=head1 SUBCLASSING

You can subclass an existing HashBase class.

    use base 'Another::HashBase::Class';
    use Test2::Util::HashBase qw/foo bar baz/;

The base class is added to C<@ISA> for you, and all constants from base classes
are added to subclasses automatically.

=head1 SOURCE

The source code repository for Test2 can be found at
F<http://github.com/Test-More/Test2/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
