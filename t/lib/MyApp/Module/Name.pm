package MyApp::Module::Name;
use base 'CGI::Application';

sub setup {
    my $self = shift;
    $self->start_mode('rm1');
    $self->run_modes([qw/
        rm1
        rm2
        rm3
        rm4
        local_args_to_new
    /]); 
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
    my $param = $self->param('my_param') || '';
    return "MyApp::Module::Name->rm3 my_param=$param";
}

# because of caching, we can't re-use PATH_INFO, so we do this. 
sub rm4 {
    my $self = shift;
    return $self->rm3;
}

sub local_args_to_new {
    my $self = shift;
    return $self->tmpl_path;
}


1;
