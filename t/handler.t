use Test::More qw(no_plan);
use strict;
use lib './t/lib';

#try to require Apache
eval { require Apache; };
if($@) {
    print "1..0 #Skipping handler() tests; no Apache module";
}


# 1
require_ok('CGI::Application::Dispatch');

#create an Apache::FakeRequest
require Apache::FakeRequest;
require Apache::URI;
require Apache::Constants;

my $request = Apache::FakeRequest->new();
my $code;
$ENV{CGI_APP_RETURN_ONLY} = 1;

# 2..4
{
    my $path_info = '/module_name/mode1';
    my $r = Apache::FakeRequest->new(
        path_info => $path_info, 
        dir_config => {},
    );

    eval { $code = CGI::Application::Dispatch::handler($r) };
    is($code, Apache::Constants::NOT_FOUND(), 'handler(): return code');

    like($CGI::Application::Dispatch::Error, qr/Can't locate Module\/Name.pm/, 'handler(): module_name');

    my $rm = CGI::Application::Dispatch::get_runmode($path_info);
    is($rm, 'mode1', 'handler(): run mode');
}


# 5..7
{
    my $path_info = '/module_name/mode1';
    my $r = Apache::FakeRequest->new(
        path_info => $path_info, 
        dir_config => {CGIAPP_DISPATCH_PREFIX => 'MyApp'},
    );

    eval { $code = CGI::Application::Dispatch::handler($r) };
    is($code, Apache::Constants::NOT_FOUND(), 'handler(): return code');

    like($CGI::Application::Dispatch::Error, qr/Can't locate MyApp\/Module\/Name.pm/, 'handler(): module_name');

    my $rm = CGI::Application::Dispatch::get_runmode($path_info);
    is($rm, 'mode1', 'handler(): run mode');
}


# 8..10
{
    my $path_info = '/cgiappdispatchtestmodule/rm2';
    my $r = Apache::FakeRequest->new(
        path_info => $path_info, 
        dir_config => {CGIAPP_DISPATCH_PREFIX => ''},
    );

    eval { $code = CGI::Application::Dispatch::handler($r) };
    is($code, Apache::Constants::OK(), 'RM true - handler(): return code');

    is($CGI::Application::Dispatch::Error, '', 'RM true - no error');

    my $rm = CGI::Application::Dispatch::get_runmode($path_info);
    is($rm, 'rm2', 'RM true - handler(): run mode');
}

# 11..12
{
    my $path_info = '/cgiappdispatchtestmodule/rm2';
    my $r = Apache::FakeRequest->new(
        path_info => $path_info, 
        dir_config => {
                        CGIAPP_DISPATCH_PREFIX  => '',
                        CGIAPP_DISPATCH_RM      => 'Off',
                    },
    );

    eval { $code = CGI::Application::Dispatch::handler($r) };
    is($code, Apache::Constants::OK(), 'RM false - handler(): return code');

    is($CGI::Application::Dispatch::Error, '', 'RM false - no error');
}

