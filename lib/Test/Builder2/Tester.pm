package Test::Builder2::Tester;

use Test::Builder2::Mouse;
with "Test::Builder2::CanTry";

use Test::Builder2::Module;
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
        is_pass => 1,
        name => "some name",
    };

    # The second one failed, and it has no name
    result_like $capture->results->[1], {
        is_pass => 0,
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

=head3 event_like

  event_like( $event, $want );
  event_like( $event, $want, $name );

Tests that a $result looks like what you $want.

$want is a hash ref of keys and values.  Each of these will be checked
against the $result's attributes.  For example...

    result_like( $result, { name => "foo" } );

will check that C<< $result->name eq "foo" >>.

Values can also be regular expressions.

    result_like( $result, { name => qr/foo/ } );

will check that C<< $result->name =~ /foo/ >>.

=cut

install_test event_like => sub($$;$) {
    my($have, $want, $name) = @_;

    $name ||= "event: ".($want->{event_type} || $have->event_type);

    my $ok = 1;
    for my $key (keys %$want) {
        my $have_val = $CLASS->try(sub { $have->$key });
        my $want_val = $want->{$key};

        $ok &= ref $want_val ? $have_val =~ $want_val
             :                 $have_val eq $want_val;
    }

    return Builder->ok($ok, $name);
};


=head3 result_like

  result_like( $result, $want );
  result_like( $result, $want, $name );

Works just as C<event_like> but it also checks the $result is a result.

=cut

install_test result_like => sub($$;$) {
    my($have, $want, $name) = @_;

    $name ||= "result: ".($want->{name} || $have->name || '');
    return Builder->ok(0, $name) if $have->event_type ne 'result';

    return event_like($have, $want, $name);
};


no Test::Builder2::Mouse;

1;
