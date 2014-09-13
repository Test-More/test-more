package Test::Stream::Deferred;
use strict;
use warnings;

my %LOADED;

sub load {
    my $class = shift;
    my ($file, $line, $module, $import) = @_;

    my $new_pkg = join '::' => $class, $module;
    unless ($LOADED{$module}) {
        my ($ok, $error);
        {
            local ($@, $!, $SIG{__DIE__});
            $ok = eval qq{#line $line "$file"\nrequire $module; 1};
            $error = $@;
        }
        die $error unless $ok;
        $LOADED{$module} = $new_pkg;
    }

    my $sub = $new_pkg->can($import);
    return $sub if $sub;

    my ($ok, $error);
    {
        local ($@, $!, $SIG{__DIE__});
        $ok = eval qq{package $new_pkg;\n#line $line "$file"\n\$module->import(\$import); 1};
        $error = $@;
    }
    die $error unless $ok;

    return $new_pkg->can($import);
}

sub import {
    my $class = shift;
    my ($importer, $file, $line) = caller;
    my ($module, @imports) = @_;

    for my $import (@imports) {
        no strict 'refs';

        my $loaded;
        *{"$importer\::$import"} = sub {
            unless($loaded) {
                $loaded = $class->load($file, $line, $module, $import);
                die "module '$module' does not export '$import' at $file line $line\n" unless $loaded;
            }
            goto &$loaded;
        };
    }
}

1;
