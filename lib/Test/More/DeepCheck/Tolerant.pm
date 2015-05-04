package Test::More::DeepCheck::Tolerant;
use strict;
use warnings;

use Test::More::Tools;
use Scalar::Util qw/reftype blessed/;
use Test::Stream::Util qw/try unoverload_str is_regex/;

use Test::Stream::HashBase(
    base => 'Test::More::DeepCheck',
);

sub preface { "First mismatch:\n" };

sub check {
    my $class = shift;
    my ($got, $expect) = @_;

    unoverload_str(\$got, \$expect);
    my $self = $class->new();

    # neither is a reference
    return tmt->is_eq($got, $expect)
        if !ref $got and !ref $expect;

    push @{$self->{+STACK}} => {type => '', vals => [$got, $expect], line => __LINE__};
    my $ok = $self->_deep_check($got, $expect);
    return ($ok, $ok ? () : $self->format_stack);
}

#============================

sub _reftype {
    my ($thing) = @_;
    my $type = reftype $thing || return '';

    $type = uc($type);

    return $type unless $type eq 'SCALAR';

    $type = 'REGEXP' if $type eq 'REGEX' || defined is_regex($thing);

    return $type;
}

sub _nonref_check {
    my ($self) = shift;
    my ($got, $expect) = @_;

    my $numeric = $got !~ m/\D/i && $expect !~ m/\D/i;
    return $numeric ? $got == $expect : "$got" eq "$expect";
}

sub _deep_check {
    my ($self) = shift;
    my ($got, $expect) = @_;

    return 1 unless defined($got) ||  defined($expect);
    return 0 if     defined($got) xor defined($expect);

    my $seen = $self->{+SEEN}->[-1];
    return 1 if $seen->{$got} && $seen->{$got} eq $expect;
    $seen->{$got} = "$expect";

    my $etype = _reftype $expect;
    my $gtype = _reftype $got;

    return 0 if ($etype && $etype ne 'REGEXP' && !$gtype) || ($gtype && !$etype);

    return $self->_nonref_check($got, $expect) unless $etype;

    ##### Both are refs at this point ####
    return 1 if $gtype && $got == $expect;

    if ($etype eq 'REGEXP') {
        return "$got" eq "$expect" if $gtype eq 'REGEXP'; # Identical regexp check
        return $got =~ $expect;
    }

    my $ok = 0;
    $seen = {%$seen};
    push @{$self->{+SEEN}} => $seen;
    if ($etype eq 'ARRAY') {
        $ok = $self->_array_check($got, $expect);
    }
    elsif ($etype eq 'HASH') {
        $ok = $self->_hash_check($got, $expect);
    }
    pop @{$self->{+SEEN}};

    return $ok;
}

sub _array_check {
    my $self = shift;
    my ($got, $expect) = @_;

    return 0 if _reftype($got) ne 'ARRAY';

    for (my $i = 0; $i < @$expect; $i++) {
        push @{$self->{+STACK}} => {type => 'ARRAY', idx => $i, vals => [$got->[$i], $expect->[$i]], line => __LINE__};
        $self->_deep_check($got->[$i], $expect->[$i]) || return 0;
        pop @{$self->{+STACK}};
    }

    return 1;
}

sub _hash_check {
    my $self = shift;
    my ($got, $expect) = @_;

    my $blessed  = blessed($got);
    my $hashref  = _reftype($got) eq 'HASH';
    my $arrayref = _reftype($got) eq 'ARRAY';

    for my $key (sort keys %$expect) {
        #                                             $wrap   $direct  $field   Leftover from wrap
        my ($wrap, $direct, $field) = ($key =~ m/^  ([\[\{]?)   (:?)   ([^\]]*) [\]\}]?$/x);

        if ($wrap) {
            if (!$blessed) {
                push @{$self->{+STACK}} => {
                    type  => 'OBJECT',
                    idx   => $field,
                    wrap  => $wrap,
                    vals  => ["(EXCEPTION)", $expect->{$key}],
                    error => "Cannot call method '$field' on an unblessed reference.\n",
                    line  => __LINE__,
                };
                return 0;
            }
            if ($direct) {
                push @{$self->{+STACK}} => {
                    type  => 'OBJECT',
                    idx   => $field,
                    wrap  => $wrap,
                    vals  => ['(EXCEPTION)', $expect->{$key}],
                    error => "'$key' is invalid, cannot wrap($wrap) a direct-access($direct).\n",
                    line  => __LINE__,
                };
                return 0;
            }
        }

        my ($val, $type);
        if ($direct || !$blessed) {
            if ($arrayref) {
                $type = 'ARRAY';
                if ($field !~ m/^-?\d+$/i) {
                    push @{$self->{+STACK}} => {
                        type  => 'ARRAY',
                        idx   => $field,
                        vals  => ['(EXCEPTION)', $expect->{$key}],
                        error => "'$field' is not a valid array index\n",
                        line  => __LINE__,
                    };
                    return 0;
                }

                # Try, if they specify -1 in an empty array it may throw an exception
                my ($success, $error) = try { $val = $got->[$field] };
                if (!$success) {
                    push @{$self->{+STACK}} => {
                        type  => 'ARRAY',
                        idx   => $field,
                        vals  => ['(EXCEPTION)', $expect->{$key}],
                        error => $error,
                        line  => __LINE__,
                    };
                    return 0;
                }
            }
            else {
                $type = 'HASH';
                $val  = $got->{$field};
            }
        }
        else {
            $type = 'OBJECT';
            my ($success, $error) = try {
                if ($wrap) {
                    if ($wrap eq '[') {
                        $val = [$got->$field()];
                    }
                    elsif ($wrap eq '{') {
                        $val = {$got->$field()};
                    }
                    else {
                        die "'$wrap' is not a valid way to wrap a method call";
                    }
                }
                else {
                    $val = $got->$field();
                }
            };
            if (!$success) {
                push @{$self->{+STACK}} => {
                    type  => 'OBJECT',
                    idx   => $field,
                    wrap  => $wrap || undef,
                    vals  => ['(EXCEPTION)', $expect->{$key}],
                    error => $error,
                    line  => __LINE__,
                };
                return 0;
            }
        }

        push @{$self->{+STACK}} => {type => $type, idx => $field, vals => [$val, $expect->{$key}], line => __LINE__, wrap => $wrap || undef};
        $self->_deep_check($val, $expect->{$key}) || return 0;
        pop @{$self->{+STACK}};
    }

    return 1;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::More::DeepCheck::Tolerant - Under the hood implementation of
mostly_like()

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head2 BACKWARDS COMPATABILITY SHIM

By default, loading Test-Stream will block Test::Builder and related namespaces
from loading at all. You can work around this by loading the compatability shim
which will populate the Test::Builder and related namespaces with a
compatability implementation on demand.

    use Test::Stream::Shim;
    use Test::Builder;
    use Test::More;

B<Note:> Modules that are experimenting with Test::Stream should NOT load the
shim in their module files. The shim should only ever be loaded in a test file.


=head1 DESCRIPTION

This is where L<Test::MostlyLike> is implemented.

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
