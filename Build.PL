my $build_pkg = eval "require Apache::Test" ? 'Apache::TestMB' : 'Module::Build';
eval "require $build_pkg";
my $build = $build_pkg->new(
    module_name => 'CGI::Application::Dispatch',
    license     => 'perl',
    requires    => {
        'perl'                       => '5.6.0',
        'CGI::Application'           => '3.2',
        'Exception::Class'           => 0,
        'Exception::Class::TryCatch' => 0,
    },
    build_requires => {
        'Test::More'       => 0,
        'Test::LongString' => 0,
    },
    create_makefile_pl => 'traditional',
);

$build->create_build_script;

