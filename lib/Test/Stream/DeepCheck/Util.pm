package Test::Stream::DeepCheck::Util;
use strict;
use warnings;

use Scalar::Util qw/looks_like_number/;

use Test::Stream::Exporter;
exports qw/yada render_var/;
no Test::Stream::Exporter;

my $VAR_STRING = \'...';

sub yada { $VAR_STRING }

sub render_var {
    my ($it, $stringify) = @_;

    return 'undef' unless defined $it;
    return "$$it"  if ref $it && $it == $VAR_STRING;

    # ' is preferred
    my $q = ($it =~ m/'/ && $it !~ m/"/) ? '"' : "'";

    my $st = $it;
    $st =~ s/\\/\\\\/g;
    $st =~ s/$q/\\$q/g;

    return "$q$st$q" if $stringify;
    return   "$it"   if ref $it;
    return   "$it"   if looks_like_number($it);
    return "$q$st$q";
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::DeepCheck::Util - Reusable components of Test-Stream-DeepCheck

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

This library holds things used by various components that get reused in other
Test-Stream-DeepCheck classes.

=head1 SYNOPSIS

    use Test::Stream::DeepCheck::Util qw/render_var yada/;

    print render_var($var);
    print render_var(yada());
    print render_var($var, 1); # force quote wrapping

=head1 EXPORTS

=over 4

=item $string = render_var($var)

=item $string = render_var($var, $stringify)

This takes the variable C<$var> which can be anything, a reference, a string, a
numbers, etc. And returns the most hepful representation of that variable for
display in diagnostics. If stringify is set to true then B<most> things will be
returned wrapped in single-quotes.

=item yada()

This returns a reference that always renders as '...' when passed to
C<render_var()>.

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

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
