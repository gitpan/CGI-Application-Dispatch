use strict;
use warnings FATAL => 'all';
use Apache::Test qw(plan ok have_lwp);
use Apache::TestRequest qw(GET);
use Apache::TestUtil qw(t_cmp);

plan( tests => 20, have_lwp() );

my $response;
my $content;

# 1..2
# make sure the PATH_INFO is translated correctly
{
    $response = GET '/app1/module_name/rm1';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /Module::Name->rm1/);
}


# 3..4
# make sure the prefix is added correctly
{
    $response = GET '/app2/module_name/rm1';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm1/); 
}


# 5..6
# make sure it grabs the RM correctly from the PATH_INFO if RM is not set
{
    $response = GET '/app2/module_name/rm2';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm2/); 
}

# 7..8
# make sure it grabs the RM correctly from the PATH_INFO if RM is ON
{
    $response = GET '/app3/module_name/rm2';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm2/);
}


# 9..10
# make sure that when we set the RM to Off, it doesn't grab the run mode
{
    $response = GET '/app4/module_name/rm2';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm1/);
}

# 11..12
# make sure CGIAPP_DISPATCH_PATH gets set correctly
{
    $response = GET '/app3/module_name/rm4';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm4 path=module_name/);
}

# 13..14
# make sure that CGIAPP_DISPATH_DEFAULT is used correctly (with RM On)
{
    $response = GET '/app5';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm2/);
}

# 15..16
# make sure that CGIAPP_DISPATH_DEFAULT is used correctly (with RM On)
{
    $response = GET '/app6';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm1/);
}

# 17..18
# make sure that we can override get_module_name()
{
    $response = GET '/app7';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm1/);
}

# 19..20
# make sure we can override get_runmode()
{
    $response = GET '/app8';
    ok($response->is_success);
    $content = $response->content;
    ok($content =~ /MyApp::Module::Name->rm2/);
}

