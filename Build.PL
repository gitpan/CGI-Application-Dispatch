use Module::Build;

my $build = Module::Build->new (
        module_name         => 'CGI::Application::Dispatch',
        license             => 'perl',
        requires            => {
                                'perl'              => '5.6.1',
                                'CGI::Application'  => '3.2',
                                },
        build_requires      => {
                                'Apache::FakeRequest' => 0,
                                },
        module_name         => 'CGI::Application::Dispatch',
        create_makefile_pl  => 'traditional',
   );

$build->create_build_script;

