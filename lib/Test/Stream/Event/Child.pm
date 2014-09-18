package Test::Stream::Event::Child;
use strict;
use warnings;

use Test::Stream::Carp qw/confess/;
use Test::Stream::Event;
BEGIN {
    accessors qw/action name no_note/;
    Test::Stream::Event->cleanup;
};

sub init {
    confess "did not get an action" unless $_[0]->[ACTION];
    confess "action must be either 'push' or 'pop', not '$_[0]->[ACTION]'"
        unless $_[0]->[ACTION] =~ m/^(push|pop)$/;

    $_[0]->[NAME] ||= "";
}

1;

__END__

=head1 NAME

Test::Stream::Event::Child - Child event type

=head1 DESCRIPTION

Sent when a child Builder is spawned, such as a subtest.

=head1 METHODS

See L<Test::Stream::Event> which is the base class for this module.

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
