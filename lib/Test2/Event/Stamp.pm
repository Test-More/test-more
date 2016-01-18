package Test2::Event::Stamp;
use strict;
use warnings;

use Time::HiRes qw/time/;
use Carp qw/croak/;

use base 'Test2::Event';
use Test2::Util::HashBase qw/stamp name action/;

sub init {
    my $self = shift;

    $self->{+STAMP} ||= time();
    $self->{+NAME}  ||= 'unknown';

    croak "'action' is a required attribute"
        unless defined $self->{+ACTION};
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Event::Stamp - Event that records a timestamp for an action.

=head1 *** EXPERIMENTAL ***

This distribution is experimental, anything can change at any time!

=head1 DESCRIPTION

Not used yet, but will be.

=head1 SYNOPSIS

    sub tool {
        my $ctx = context();

        ...
        $ctx->send_event('Stamp', action => 'eat', name => 'food');
        ...

        $ctx->release;
    }

=head1 ATTRIBUTES

=over 4

=item action (required)

This is the action being stamped.

=item name

Defaults to 'unknown'

=item stamp

The timestamp, set for you using C<Time::HiRes::time()>.

=back

=head1 SOURCE

The source code repository for Test2-Workflow can be found at
F<http://github.com/Test-More/Test2-Workflow/>.

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

See F<http://dev.perl.org/licenses/>

=cut

