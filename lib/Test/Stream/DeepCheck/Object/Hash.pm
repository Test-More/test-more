package Test::Stream::DeepCheck::Object::Hash;
use strict;
use warnings;

use base 'Test::Stream::DeepCheck::Object';
use base 'Test::Stream::DeepCheck::Hash';

sub init {
    $_[0]->Test::Stream::DeepCheck::Hash::init();
    $_[0]->Test::Stream::DeepCheck::Object::init();
}

sub path {
    my $self = shift;
    my ($parent_path, $child) = @_;

    return $self->Test::Stream::DeepCheck::Object::path(@_)
        if ref $child;

    return $self->Test::Stream::DeepCheck::Hash::path(@_)
}

sub verify {
    my $self = shift;
    my ($got, $state) = @_;

    # if it already failed we would not be here
    # if it already passed returning 1 is fine
    # if it is recursive then it has been true so far, return true, other
    # checks will catch any failures. 
    return 1 if $state->seen->{$self}->{$got}++;

    $self->verify_meta(@_) || return 0;

    push @{$state->path} => $self;
    $self->verify_object(@_) || return 0;
    $self->verify_hash(@_)  || return 0;
    pop @{$state->path};

    return 1;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::DeepCheck::Object::Hash - Class for doing deep hash-object
checks

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 DESCRIPTION

This package represents a deep check of an hash-object datastructure.

=head1 SUBCLASSES

This class subclasses L<Test::Stream::DeepCheck::Meta>,
L<Test::Stream::DeepCheck::Object>, and
L<Test::Stream::DeepCheck::Hash>.

=head1 SOURCE

The source code repository for Test::Stream can be found at
F<http://github.com/Test-More/Test-Stream/>.

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

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
