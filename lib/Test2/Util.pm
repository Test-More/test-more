package Test2::Util;
use strict;
use warnings;

use Test2::Capabilities qw/CAN_THREAD/;

our @EXPORT_OK = qw{
    try protect

    get_tid USE_THREADS

    pkg_to_file
};
use base 'Exporter';

sub _manual_protect(&) {
    my $code = shift;

    my ($ok, $error);
    {
        my ($msg, $no) = ($@, $!);
        $ok = eval {
            $code->();
            1
        } || 0;
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
        $ok = eval {
            $code->();
            1
        } || 0;
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

        $ok = eval {
            $code->(@$args);
            1
        } || 0;
        unless($ok) {
            $error = $@ || "Error was squashed!\n";
        }

        ($@, $!) = ($msg, $no);
        if ($die) {
            $SIG{__DIE__} = $die;
        }
        else {
            delete $SIG{__DIE__};
        }
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
        $ok = eval {
            $code->(@$args);
            1
        } || 0;
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
    $file =~ s{(::|')}{/}g;
    $file .= '.pm';
    return $file;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Util - Tools used by Test2 and friends.

=head1 DESCRIPTION

Collection of tools used by L<Test2> and friends.

=head1 EXPORTS

All exports are optional, you must specify subs to import.

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

=back

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

=item Kent Fredric E<lt>kentnl@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
