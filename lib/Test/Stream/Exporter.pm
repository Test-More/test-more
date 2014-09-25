package Test::Stream::Exporter;
use strict;
use warnings;

use Test::Stream::PackageUtil;
use Test::Stream::Exporter::Meta;

sub export;
sub exports;
sub default_export;
sub default_exports;

# Test::Stream::Carp uses this module.
sub croak   { require Carp; goto &Carp::croak }
sub confess { require Carp; goto &Carp::confess }

BEGIN { Test::Stream::Exporter::Meta->new(__PACKAGE__) };

sub import {
    my $class = shift;
    my $caller = caller;

    Test::Stream::Exporter::Meta->new($caller);

    export_to($class, $caller, @_);
}

default_exports qw/export exports default_export default_exports/;
exports         qw/export_to export_meta/;

default_export import => sub {
    my $class = shift;
    my $caller = caller;
    my @args = @_;

    my $stash = $class->before_import($caller, \@args) if $class->can('before_import');
    export_to($class, $caller, @args);
    $class->after_import($caller, $stash, @args) if $class->can('after_import');
};

sub export_meta {
    my $pkg = shift || caller;
    return Test::Stream::Exporter::Meta->get($pkg);
}

sub export_to {
    my $class = shift;
    my ($dest, @imports) = @_;

    my $meta = export_meta($class)
        || confess "$class is not an exporter!?";

    my (@include, %exclude);
    for my $import (@imports) {
        if ($import =~ m/^!(.*)$/) {
            $exclude{$1}++;
        }
        else {
            push @include => $import;
        }
    }

    @include = $meta->default unless @include;

    for my $name (@include) {
        next if $exclude{$name};

        my $ref = $meta->exports->{$name}
            || croak "$class does not export $name";

        no strict 'refs';
        $name =~ s/^[\$\@\%\&]//;
        *{"$dest\::$name"} = $ref;
    }
}

sub cleanup {
    my $pkg = caller;
    package_purge_sym($pkg, map {(CODE => $_)} qw/export exports default_export default_exports/);
}

sub export {
    my ($name, $ref) = @_;
    my $caller = caller;

    my $meta = export_meta($caller) ||
        confess "$caller is not an exporter!?";

    $meta->add($name, $ref);
}

sub exports {
    my $caller = caller;

    my $meta = export_meta($caller) ||
        confess "$caller is not an exporter!?";

    $meta->add($_) for @_;
}

sub default_export {
    my ($name, $ref) = @_;
    my $caller = caller;

    my $meta = export_meta($caller) ||
        confess "$caller is not an exporter!?";

    $meta->add_default($name, $ref);
}

sub default_exports {
    my $caller = caller;

    my $meta = export_meta($caller) ||
        confess "$caller is not an exporter!?";

    $meta->add_default($_) for @_;
}

1;

__END__

=encoding utf8

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

=over 4

=item Test::Stream

=item Test::Tester2

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

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
