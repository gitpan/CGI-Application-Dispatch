use Test::More qw(no_plan);
use strict;
use lib './t';

# 1..2
require_ok('CGI::Application::Dispatch');
require_ok('Cgiappdispatchtestmodule');

# 3
{
    local $ENV{PATH_INFO} = '/module_name/mode1';
    eval {
        CGI::Application::Dispatch->dispatch();
    };

    like($@, qr/Can't locate Module\/Name.pm/, 'dispatch(): module_name');
}

# 4
{
    local $ENV{PATH_INFO} = '/module_name/mode1';
    eval {
        CGI::Application::Dispatch->dispatch(CGIAPP_DISPATCH_PREFIX => 'MyApp');
    };

    like($@, qr/Can't locate MyApp\/Module\/Name.pm/, 'dispatch(): prefix');
}

# 5
{
    local $ENV{PATH_INFO} = '/cgiappdispatchtestmodule/rm2';
    local $ENV{CGI_APP_RETURN_ONLY} = '1';
    my $output;
    $output = CGI::Application::Dispatch->dispatch(
                    PREFIX => '',
                    RM => 1,
                );
    like($output, qr/rm2/, 'RM true');
}

# 6
{
    local $ENV{PATH_INFO} = '/cgiappdispatchtestmodule/rm2';
    local $ENV{CGI_APP_RETURN_ONLY} = '1';
    my $output;
    $output = CGI::Application::Dispatch->dispatch(
                    PREFIX => '',
                    RM => 0,
                );
    like($output, qr/rm1/, 'RM false');
}





