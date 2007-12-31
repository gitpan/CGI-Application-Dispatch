# make sure we have Module::Build so we can use it, else install it
unless(eval "use Module::Build::Compat 0.03; 1") {
    print "This module requires Module::Build to install itself.\n";

    require ExtUtils::MakeMaker;
    my $yn = ExtUtils::MakeMaker::prompt('  Install Module::Build now from CPAN?', 'y');

    unless($yn =~ /^y/i) {
        die " *** Cannot install without Module::Build.  Exiting ...\n";
    }

    require Cwd;
    require File::Spec;
    require CPAN;

    # Save this 'cause CPAN will chdir all over the place.
    my $cwd = Cwd::cwd();

    CPAN::Shell->install('Module::Build::Compat');
    CPAN::Shell->expand("Module", "Module::Build::Compat")->uptodate
      or die "Couldn't install Module::Build, giving up.\n";

    chdir $cwd or die "Cannot chdir() back to $cwd: $!";
}
eval "use Module::Build::Compat 0.02; 1" or die $@;

# see if they have Apache::Test, if not, ask if they want it
my $build_pkg = 'Module::Build';
unless(eval "use Apache::Test 1.30; 1") {
    print "This module can optionally use Apache::Test to test the mod_perl functionality.\n";
    my $yn = ExtUtils::MakeMaker::prompt('  Install Apache::Test now from CPAN?', 'y');

    if($yn =~ /^y/i) {
        # Save this 'cause CPAN will chdir all over the place.
        my $cwd = Cwd::cwd();

        CPAN::Shell->install('Apache::Test');
        if( CPAN::Shell->expand("Module", "Apache::Test")->uptodate ) {
            $build_pkg = 'Apache::TestMB';
        } else {
            print "Couldn't install Apache::Test, skipping mod_perl tests.\n";
        }

        chdir $cwd or die "Cannot chdir() back to $cwd: $!";
    }
}

Module::Build::Compat->run_build_pl(args => \@ARGV);
Module::Build::Compat->write_makefile(build_class => $build_pkg);
