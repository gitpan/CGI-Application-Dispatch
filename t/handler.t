use strict;
use warnings FATAL => 'all';
use Apache::Test qw(plan ok have_lwp need_module);
use Apache::TestRequest qw(GET);
use Apache::TestUtil qw(t_cmp);

plan tests => 33, need_module 'Apache::TestMB', have_lwp();
my $response;
my $content;

# 1..2
# PATH_INFO is translated correctly
{
    $response = GET '/app1/module_name/rm1';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /Module::Name->rm1/);
}


# 3..4
# prefix is added correctly
{
    $response = GET '/app2/module_name/rm1';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm1/); 
}


# 5..6
# grab the RM correctly from the PATH_INFO if RM is not set
{
    $response = GET '/app2/module_name/rm2';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm2/); 
}

# 7..12
# grab the RM correctly from the PATH_INFO if RM is ON
{
    $response = GET '/app3/module_name/rm2';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm2/);

    # get the default (with trailing '/')
    $response = GET '/app3/module_name/';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm1/);

    # get the default (without trailing '/')
    $response = GET '/app3/module_name';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm1/);
}


# 13..14
# don't grab the run mode when RM is Off
{
    $response = GET '/app4/module_name/rm2';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm1/);
}

# 15..16
# CGIAPP_DISPATCH_PATH gets set correctly
{
    $response = GET '/app3/module_name/rm4';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm4 path=module_name/);
}

# 17..20
# CGIAPP_DISPATCH_DEFAULT is used correctly (with RM On)
{
    # no extra path
    $response = GET '/app5';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm2/);

    # only a '/' as the path_info
    $response = GET '/app5/';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm2/);
}

# 21..22
# CGIAPP_DISPATCH_DEFAULT is used correctly (with RM Off)
{
    $response = GET '/app6';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm1/);
}

# 23..24
# override get_module_name()
{
    $response = GET '/app7';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm1/);
}

# 25..26
# override get_runmode()
{
    $response = GET '/app8';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm2/);
}

# 27..30
# CGIAPP_DISPATCH_TABLE with PerlSetVar/PerlAddVar
{
    $response = GET '/app9/foo/rm2';
    ok($response->is_success);
    $content = $response->content();
    ok($content =~ /MyApp::Module::Name->rm2/);

    $response = GET '/app9/bar/rm1';
    ok($response->is_success);
    $content = $response->content();
    ok($content =~ /MyApp::Module::Name->rm1/);
}

# 31..33
# cause errors
{
    # non existant module
    $response = GET '/app2/asdf/rm1';
    ok($response->is_error);

    # poorly written module
    $response = GET '/app2/module_bad/rm1';
    ok($response->is_error);

    # invalid characters
    $response = GET '/app2/module;_bad';
    ok($response->is_error);
}


