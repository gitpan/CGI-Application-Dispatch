package Cgiappdispatchtestmodule;
use base 'CGI::Application';

sub setup {
    my $self = shift;
    $self->start_mode('rm1');
    $self->run_modes(
        rm1 => 'rm1',
        rm2 => 'rm2',
        rm3 => 'rm3',
    ); 
}

sub rm1 {
    my $self = shift;
    return 'rm1';
}

sub rm2 {
    my $self = shift;
    return 'rm2';
}

sub rm3 {
    my $self = shift;
    return 'rm3';
}

1;
