package Test::Builder::Event::Child;
use strict;
use warnings;

use base 'Test::Builder::Event';

use Carp qw/confess/;
use Test::Builder::ArrayBase;
BEGIN {
    accessors qw/action name/;
    Test::Builder::ArrayBase->cleanup;
};

sub init {
    confess "did not get an action" unless $_[0]->[ACTION];
    confess "action must be either 'push' or 'pop', not '$_[0]->[ACTION]'"
        unless $_[0]->[ACTION] =~ m/^(push|pop)$/;

    $_[0]->[NAME] ||= "";
}

sub to_tap { }

1;

__END__

=head1 NAME

Test::Builder::Event::Child - Child event type

=head1 DESCRIPTION

Sent when a child Builder is spawned, such as a subtest.

=head1 METHODS

See L<Test::Builder::Event> which is the base class for this module.

=head2 CONSTRUCTORS

=over 4

=item $r = $class->new(...)

Create a new instance

=back

=head2 ATTRIBUTES

=over 4

=item $r->action

Either 'push' or 'pop'. When a child is created a push is sent, when a child
exits a pop is sent.

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
