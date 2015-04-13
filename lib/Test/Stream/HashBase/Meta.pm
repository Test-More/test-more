package Test::Stream::HashBase::Meta;
use strict;
use warnings;

use Test::Stream::Carp qw/confess/;

my %META;

sub package { shift->{package} }
sub parent  { shift->{parent} }
sub locked  { shift->{locked} }
sub fields  { ({%{shift->{fields}}}) }
sub order   { [@{shift->{order}}] }

sub new {
    my $class = shift;
    my ($pkg) = @_;

    $META{$pkg} ||= bless {
        package => $pkg,
        locked  => 0,
    }, $class;

    return $META{$pkg};
}

sub get {
    my $class = shift;
    my ($pkg) = @_;

    return $META{$pkg};
}

sub baseclass {
    my $self = shift;
    $self->{parent} = 'Test::Stream::HashBase';
    $self->{fields} = {};
    $self->{order}  = [];
}

sub subclass {
    my $self = shift;
    my ($parent) = @_;
    confess "Already a subclass of $self->{parent}! Tried to sublcass $parent" if $self->{parent};

    my $pmeta = $self->get($parent) || die "$parent is not a HashBase object!";
    $pmeta->{locked} = 1;

    $self->{parent} = $parent;
    $self->{fields} = $pmeta->fields; #Makes a copy
    $self->{order}  = $pmeta->order;  #Makes a copy

    my $ex_meta = Test::Stream::Exporter::Meta->get($self->{package});

    # Put parent constants into the subclass
    for my $field (@{$self->{order}}) {
        my $const = uc $field;
        no strict 'refs';
        *{"$self->{package}\::$const"} = $parent->can($const) || confess "Could not find constant '$const'!";
        $ex_meta->add($const);
    }
}

{
    no warnings 'once';
    *add_accessor = \&add_accessors;
}

sub add_accessors {
    my $self = shift;

    confess "Cannot add accessor, metadata is locked due to a subclass being initialized ($self->{parent}).\n"
        if $self->{locked};

    my $ex_meta = Test::Stream::Exporter::Meta->get($self->{package});

    for my $name (@_) {
        confess "field '$name' already defined!"
            if exists $self->{fields}->{$name};

        $self->{fields}->{$name} = 1;
        push @{$self->{order}} => $name;

        my $const = uc $name;
        my $gname = lc $name;
        my $sname = "set_$gname";

        my $cname = $name;
        my $csub = sub() { $cname };

        {
            no strict 'refs';
            *{"$self->{package}\::$const"} = $csub;
            *{"$self->{package}\::$gname"} = sub { $_[0]->{$name} };
            *{"$self->{package}\::$sname"} = sub { $_[0]->{$name} = $_[1] };
        }

        $ex_meta->{exports}->{$const} = $csub;
        push @{$ex_meta->{polist}} => $const;
    }
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::HashBase::Meta - Meta Object for HashBase objects.

=head1 SYNOPSIS

B<Note:> You probably do not want to directly use this object.

    my $meta = Test::Stream::HashBase::Meta->new('Some::Class');
    $meta->add_accessor('foo');

=head1 DESCRIPTION

This is the meta-object used by L<Test::Stream::HashBase>

=head1 METHODS

=over 4

=item $meta = $class->new($package)

Create a new meta object for the specified class. If one already exists that
instance is returned.

=item $meta = $class->get($package)

Get the meta object for the specified class. Returns C<undef> if there is none
initiated.

=item $package = $meta->package

Get the package the meta-object manages.

=item $package = $meta->parent

Get the parent package to the one being managed.

=item $bool = $meta->locked

True if the package has been locked. Locked means no new accessors can be
added. A package is locked once something else subclasses it.

=item $hr = $meta->fields

Get a hashref defining the fields on the package. This is primarily for
internal use, it is not very useful outside.

=item $ar = $meta->order

All fields for the class in order starting with fields from base classes.

=item $meta->baseclass

Make the package inherit from HashBase directly.

=item $meta->subclass($package)

Set C<$package> as the base class of the managed package.

=item $meta->add_accessor($name)

Add an accessor to the package. Also defines the C<"set_$name"> method, and the
C<uc($name)> constant.

=back

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINER

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

The following people have all contributed to the Test-More dist (sorted using
VIM's sort function).

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=item Fergal Daly E<lt>fergal@esatclear.ie>E<gt>

=item Mark Fowler E<lt>mark@twoshortplanks.comE<gt>

=item Michael G Schwern E<lt>schwern@pobox.comE<gt>

=item 唐鳳

=back

=head1 COPYRIGHT

There has been a lot of code migration between modules,
here are all the original copyrights together:

=over 4

=item Test::Stream

=item Test::Stream::Tester

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::Simple

=item Test::More

=item Test::Builder

Originally authored by Michael G Schwern E<lt>schwern@pobox.comE<gt> with much
inspiration from Joshua Pritikin's Test module and lots of help from Barrie
Slaymaker, Tony Bowden, blackstar.co.uk, chromatic, Fergal Daly and the perl-qa
gang.

Idea by Tony Bowden and Paul Johnson, code by Michael G Schwern
E<lt>schwern@pobox.comE<gt>, wardrobe by Calvin Klein.

Copyright 2001-2008 by Michael G Schwern E<lt>schwern@pobox.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::use::ok

To the extent possible under law, 唐鳳 has waived all copyright and related
or neighboring rights to L<Test-use-ok>.

This work is published from Taiwan.

L<http://creativecommons.org/publicdomain/zero/1.0>

=item Test::Tester

This module is copyright 2005 Fergal Daly <fergal@esatclear.ie>, some parts
are based on other people's work.

Under the same license as Perl itself

See http://www.perl.com/perl/misc/Artistic.html

=item Test::Builder::Tester

Copyright Mark Fowler E<lt>mark@twoshortplanks.comE<gt> 2002, 2004.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=back
