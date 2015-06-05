package Test::Stream::Exporter;
use strict;
use warnings;

use Test::Stream::Exporter::Meta;

use Carp qw/croak confess/;

BEGIN { Test::Stream::Exporter::Meta->new(__PACKAGE__) };

sub import {
    my $class = shift;
    my $caller = caller;

    Test::Stream::Exporter::Meta->new($caller);
    export_from($class => $caller, \@_);
}

sub unimport {
    my ($class, @list) = @_;
    my $pkg = caller;

    @list = qw/export exports default_export default_exports export_from/ unless @list;

    for my $name (@list) {
        no strict 'refs';
        local *GLOBCLONE = *{"$pkg\::$name"};
        my $stash = \%{"${pkg}\::"};
        delete $stash->{$name};
        for my $slot (qw/HASH SCALAR ARRAY IO FORMAT/) {
            *{"$pkg\::$name"} = *GLOBCLONE{$slot} if defined *GLOBCLONE{$slot};
        }
    }

}

###############
# Exported Methods
###############

exports(qw/export_to/);

default_export( import => sub {
    return unless Test::Stream::Exporter::Meta::get($_[0]);
    my $class = shift;
    my $caller = caller;
    export_from($class => $caller, \@_);
});

sub export_to {
    my ($from, $dest, $imports) = @_;

    my $meta = Test::Stream::Exporter::Meta->new($from);

    $imports = $meta->default unless $imports && @$imports;

    my $exports = $meta->exports;
    for my $name (@$imports) {
        my $ref = $exports->{$name}
            || croak qq{"$name" is not exported by the $from module};

        no strict 'refs';
        *{"$dest\::$name"} = $ref;
    }
}

###############
# Exported Functions
###############

default_exports(qw/export exports default_export default_exports/);
exports(qw/export_from/);

# There is no implementation difference, but different names make the purpose
# of each use more clear.
BEGIN { *export_from = \&export_to }

sub export {
    my $caller = caller;

    my $meta = Test::Stream::Exporter::Meta::get($caller) ||
        confess "$caller is not an exporter!?";

    # Only the first 2 args are used.
    $meta->add(0, @_);
}

sub exports {
    my $caller = caller;

    my $meta = Test::Stream::Exporter::Meta::get($caller) ||
        confess "$caller is not an exporter!?";

    $meta->add_bulk(0, @_);
}

sub default_export {
    my $caller = caller;

    my $meta = Test::Stream::Exporter::Meta::get($caller) ||
        confess "$caller is not an exporter!?";

    $meta->add(1, @_);
}

sub default_exports {
    my $caller = caller;

    my $meta = Test::Stream::Exporter::Meta::get($caller) ||
        confess "$caller is not an exporter!?";

    $meta->add_bulk(1, @_);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Exporter - Declarative exporter for Test::Stream and friends.

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

Test::Stream::Exporter is an internal implementation of some key features from
L<Exporter::Declare>. This is a much more powerful exporting tool than
L<Exporter>. This package is used to easily manage complicated EXPORT logic
across L<Test::Stream> and friends.

=head1 SYNOPSIS

    use Test::Stream::Exporter;

    # Export some named subs from the package
    default_exports qw/foo bar baz/;
    exports qw/fluxx buxx suxx/;

    # Export some anonymous subs under specific names.
    export         some_tool    => sub { ... };
    default_export another_tool => sub { ... };

    # Call this when you are done providing exports in order to cleanup your
    # namespace.
    no Test::Stream::Exporter;

    ...;

=head1 CUSTOMIZING AN IMPORT METHOD

Sometimes you need to make a custom import method, but you still want to use
the exporter tool to manage exports. here is how you do it:

    use Test::Stream::Exporter qw/export exports export_from/;
    export foo => sub { 'foo' };
    export qw/bar baz/;

    sub import {
        my $class = shift;
        my @exports = @_;

        # Do whatever you need to
        ...

        # Now go ahead and do the exporting with your list
        my $caller = caller;
        export_from($class, $caller, \@exports);
    }

    # This will cleanup the namespace, including 'export_from', do you need to
    # do it AFTER your import method.
    no Test::Stream::Exporter;

    sub bar { 'bar' }
    sub baz { 'baz' }

    1;

=head1 EXPORTS

=head2 DEFAULT

=head3 METHODS

=over 4

=item $class->import(@list)

Your class needs this to function as an exporter.

=back

=head3 FUNCTIONS

B<Note:> All of thease are removed by default when you run
C<no Test::Stream::Exporter;>

=over 4

=item export NAME => sub { ... }

=item default_export NAME => sub { ... }

These are used to define exports that may not actually be subs in the current
package.

=item exports qw/foo bar baz/

=item default_exports qw/foo bar baz/

These let you export package subs en mass.

=back

=head2 OTHER AVAILABLE EXPORTS

=head3 METHODS

=over 4

=item $class->export_to($dest)

=item $class->export_to($dest, \@symbols)

Export from the exporter class into the C<$dest> package. The seconond argument
is optional, if it is omitted the default export list will be used. The second
argument must be an arrayref with export names.

=back

=head3 FUNCTIONS

B<Note:> All of thease are removed by default when you run
C<no Test::Stream::Exporter;>

=over 4

=item export_from($from, $to)

=item export_from($from, $to, \@symbols)

This will export all the specified symbols from the C<$from> package to the
C<$to> package.

=back

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

=item Kent Fredric E<lt>kentnl@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
