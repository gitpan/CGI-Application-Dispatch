use Test::More qw(no_plan);
use strict;

#try to require Apache
eval { require Apache; };
if($@) {
    print "1..0 #Skipping handler() tests; no Apache module";
}


require_ok('CGI::Application::Dispatch');

#create an Apache::FakeRequest
require Apache::FakeRequest;
require Apache::URI;
require Apache::Constants;

my $request = Apache::FakeRequest->new();
my $code;

{
    my $path_info = '/module_name/mode1';
    my $r = Apache::FakeRequest->new(path_info => $path_info, dir_config => {});

    eval { $code = CGI::Application::Dispatch::handler($r) };
    is($code, Apache::Constants::NOT_FOUND(), 'handler(): return code');

    like($CGI::Application::Dispatch::Error, qr/Can't locate Module\/Name.pm/, 'handler(): module_name');

    my $rm = CGI::Application::Dispatch::get_runmode($path_info);
    is($rm, 'mode1', 'handler(): run mode');
}


{
    my $path_info = '/module_name/mode1';
    my $r = Apache::FakeRequest->new(path_info => $path_info, dir_config => {CGIAPP_DISPATCH_PREFIX => 'MyApp'});
                                                                                                                                             
    eval { $code = CGI::Application::Dispatch::handler($r) };
    is($code, Apache::Constants::NOT_FOUND(), 'handler(): return code');
                                                                                                                                             
    like($CGI::Application::Dispatch::Error, qr/Can't locate MyApp\/Module\/Name.pm/, 'handler(): module_name');
                                                                                                                                             
    my $rm = CGI::Application::Dispatch::get_runmode($path_info);
    is($rm, 'mode1', 'handler(): run mode');
}







