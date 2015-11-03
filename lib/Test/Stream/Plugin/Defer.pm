package Test::Stream::Plugin::Defer;
use strict;
use warnings;

use Test::Stream::DeferredTests;

use Test::Stream::Exporter;
default_exports qw/def do_def/;
no Test::Stream::Exporter;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::Defer - Write tests that get executaed at a later time

=head1 DESCRIPTION

This is the plugin form of L<Test::Stream::DeferredTests>.

=head1 SYNOPSIS

    use strict;
    use warnings;

    use Test::Stream '-V1', 'Defer';

    # Declare some more tests to run later:
    def ok => (1, "another pass");
    ...

    do_def(); # run the new tests

    done_testing;

=head1 EXPORTS

=over 4

=item def function => @args;

This will store the function name, and the arguments to be run later. Note that
each package has a separate store of tests to run.

=item do_def()

This will run all the stored tests. It will also reset the list to be empty so
you can add more tests to run even later.

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
