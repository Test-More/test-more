package Test::Builder2::Tester;

use Test::Builder2::Mouse;
with "Test::Builder2::CanTry";

use Exporter 'import';
our @EXPORT = qw(capture result_like event_like);
my $CLASS = __PACKAGE__;


=head1 NAME

Test::Builder2::Tester - Testing a Test:: module

=head1 SYNOPSIS

    use Test::More;
    use Your::Test::Module qw(this_ok that_ok);
    use Test::Builder2::Tester;

    my $capture = capture {
        this_ok $this, "some name";
        that_ok $that;
    };

    # The first one passed, and it has a name
    result_like $capture->results->[0], {
        pass => 1,
        name => "some name",
    };

    # The second one failed, and it has no name
    result_like $capture->results->[1], {
        pass => 0,
        name => ''
    };

=head1 DESCRIPTION

This is a module for testing Test modules.

=head1 Exports

These are exported by default

=head3 capture

    my $capture = capture { ...test code ... };

Captures all the events and results which happens inside the block.

Returns a L<Test::Builder2::Tester::Capture> (which is largely a
L<Test::Builder2::History>) that you can reference later.

=cut

sub capture(&) {
    my $code = shift;

    require Test::Builder2::EventCoordinator;
    my $ec = Test::Builder2::EventCoordinator->singleton;
    my $real_ec = $ec->real_coordinator;

    my $our_ec = $real_ec->create;
    $our_ec->clear_formatters;

    $ec->real_coordinator($our_ec);
    
    my($ret, $err) = $CLASS->try(sub { $code->(); 1; });

    $ec->real_coordinator($real_ec);

    die $err if $err;

    return $our_ec->history;
}

=head3 result_like

=head3 event_like

=cut

no Test::Builder2::Mouse;

1;
