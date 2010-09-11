package Test::Builder2::Mouse::Util;
use Test::Builder2::Mouse::Exporter; # enables strict and warnings

# must be here because it will be refered by other modules loaded
sub get_linear_isa($;$); ## no critic

# must be here because it will called in Test::Builder2::Mouse::Exporter
sub install_subroutines {
    my $into = shift;

    while(my($name, $code) = splice @_, 0, 2){
        no strict 'refs';
        no warnings 'once', 'redefine';
        use warnings FATAL => 'uninitialized';
        *{$into . '::' . $name} = \&{$code};
    }
    return;
}

BEGIN{
    # This is used in Test::Builder2::Mouse::PurePerl
    Test::Builder2::Mouse::Exporter->setup_import_methods(
        as_is => [qw(
            find_meta
            does_role
            resolve_metaclass_alias
            apply_all_roles
            english_list

            load_class
            is_class_loaded

            get_linear_isa
            get_code_info

            get_code_package
            get_code_ref

            not_supported

            does meta dump
        )],
        groups => {
            default => [], # export no functions by default

            # The ':meta' group is 'use metaclass' for Mouse
            meta    => [qw(does meta dump)],
        },
    );


    # Because Test::Builder2::Mouse::Util is loaded first in all the Mouse sub-modules,
    # XS loader is placed here, not in Test/Builder2/Mouse.pm.

    our $VERSION = '0.64';

    my $xs = 0; #!(exists $INC{'Test/Builder2/Mouse/PurePerl.pm'} || $ENV{MOUSE_PUREPERL});

    if($xs){
        # XXX: XSLoader tries to get the object path from caller's file name
        #      $hack_mouse_file fools its mechanism

        (my $hack_mouse_file = __FILE__) =~ s/.Util//; # .../Test/Builder2/Mouse/Util.pm -> .../Test/Builder2/Mouse.pm
        $xs = eval sprintf("#line %d %s\n", __LINE__, $hack_mouse_file) . q{
            local $^W = 0; # work around 'redefine' warning to &install_subroutines
            require XSLoader;
            XSLoader::load('Test::Builder2::Mouse', $VERSION);
            Test::Builder2::Mouse::Util->import({ into => 'Test::Builder2::Mouse::Meta::Method::Constructor::XS' }, ':meta');
            Test::Builder2::Mouse::Util->import({ into => 'Test::Builder2::Mouse::Meta::Method::Destructor::XS'  }, ':meta');
            Test::Builder2::Mouse::Util->import({ into => 'Test::Builder2::Mouse::Meta::Method::Accessor::XS'    }, ':meta');
            return 1;
        } || 0;
        #warn $@ if $@;
    }

    if(!$xs){
        require 'Test/Builder2/Mouse/PurePerl.pm'; # we don't want to create its namespace
    }

    *MOUSE_XS = sub(){ $xs };
}

use Carp         ();
use Scalar::Util ();

# aliases as public APIs
# it must be 'require', not 'use', because Test::Builder2::Mouse::Meta::Module depends on Test::Builder2::Mouse::Util
require Test::Builder2::Mouse::Meta::Module; # for the entities of metaclass cache utilities

# aliases
{
    *class_of                    = \&Test::Builder2::Mouse::Meta::Module::_class_of;
    *get_metaclass_by_name       = \&Test::Builder2::Mouse::Meta::Module::_get_metaclass_by_name;
    *get_all_metaclass_instances = \&Test::Builder2::Mouse::Meta::Module::_get_all_metaclass_instances;
    *get_all_metaclass_names     = \&Test::Builder2::Mouse::Meta::Module::_get_all_metaclass_names;

    *Test::Builder2::Mouse::load_class           = \&load_class;
    *Test::Builder2::Mouse::is_class_loaded      = \&is_class_loaded;

    # is-a predicates
    #generate_isa_predicate_for('Test::Builder2::Mouse::Meta::TypeConstraint' => 'is_a_type_constraint');
    #generate_isa_predicate_for('Test::Builder2::Mouse::Meta::Class'          => 'is_a_metaclass');
    #generate_isa_predicate_for('Test::Builder2::Mouse::Meta::Role'           => 'is_a_metarole');

    # duck type predicates
    generate_can_predicate_for(['_compiled_type_constraint']  => 'is_a_type_constraint');
    generate_can_predicate_for(['create_anon_class']          => 'is_a_metaclass');
    generate_can_predicate_for(['create_anon_role']           => 'is_a_metarole');
}

our $in_global_destruction = 0;
END{ $in_global_destruction = 1 }

# Moose::Util compatible utilities

sub find_meta{
    return class_of( $_[0] );
}

sub does_role{
    my ($class_or_obj, $role_name) = @_;

    my $meta = class_of($class_or_obj);

    (defined $role_name)
        || ($meta || 'Test::Builder2::Mouse::Meta::Class')->throw_error("You must supply a role name to does()");

    return defined($meta) && $meta->does_role($role_name);
}

BEGIN {
    my $get_linear_isa;
    if ($] >= 5.009_005) {
        require mro;
        $get_linear_isa = \&mro::get_linear_isa;
    } else {
        # this code is based on MRO::Compat::__get_linear_isa
        my $_get_linear_isa_dfs; # this recurses so it isn't pretty
        $_get_linear_isa_dfs = sub {
            my($classname) = @_;

            my @lin = ($classname);
            my %stored;

            no strict 'refs';
            foreach my $parent (@{"$classname\::ISA"}) {
                foreach  my $p(@{ $_get_linear_isa_dfs->($parent) }) {
                    next if exists $stored{$p};
                    push(@lin, $p);
                    $stored{$p} = 1;
                }
            }
            return \@lin;
        };

        {
            package # hide from PAUSE
                Class::C3;
            our %MRO; # work around 'once' warnings
        }

        # MRO::Compat::__get_linear_isa has no prototype, so
        # we define a prototyped version for compatibility with core's
        # See also MRO::Compat::__get_linear_isa.
        $get_linear_isa = sub ($;$){
            my($classname, $type) = @_;

            if(!defined $type){
                $type = exists $Class::C3::MRO{$classname} ? 'c3' : 'dfs';
            }
            if($type eq 'c3'){
                require Class::C3;
                return [Class::C3::calculateMRO($classname)];
            }
            else{
                return $_get_linear_isa_dfs->($classname);
            }
        };
    }

    *get_linear_isa = $get_linear_isa;
}


# taken from Test::Builder2::Mouse::Util (0.90)
{
    my %cache;

    sub resolve_metaclass_alias {
        my ( $type, $metaclass_name, %options ) = @_;

        my $cache_key = $type . q{ } . ( $options{trait} ? '-Trait' : '' );

        return $cache{$cache_key}{$metaclass_name} ||= do{

            my $possible_full_name = join '::',
                'Test::Builder2::Mouse::Meta', $type, 'Custom', ($options{trait} ? 'Trait' : ()), $metaclass_name
            ;

            my $loaded_class = load_first_existing_class(
                $possible_full_name,
                $metaclass_name
            );

            $loaded_class->can('register_implementation')
                ? $loaded_class->register_implementation
                : $loaded_class;
        };
    }
}

# Utilities from Class::MOP

sub get_code_info;
sub get_code_package;

sub is_valid_class_name;

# taken from Class/MOP.pm
sub load_first_existing_class {
    my @classes = @_
      or return;

    my %exceptions;
    for my $class (@classes) {
        my $e = _try_load_one_class($class);

        if ($e) {
            $exceptions{$class} = $e;
        }
        else {
            return $class;
        }
    }

    # not found
    Carp::confess join(
        "\n",
        map {
            sprintf( "Could not load class (%s) because : %s",
                $_, $exceptions{$_} )
          } @classes
    );
}

# taken from Class/MOP.pm
sub _try_load_one_class {
    my $class = shift;

    unless ( is_valid_class_name($class) ) {
        my $display = defined($class) ? $class : 'undef';
        Carp::confess "Invalid class name ($display)";
    }

    return '' if is_class_loaded($class);

    $class  =~ s{::}{/}g;
    $class .= '.pm';

    return do {
        local $@;
        eval { require $class };
        $@;
    };
}


sub load_class {
    my $class = shift;
    my $e = _try_load_one_class($class);
    Carp::confess "Could not load class ($class) because : $e" if $e;

    return $class;
}

sub is_class_loaded;

sub apply_all_roles {
    my $consumer = Scalar::Util::blessed($_[0])
        ?                                shift   # instance
        : Test::Builder2::Mouse::Meta::Class->initialize(shift); # class or role name

    my @roles;

    # Basis of Data::OptList
    my $max = scalar(@_);
    for (my $i = 0; $i < $max ; $i++) {
        if ($i + 1 < $max && ref($_[$i + 1])) {
            push @roles, [ $_[$i] => $_[++$i] ];
        } else {
            push @roles, [ $_[$i] => undef ];
        }
        my $role_name = $roles[-1][0];
        load_class($role_name);

        is_a_metarole( get_metaclass_by_name($role_name) )
            || $consumer->meta->throw_error("You can only consume roles, $role_name is not a Mouse role");
    }

    if ( scalar @roles == 1 ) {
        my ( $role_name, $params ) = @{ $roles[0] };
        get_metaclass_by_name($role_name)->apply( $consumer, defined $params ? $params : () );
    }
    else {
        Test::Builder2::Mouse::Meta::Role->combine(@roles)->apply($consumer);
    }
    return;
}

# taken from Moose::Util 0.90
sub english_list {
    return $_[0] if @_ == 1;

    my @items = sort @_;

    return "$items[0] and $items[1]" if @items == 2;

    my $tail = pop @items;

    return join q{, }, @items, "and $tail";
}

sub quoted_english_list {
    return english_list(map { qq{'$_'} } @_);
}

# common utilities

sub not_supported{
    my($feature) = @_;

    $feature ||= ( caller(1) )[3]; # subroutine name

    local $Carp::CarpLevel = $Carp::CarpLevel + 1;
    Carp::confess("Mouse does not currently support $feature");
}

# general meta() method
sub meta :method{
    return Test::Builder2::Mouse::Meta::Class->initialize(ref($_[0]) || $_[0]);
}

# general dump() method
sub dump :method {
    my($self, $maxdepth) = @_;

    require 'Data/Dumper.pm'; # we don't want to create its namespace
    my $dd = Data::Dumper->new([$self]);
    $dd->Maxdepth(defined($maxdepth) ? $maxdepth : 3);
    $dd->Indent(1);
    return $dd->Dump();
}

# general does() method
sub does :method {
    goto &does_role;
}

1;
__END__

=head1 NAME

Test::Builder2::Mouse::Util - Features, with or without their dependencies

=head1 VERSION

This document describes Mouse version 0.64

=head1 IMPLEMENTATIONS FOR

=head2 Moose::Util

=head3 C<find_meta>

=head3 C<does_role>

=head3 C<resolve_metaclass_alias>

=head3 C<apply_all_roles>

=head3 C<english_list>

=head2 Class::MOP

=head3 C<< is_class_loaded(ClassName) -> Bool >>

Returns whether C<ClassName> is actually loaded or not. It uses a heuristic which
involves checking for the existence of C<$VERSION>, C<@ISA>, and any
locally-defined method.

=head3 C<< load_class(ClassName) >>

This will load a given C<ClassName> (or die if it is not loadable).
This function can be used in place of tricks like
C<eval "use $module"> or using C<require>.

=head3 C<< Test::Builder2::Mouse::Util::class_of(ClassName or Object) >>

=head3 C<< Test::Builder2::Mouse::Util::get_metaclass_by_name(ClassName) >>

=head3 C<< Test::Builder2::Mouse::Util::get_all_metaclass_instances() >>

=head3 C<< Test::Builder2::Mouse::Util::get_all_metaclass_names() >>

=head2 MRO::Compat

=head3 C<get_linear_isa>

=head2 Sub::Identify

=head3 C<get_code_info>

=head1 Mouse specific utilities

=head3 C<not_supported>

=head3 C<get_code_package>

=head3 C<get_code_ref>

=head1 SEE ALSO

L<Moose::Util>

L<Class::MOP>

L<Sub::Identify>

L<MRO::Compat>

=cut

