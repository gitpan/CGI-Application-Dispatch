use Module::Build;
my $build_pkg = eval { require Apache::TestMB }
      ? 'Apache::TestMB' : 'Module::Build';

my $build = $build_pkg->new (
        module_name         => 'CGI::Application::Dispatch',
        license             => 'perl',
        requires            => {
                    'perl'              => '5.6.0',
                    'CGI::Application'  => '3.2',
                    'Test::More'        => 0,
                    },
        build_requires      => {
                    'Apache::Test'  => '1.16',
                    },
        module_name         => 'CGI::Application::Dispatch',
        create_makefile_pl  => 'passthrough',
   );

$build->create_build_script;

