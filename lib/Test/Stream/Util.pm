package Test::Stream::Util;
use strict;
use warnings;

use Scalar::Util qw/reftype blessed/;
use Test::Stream::Exporter qw/import export_to exports/;

exports qw{
    try protect is_regex is_dualvar
    unoverload unoverload_str unoverload_num
};

Test::Stream::Exporter->cleanup();

sub protect(&) {
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

sub try(&) {
    my $code = shift;
    my $error;
    my $ok;

    {
        local ($@, $!, $SIG{__DIE__});
        $ok = eval { $code->(); 1 } || 0;
        unless($ok) {
            $error = $@ || "Error was squashed!\n";
        }
    }

    return wantarray ? ($ok, $error) : $ok;
}

sub is_regex {
    my ($pattern) = @_;

    return undef unless defined $pattern;

    return $pattern if defined &re::is_regexp
                    && re::is_regexp($pattern);

    my $type = reftype($pattern) || '';

    return $pattern if $type =~ m/^regexp?$/i;
    return $pattern if $type eq 'SCALAR' && $pattern =~ m/^\(\?.+:.*\)$/s;
    return $pattern if !$type && $pattern =~ m/^\(\?.+:.*\)$/s;

    my ($re, $opts);

    if ( $pattern =~ m{^ /(.*)/ (\w*) $ }sx) {
        ($re, $opts) = ($1, $2);
    }
    elsif ($pattern =~ m,^ m([^\w\s]) (.+) \1 (\w*) $,sx) {
        ($re, $opts) = ($2, $3);
    }
    else {
        return;
    }

    return length $opts ? "(?$opts)$re" : $re;
}

sub unoverload_str { unoverload(q[""], @_) }

sub unoverload_num {
    unoverload('0+', @_);

    for my $val (@_) {
        next unless is_dualvar($$val);
        $$val = $$val + 0;
    }

    return;
}

# This is a hack to detect a dualvar such as $!
sub is_dualvar {
    my($val) = @_;

    # Objects are not dualvars.
    return 0 if ref $val;

    no warnings 'numeric';
    my $numval = $val + 0;
    return ($numval != 0 and $numval ne $val ? 1 : 0);
}

sub unoverload {
    my $type = shift;

    protect { require overload };

    for my $thing (@_) {
        if (blessed $$thing) {
            if (my $string_meth = overload::Method($$thing, $type)) {
                $$thing = $$thing->$string_meth();
            }
        }
    }
}


1;

__END__

=head1 NAME

Test::Stream::Util

=head1 DESCRIPTION

Tools for generating accessors and other object bits and pieces.

=head1 SYNOPSYS

    ...

=head1 EXPORTS

=over 4

=item $success = try { ... }

=item ($success, $error) = try { ... }

Eval the codeblock, return success or failure, and optionally the error
message. This code protects $@ and $!, they will be restored by the end of the
run. This code also temporarily blocks $SIG{DIE} handlers.

=item protect { ... }

Similar to try, except that it does not catch exceptions. The idea here is to
protect $@ and $! from changes. $@ and $! will be restored to whatever they
were before the run so long as it is successful. If the run fails $! will still
be restored, but $@ will contain the exception being thrown.

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 COPYRIGHT

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

