my $build_pkg = eval "require Apache::TestMB" ? 'Apache::TestMB' : 'Module::Build';
my $build = $build_pkg->new(
    module_name => 'CGI::Application::Dispatch',
    license     => 'perl',
    requires    => {
        'perl'                       => '5.6.0',
        'CGI::Application'           => '3.2',
        'Exception::Class'           => 0,
        'Exception::Class::TryCatch' => 0,
    },
    recommends => {
        'Apache::Test'   => 1.30,
        'Apache::TestMB' => 0,
    },
    build_requires => {
        'Test::More'       => 0,
        'Test::LongString' => 0,
    },
);

$build->create_build_script;

