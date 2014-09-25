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

    if ($pattern =~ m{^ /(.*)/ (\w*) $ }sx) {
        protect { ($re, $opts) = ($1, $2) };
    }
    elsif ($pattern =~ m,^ m([^\w\s]) (.+) \1 (\w*) $,sx) {
        protect { ($re, $opts) = ($2, $3) };
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
