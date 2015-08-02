package Test::Stream::Util;
use strict;
use warnings;

use Test::Stream::Capabilities qw/CAN_THREAD/;
use Scalar::Util qw/reftype blessed/;
use Carp qw/croak/;

use Test::Stream::Exporter qw/import export_to exports/;
exports qw{
        try protect

        get_tid USE_THREADS

        pkg_to_file

        get_stash

        sig_to_slot slot_to_sig
        parse_symbol
};
no Test::Stream::Exporter;

sub _manual_protect(&) {
    my $code = shift;

    my ($ok, $error);
    {
        my ($msg, $no) = ($@, $!);
        $ok = eval { $code->(); 1 } || 0;
        $error = $@ || "Error was squashed!\n";
        ($@, $!) = ($msg, $no);
    }
    die $error unless $ok;
    return $ok;
}

sub _local_protect(&) {
    my $code = shift;

    my ($ok, $error);
    {
        local ($@, $!);
        $ok = eval { $code->(); 1 } || 0;
        $error = $@ || "Error was squashed!\n";
    }
    die $error unless $ok;
    return $ok;
}

sub _manual_try(&;@) {
    my $code = shift;
    my $args = \@_;
    my $error;
    my $ok;

    {
        my ($msg, $no) = ($@, $!);
        my $die = delete $SIG{__DIE__};

        $ok = eval { $code->(@$args); 1 } || 0;
        unless($ok) {
            $error = $@ || "Error was squashed!\n";
        }

        ($@, $!) = ($msg, $no);
        $SIG{__DIE__} = $die;
    }

    return ($ok, $error);
}

sub _local_try(&;@) {
    my $code = shift;
    my $args = \@_;
    my $error;
    my $ok;

    {
        local ($@, $!, $SIG{__DIE__});
        $ok = eval { $code->(@$args); 1 } || 0;
        unless($ok) {
            $error = $@ || "Error was squashed!\n";
        }
    }

    return ($ok, $error);
}

# Older versions of perl have a nasty bug on win32 when localizing a variable
# before forking or starting a new thread. So for those systems we use the
# non-local form. When possible though we use the faster 'local' form.
BEGIN {
    if ($^O eq 'MSWin32' && $] < 5.020002) {
        *protect = \&_manual_protect;
        *try     = \&_manual_try;
    }
    else {
        *protect = \&_local_protect;
        *try     = \&_local_try;
    }
}

BEGIN {
    if(CAN_THREAD) {
        if ($INC{'threads.pm'}) {
            # Threads are already loaded, so we do not need to check if they
            # are loaded each time
            *USE_THREADS = sub() { 1 };
            *get_tid = sub { threads->tid() };
        }
        else {
            # :-( Need to check each time to see if they have been loaded.
            *USE_THREADS = sub { $INC{'threads.pm'} ? 1 : 0 };
            *get_tid = sub { $INC{'threads.pm'} ? threads->tid() : 0 };
        }
    }
    else {
        # No threads, not now, not ever!
        *USE_THREADS = sub() { 0 };
        *get_tid     = sub() { 0 };
    }
}

sub pkg_to_file {
    my $pkg = shift;
    my $file = $pkg;
    $file =~ s{::}{/}g;
    $file .= '.pm';
    return $file;
}

sub get_stash {
    my $pkg = shift;
    no strict 'refs';
    return \%{"$pkg\::"};
}

my %SIG_TABLE = (
    '&' => 'CODE',
    '%' => 'HASH',
    '@' => 'ARRAY',
    '$' => 'SCALAR',
    '*' => 'GLOB',
);
my %SLOT_TABLE = reverse %SIG_TABLE;

sub sig_to_slot { $SIG_TABLE{$_[0]}  }
sub slot_to_sig { $SLOT_TABLE{$_[0]} }

sub parse_symbol {
    my ($sym) = @_;

    return ($sym, 'CODE') unless $sym =~ m/^(\W)(.+)$/;
    my ($sig, $name) = ($1, $2);

    my $slot = $SIG_TABLE{$sig} || croak "'$sig' is not a supported sigil";

    return ($name, $slot);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Util - Tools used by Test::Stream and friends.

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

Collection of tools used by L<Test::Stream> and friends.

=head1 EXPORTS

All exports are optional, you must specify subs to import. If you want to
import everything use '-all'.

    use Test::Stream::Util '-all';

=over 4

=item ($success, $error) = try { ... }

Eval the codeblock, return success or failure, and the error message. This code
protects $@ and $!, they will be restored by the end of the run. This code also
temporarily blocks $SIG{DIE} handlers.

=item protect { ... }

Similar to try, except that it does not catch exceptions. The idea here is to
protect $@ and $! from changes. $@ and $! will be restored to whatever they
were before the run so long as it is successful. If the run fails $! will still
be restored, but $@ will contain the exception being thrown.

=item USE_THREADS

Returns true if threads are enabled, false if they are not.

=item get_tid

This will return the id of the current thread when threads are enabled,
otherwise it returns 0.

=item my $file = pkg_to_file($package)

Convert a package name to a filename.

=item $stash = get_stash($package)

Returns the stash reference for the given package. The stash reference can be
treated like a hashref, you can get keys and values from it.

=item $slot = sig_to_slot($sigil)

Given a sigil such as C<$>, C<@>, C<%>, C<&>, C<*>, this will return the GLOB
slot for that sigil such as C<SCALAR>, C<ARRAY>, C<HASH>, C<CODE>, C<GLOB>.

=item $sigil = slot_to_sig($slot)

Given a a glob slot such as C<SCALAR>, C<ARRAY>, C<HASH>, C<CODE>, C<GLOB>,
this will return the typical sigil for that slot such as C<$>, C<@>, C<%>,
C<&>, C<*>.

=item ($name, $type) = parse_symbol($symbol)

When given a symbol name such as C<$foo> or C<@bar> this will return the symbol
name, and the type name. If no sigil is present in the variable name it will
assume it is a subroutine and return the C<CODE> type. C<$symbol> should be a
string containing the name of the symbol with optional sigil.

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
