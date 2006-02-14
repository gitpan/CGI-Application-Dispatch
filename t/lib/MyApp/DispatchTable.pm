package MyApp::DispatchTable;
use base 'CGI::Application::Dispatch';

sub dispatch_args {
    return {
        prefix  => 'MyApp',
        table   => [
            'foo/bar'             => { app => 'Name', rm => 'rm2', prefix => 'MyApp::Module' },
            ':app/bar/:my_param'  => { rm => 'rm3' },
            ':app/foo/:my_param?' => { rm => 'rm3' },
            ':app/:rm/:my_param'  => { },
            ':app/:rm'            => { },
            ':app'                => { },
            ''                    => { app => 'Module::Name', rm => 'rm1' },
        ],
    };
}

1;
