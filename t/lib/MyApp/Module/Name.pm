package MyApp::Module::Name;
use base 'CGI::Application';

sub setup {
    my $self = shift;
    $self->start_mode('rm1');
    $self->run_modes(
        rm1 => 'rm1',
        rm2 => 'rm2',
        rm3 => 'rm3',
        rm4 => 'rm4',
    ); 
}

sub rm1 {
    my $self = shift;
    return 'MyApp::Module::Name->rm1';
}

sub rm2 {
    my $self = shift;
    return 'MyApp::Module::Name->rm2';
}

sub rm3 {
    my $self = shift;
    my $param = $self->param('my_param');
    return "MyApp::Module::Name->rm3 my_param=$param";
}

sub rm4 {
    my $self = shift;
    my $path = $self->param('CGIAPP_DISPATCH_PATH');
    return "MyApp::Module::Name->rm4 path=$path";
}

1;
