use Test::More qw(no_plan);
use strict;

require_ok('CGI::Application::Dispatch');
$ENV{PATH_INFO} = '/module_name/mode1';

{
    eval {
        CGI::Application::Dispatch->dispatch();
    };

    like($@, qr/Can't locate Module\/Name.pm/, 'dispatch(): module_name');
}

{
    eval {
        CGI::Application::Dispatch->dispatch(CGIAPP_DISPATCH_PREFIX => 'MyApp');
    };

    like($@, qr/Can't locate MyApp\/Module\/Name.pm/, 'dispatch(): prefix');
}


