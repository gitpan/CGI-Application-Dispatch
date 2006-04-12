use Test::More;
use Test::LongString max => 500;
use IO::Scalar;
use strict;
use warnings;
plan(tests => 24);

# 1..5
# make sure we can get to our modules
require_ok('CGI::Application::Dispatch');
require_ok('Module::Name');
require_ok('MyApp::Module::Name');
require_ok('MyApp::Dispatch');
require_ok('MyApp::DispatchTable');
local $ENV{CGI_APP_RETURN_ONLY} = '1';
my $output = '';

# 6..7
# module name
{
    # with starting '/'
    local $ENV{PATH_INFO} = '/module_name/rm1';
    my $output = CGI::Application::Dispatch->dispatch();
    contains_string($output, 'Module::Name->rm1', 'dispatch(): module_name');

    # without starting '/'
    local $ENV{PATH_INFO} = 'module_name/rm1';
    $output = '';
    $output = CGI::Application::Dispatch->dispatch();
    contains_string($output, 'Module::Name->rm1', 'dispatch(): module_name');
}

# 8
# prefix
{
    local $ENV{PATH_INFO} = '/module_name/rm2';
    $output = CGI::Application::Dispatch->dispatch(
        prefix => 'MyApp',
    );
    contains_string($output, 'MyApp::Module::Name->rm2', 'dispatch(): prefix');
}

# 9
# grabs the RM from the PATH_INFO
{
    # with run mode
    local $ENV{PATH_INFO} = '/module_name/rm2';
    $output = CGI::Application::Dispatch->dispatch(
        prefix => 'MyApp',
    );
    contains_string($output, 'MyApp::Module::Name->rm2', 'RM correct');
}

# 10
# extra things passed to dispatch() get passed into new()
{
    local $ENV{PATH_INFO} = '/module_name/rm3';
    $output = CGI::Application::Dispatch->dispatch(
        prefix  => 'MyApp',
        PARAMS  => {
            my_param => 'testing',
        },
    );
    contains_string($output, 'MyApp::Module::Name->rm3 my_param=testing', 'PARAMS passed through');
}

# 11..12
# use default 
{
    # using short cuts names
    local $ENV{PATH_INFO} = '';
    $output = CGI::Application::Dispatch->dispatch(
        prefix  => 'MyApp',
        default => '/module_name/rm2',
    );
    contains_string($output, 'MyApp::Module::Name->rm2', 'default');

    # with trailing '/'
    local $ENV{PATH_INFO} = '/';
    $output = CGI::Application::Dispatch->dispatch(
        prefix  => 'MyApp',
        default => '/module_name/rm2',
    );
    contains_string($output, 'MyApp::Module::Name->rm2', 'default');
}

# 13
# override translate_module_name()
{
    local $ENV{PATH_INFO} = '/something_strange';
    $output = MyApp::Dispatch->dispatch();
    contains_string($output, 'MyApp::Module::Name->rm1', 'override translate_module_name()');
}

# 14..15
# cause errors
{
    # non-existant module
    local $ENV{PATH_INFO} = '/foo';
    $output = CGI::Application::Dispatch->dispatch();
    like($output, qr/Not Found/i);

    # no a valid path_info
    local $ENV{PATH_INFO} = '//';
    $output = CGI::Application::Dispatch->dispatch();
    like($output, qr/Internal Server Error/i);
}

# 16
# args_to_new
{
    local $ENV{PATH_INFO} = '/module_name/rm4';
    $output = CGI::Application::Dispatch->dispatch(
        prefix      => 'MyApp',
        args_to_new => {
            PARAMS => { my_param => 'more testing' },
        },
    );
    contains_string($output, 'MyApp::Module::Name->rm3 my_param=more testing', 'PARAMS passed through');
}

# 17..23
# use a full dispatch table in a subclass
{
    local $ENV{PATH_INFO} = '/module_name';
    $output = MyApp::DispatchTable->dispatch();
    contains_string($output, 'MyApp::Module::Name->rm1', 'matched :app');

    local $ENV{PATH_INFO} = '/module_name/rm2';
    $output = MyApp::DispatchTable->dispatch();
    contains_string($output, 'MyApp::Module::Name->rm2', 'matched :app/:rm');

    local $ENV{PATH_INFO} = '/module_name/rm3/stuff';
    $output = MyApp::DispatchTable->dispatch();
    contains_string($output, 'MyApp::Module::Name->rm3 my_param=stuff', 'matched :app/:rm/:my_param');
    
    local $ENV{PATH_INFO} = '/module_name/bar/stuff';
    $output = MyApp::DispatchTable->dispatch();
    contains_string($output, 'MyApp::Module::Name->rm3 my_param=stuff', 'matched :app/bar/:my_param');

    local $ENV{PATH_INFO} = '/foo/bar';
    $output = MyApp::DispatchTable->dispatch();
    contains_string($output, 'MyApp::Module::Name->rm2', 'matched foo/bar');

    local $ENV{PATH_INFO} = '/module_name/foo';
    $output = MyApp::DispatchTable->dispatch();
    contains_string($output, 'MyApp::Module::Name->rm3 my_param=', 'missing optional');

    local $ENV{PATH_INFO} = '/module_name/foo/weird';
    $output = MyApp::DispatchTable->dispatch();
    contains_string($output, 'MyApp::Module::Name->rm3 my_param=weird', 'present optional');
}

# 24
# local args_to_new
{
    local $ENV{PATH_INFO} = '/module_name/local_args_to_new';
    $output = CGI::Application::Dispatch->dispatch(
        prefix      => 'MyApp',
        table => [
            ':app/:rm' => {
                args_to_new => {
                    TMPL_PATH => 'events',
                },
            },
        ],

    );
    contains_string($output, 'events', 'local args_to_new works');
}
