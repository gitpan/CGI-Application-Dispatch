package MyApp::DispatchTable;
use base 'CGI::Application::Dispatch';

sub dispatch_args {
    return {
        prefix  => 'MyApp',
        table   => [
            ':app'                => { },
            ':app/:rm'            => { },
            ':app/:rm/:my_param'  => { },
            ':app/bar/:my_param'  => { rm => 'rm3' },
            ':app/foo/:my_param?' => { rm => 'rm3' },
            'foo/bar'             => { app => 'Name', rm => 'rm2', prefix => 'MyApp::Module' },
        ],
    };
}

1;
