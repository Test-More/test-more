use Test2::Bundle::Extended -target => 'Test2::Workflow::Task::Group';

can_ok($CLASS, qw/before after primary rand variant/);

done_testing;

__END__


sub init {
    my $self = shift;

    if (my $take = delete $self->{take}) {
        $self->{$_} = delete $take->{$_} for ISO, ASYNC, TODO, SKIP;
        $self->{$_} = $take->{$_} for FLAT, SCAFFOLD, NAME, CODE, FRAME;
        $take->{+FLAT}     = 1;
        $take->{+SCAFFOLD} = 1;
    }

    {
        local $Carp::CarpLevel = $Carp::CarpLevel + 1;
        $self->SUPER::init();
    }

    $self->{+BEFORE}  ||= [];
    $self->{+AFTER}   ||= [];
    $self->{+PRIMARY} ||= [];
}

sub filter {
    my $self = shift;
    my ($filter) = @_;

    return if $self->{+IS_ROOT};

    my $result = $self->SUPER::filter($filter);

    my $child_ok = 0;
    for my $c (@{$self->{+PRIMARY}}) {
        next if $c->{+SCAFFOLD};
        # A child matches the filter, so we should not be filtered, but also
        # should not satisfy the filter.
        my $res = $c->filter($filter);

        # A child satisfies the filter
        $child_ok++ if !$res || $res->{satisfied};
        last if $child_ok;
    }

    # If the filter says we are ok
    unless($result) {
        # If we are a variant then allow everything under us to be run
        return {satisfied => 1} if $self->{+VARIANT} || !$child_ok;

        # Normal group
        return;
    }

    return if $child_ok;

    return $result;
}
