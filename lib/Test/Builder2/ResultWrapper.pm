package Test::Builder2::ResultWrapper;

my $CLASS = __PACKAGE__;

=head1 NAME

Test::Builder2::ResultWrapper

==head1 SYNOPSIS

    use Test::Builder2::Result;

    my $wrapper = Test::Builder2::ResultWrapper->new($result, $output);

=head1 DESCRIPTION

=head3 new

  my $wrapper = Test::Builder2::ResultWrapper->new(result => $result, output => $output);

new() creates a new wrapper object that when destroyed displays the
result object.  The purpose of the wrapper is to allow you time to
query and add extra information to the result object before it is
displayed.  

Be careful about how you use it though because if you aren't careful
to ensure it's destroyed promptly you will end up with test results
displayed out of order.  The number of the test is determined before
the object is created so you need to ensure they are destroyed in
the correct order.

=cut

sub new {
    my $class = shift;
    my %args = @_;
    return bless \%args, $class;
}

{

    # stolen (and probably broken)
    # from perl critic Document.pm
    our $AUTOLOAD;
    sub AUTOLOAD {  
        my ( $function_name ) = $AUTOLOAD =~ m/ ([^:\']+) \z /xms;
        return if $function_name eq 'DESTROY';
        my $self = shift;
        return $self->{_result}->$function_name(@_);
    }

}

sub DESTROY
{
    my $self = shift;
    $self->{_output}->result($self->{_result});
}

1;
