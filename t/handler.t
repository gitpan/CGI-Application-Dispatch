use strict;
use warnings FATAL => 'all';
use Apache::Test qw(have_lwp need_module :withtestmore);
use Apache::TestRequest qw(GET);
use Apache::TestUtil qw(t_cmp);
use Test::More;

plan tests => 38, need_module 'Apache::TestMB', have_lwp();
my $response;
my $content;

# 1..2
# PATH_INFO is translated correctly
{
    $response = GET '/app1/module_name/rm1';
    ok($response->is_success);
    $content = $response->content;
    contains_string($content, 'Module::Name->rm1', 'PATH_INFO translated');
}


# 3..4
# prefix is added correctly
{
    $response = GET '/app2/module_name/rm1';
    ok($response->is_success);
    $content = $response->content;
    contains_string($content, 'MyApp::Module::Name->rm1', 'prefix added'); 
}


# 5..6
# grab the RM correctly from the PATH_INFO
{
    $response = GET '/app2/module_name/rm2';
    ok($response->is_success);
    $content = $response->content;
    contains_string($content, 'MyApp::Module::Name->rm2', 'extract RM form PATH_INFO'); 
}

# 7..10
# CGIAPP_DISPATCH_DEFAULT is used correctly
{
    # no extra path
    $response = GET '/app3';
    ok($response->is_success);
    $content = $response->content;
    contains_string($content, 'MyApp::Module::Name->rm2');

    # only a '/' as the path_info
    $response = GET '/app3/';
    ok($response->is_success);
    $content = $response->content;
    contains_string($content, 'MyApp::Module::Name->rm2', 'CGIAPP_DISPATCH_DEFAULT used');
}

# 11..12
# override translate_module_name()
{
    $response = GET '/app4/something_strange';
    ok($response->is_success);
    $content = $response->content;
    contains_string($content, 'MyApp::Module::Name->rm1', 'override translate_module_name()');
}

# 13..20
# cause errors
{
    # non existant module
    $response = GET '/app2/asdf/rm1';
    ok($response->is_error);
    cmp_ok($response->code, 'eq', '404', 'not found - no module');

    # poorly written module
    $response = GET '/app2/module_bad/rm1';
    ok($response->is_error);
    cmp_ok($response->code, 'eq', '500', 'server error: module doesnt complie');

    # non existant run mode
    $response = GET '/app2/module_name/rm5';
    ok($response->is_error);
    cmp_ok($response->code, 'eq', '404', 'not found: no run mode');

    # invalid characters
    $response = GET '/app2/module;_bad';
    ok($response->is_error);
    cmp_ok($response->code, 'eq', '400', 'server error: invalid characters');
}

# 21..38
# dispatch table via a subclass
{
    $response = GET '/app5/module_name';
    ok($response->is_success);
    $content = $response->content;
    contains_string($content, 'MyApp::Module::Name->rm1', 'matched :app');

    $response = GET '/app5/module_name/rm2';
    ok($response->is_success);
    $content = $response->content;
    contains_string($content, 'MyApp::Module::Name->rm2', 'matched :app/:rm');

    $response = GET '/app5/module_name/rm3/stuff';
    ok($response->is_success);
    $content = $response->content;
    contains_string($content, 'MyApp::Module::Name->rm3 my_param=stuff', 'matched :app/:rm/:my_param');

    $response = GET '/app5/module_name/bar/stuff';
    ok($response->is_success);
    $content = $response->content;
    contains_string($content, 'MyApp::Module::Name->rm3 my_param=stuff', 'matched :app/bar/:my_param');

    $response = GET '/app5/foo/bar';
    ok($response->is_success);
    $content = $response->content;
    contains_string($content, 'MyApp::Module::Name->rm2', 'matched foo/bar');

    $response = GET '/app5/module_name/foo';
    ok($response->is_success);
    $content = $response->content;
    contains_string($content, 'MyApp::Module::Name->rm3 my_param=', 'missing optional');

    $response = GET '/app5/module_name/foo/weird%20stuff';
    ok($response->is_success);
    $content = $response->content;
    contains_string($content, 'MyApp::Module::Name->rm3 my_param=weird stuff', 'present optional');

    $response = GET '/app5';
    ok($response->is_success);
    $content = $response->content;
    contains_string($content, 'MyApp::Module::Name->rm1', 'empty default');

    $response = GET '/app5/';
    ok($response->is_success);
    $content = $response->content;
    contains_string($content, 'MyApp::Module::Name->rm1', 'empty default');
}

sub contains_string {
    my ($str, $substr, $diag) = @_;
    if( index($str, $substr) != -1) {
        ok(1);
    } else {
        ok(0);
    }
}
