use Test::More (tests => 21);
use strict;

# 1..4
# make sure we can get to our modules
require_ok('CGI::Application::Dispatch');
require_ok('Module::Name');
require_ok('MyApp::Module::Name');
require_ok('MyApp::Dispatch');
local $ENV{CGI_APP_RETURN_ONLY} = '1';
my $output = '';

# 5..6
# make sure the module name gets created correctly
{
    # with starting '/'
    local $ENV{PATH_INFO} = '/module_name/rm1';
    $output = CGI::Application::Dispatch->dispatch();
    like($output, qr/Module::Name->rm1/, 'dispatch(): module_name');

    # without starting '/'
    local $ENV{PATH_INFO} = 'module_name/rm1';
    $output = CGI::Application::Dispatch->dispatch();
    like($output, qr/Module::Name->rm1/, 'dispatch(): module_name');
}

# 7
# make sure that the prefix gets added on correctly
{
    local $ENV{PATH_INFO} = '/module_name/rm1';
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX => 'MyApp',
    );
    like($output, qr/MyApp::Module::Name->rm1/, 'dispatch(): prefix');
}

# 8
# make sure it grabs the RM correctly from the PATH_INFO if RM is true
{
    # with run mode
    local $ENV{PATH_INFO} = '/module_name/rm2';
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX => 'MyApp',
        RM => 1,
    );
    like($output, qr/MyApp::Module::Name->rm2/, 'RM true');
}

# 9
# make sure it grabs the RM correctly from the PATH_INFO if RM is undefined
{
    local $ENV{PATH_INFO} = '/module_name/rm2';
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX => 'MyApp',
    );
    like($output, qr/MyApp::Module::Name->rm2/, 'RM true');
}

# 10
# make sure it doesn't grab the run mode when RM is false
{
    local $ENV{PATH_INFO} = '/module_name/rm2';
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX => 'MyApp',
        RM => 0,
    );
    like($output, qr/MyApp::Module::Name->rm1/, 'RM false');
}

# 11 
# make sure extra things passed to dispatch() get passed into new()
{
    local $ENV{PATH_INFO} = '/module_name/rm3';
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX  => 'MyApp',
        RM      => 1,
        PARAMS  => {
            my_param => 'testing',
        },
    );
    like($output, qr/MyApp::Module::Name->rm3 my_param=testing/, 'PARAMS passed through');
}

# 12 
# make sure that we have a correct CGIAPP_DISPATCH_PATH
{
    local $ENV{PATH_INFO} = '/module_name/rm4';
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX  => 'MyApp',
        RM      => 1,
    );
    like($output, qr#MyApp::Module::Name->rm4 path=module_name#, 'CGIAPP_DISPATCH_PATH set correctly');
}

# 13..14
# let's test that the DEFAULT is used
{
    # using short cuts names
    local $ENV{PATH_INFO} = '';
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX  => 'MyApp',
        RM      => 1,
        DEFAULT => '/module_name/rm2',
    );
    like($output, qr/MyApp::Module::Name->rm2/, 'DEFAULT');

    # using long names with trailing '/'
    local $ENV{PATH_INFO} = '/';
    $output = CGI::Application::Dispatch->dispatch(
        CGIAPP_DISPATCH_PREFIX  => 'MyApp',
        CGIAPP_DISPATCH_RM      => 1,
        CGIAPP_DISPATCH_DEFAULT => '/module_name/rm2',
    );
    like($output, qr/MyApp::Module::Name->rm2/, 'DEFAULT');
}

# 15
# make sure we can override get_module_name()
{
    local $ENV{PATH_INFO} = '';
    $output = MyApp::Dispatch->dispatch(
        RM      => 0,
    );
    like($output, qr/MyApp::Module::Name->rm1/, 'override get_module_name()');
}

# 16
# make sure we can override get_runmode()
{
    local $ENV{PATH_INFO} = '';
    $output = MyApp::Dispatch->dispatch();
    like($output, qr/MyApp::Module::Name->rm2/, 'override get_runmode()');
}

# 17..19
# lets test the TABLE
{
    local $ENV{PATH_INFO} = '/foo';
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX  => 'MyApp',
        TABLE   => {
            'foo' => 'Module::Name',
            'bar' => 'Module::Name',
        },
        RM      => 0,
    );
    like($output, qr/MyApp::Module::Name->rm1/, 'using TABLE');

    # with long names
    local $ENV{PATH_INFO} = '/bar';
    $output = CGI::Application::Dispatch->dispatch(
        CGIAPP_DISPATCH_PREFIX  => 'MyApp',
        CGIAPP_DISPATCH_TABLE   => {
            'foo' => 'Module::Name',
            'bar' => 'Module::Name',
        },
        CGIAPP_DISPATCH_RM      => 0,
    );
    like($output, qr/MyApp::Module::Name->rm1/, 'using TABLE');

    # test with run mode
    local $ENV{PATH_INFO} = '/bar/rm2';
    $output = CGI::Application::Dispatch->dispatch(
        PREFIX  => 'MyApp',
        TABLE   => {
            'foo' => 'Module::Name',
            'bar' => 'Module::Name',
        },
    );
    like($output, qr/MyApp::Module::Name->rm2/, 'using TABLE');
}

# 20..21
# cause errors
{
    # non-existant module
    local $ENV{PATH_INFO} = '/foo';
    eval { $output = CGI::Application::Dispatch->dispatch() };
    ok($@, 'non-existant module');

    # no a valid path_info
    local $ENV{PATH_INFO} = '//';
    eval { $output = CGI::Application::Dispatch->dispatch() };
    ok($@, 'no module name');
}



