use Test::More (tests => 14);
use strict;
use lib './t/lib';

# 1..4
# make sure we can get to our modules
require_ok('CGI::Application::Dispatch');
require_ok('Module::Name');
require_ok('MyApp::Module::Name');
require_ok('MyApp::Dispatch');
local $ENV{CGI_APP_RETURN_ONLY} = '1';
my $output = '';

# 5
# make sure the module name gets created correctly
{
    local $ENV{PATH_INFO} = '/module_name/rm1';
    $output = CGI::Application::Dispatch->dispatch();
    like($output, qr/Module::Name->rm1/, 'dispatch(): module_name');
}

# 6
# make sure that the prefix gets added on correctly
{
    local $ENV{PATH_INFO} = '/module_name/rm1';
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX => 'MyApp',
    );
    like($output, qr/MyApp::Module::Name->rm1/, 'dispatch(): prefix');
}

# 7
# make sure it grabs the RM correctly from the PATH_INFO if RM is true
{
    local $ENV{PATH_INFO} = '/module_name/rm2';
    my $output;
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX => 'MyApp',
        RM => 1,
    );
    like($output, qr/MyApp::Module::Name->rm2/, 'RM true');
}

# 8
# make sure it grabs the RM correctly from the PATH_INFO if RM is undefined
{
    local $ENV{PATH_INFO} = '/module_name/rm2';
    my $output;
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX => 'MyApp',
    );
    like($output, qr/MyApp::Module::Name->rm2/, 'RM true');
}

# 9
# make sure it doesn't grab the run mode when RM is false
{
    local $ENV{PATH_INFO} = '/module_name/rm2';
    my $output;
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX => 'MyApp',
        RM => 0,
    );
    like($output, qr/MyApp::Module::Name->rm1/, 'RM false');
}

# 10 
# make sure extra things passed to dispatch() get passed into new()
{
    local $ENV{PATH_INFO} = '/module_name/rm3';
    my $output;
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX  => 'MyApp',
        RM      => 1,
        PARAMS  => {
            my_param => 'testing',
        },
    );
    like($output, qr/MyApp::Module::Name->rm3 my_param=testing/, 'PARAMS passed through');
}

# 11 
# make sure that we have a correct CGIAPP_DISPATCH_PATH
{
    local $ENV{PATH_INFO} = '/module_name/rm4';
    my $output;
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX  => 'MyApp',
        RM      => 1,
    );
    like($output, qr#MyApp::Module::Name->rm4 path=module_name#, 'CGIAPP_DISPATCH_PATH set correctly');
}

# 12
# let's test that the DEFAULT is used
{
    local $ENV{PATH_INFO} = '';
    my $output;
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX  => 'MyApp',
        RM      => 1,
        DEFAULT => '/module_name/rm2',
    );
    like($output, qr/MyApp::Module::Name->rm2/, 'DEFAULT');
}

# 13
# make sure we can override get_module_name()
{
    local $ENV{PATH_INFO} = '';
    my $output;
    $output = MyApp::Dispatch->dispatch(
        RM      => 0,
    );
    like($output, qr/MyApp::Module::Name->rm1/, 'override get_module_name()');
}

# 14
# make sure we can override get_runmode()
{
    local $ENV{PATH_INFO} = '';
    my $output;
    $output = MyApp::Dispatch->dispatch();
    like($output, qr/MyApp::Module::Name->rm2/, 'override get_runmode()');
}


