package CGI::Application::Dispatch;
use strict;
use warnings;
use Carp;

$CGI::Application::Dispatch::Error = '';
$CGI::Application::Dispatch::VERSION = '1.01';

=pod

=head1 NAME

CGI::Application::Dispatch - Class used to dispatch request to CGI::Application based objects 

=head1 SYNOPSIS

=head2 Under mod_perl

    <Location /app>
        SetHandler perl-script
        PerlHandler CGI::Application::Dispatch
    </Location>

=head2 Under normal cgi

    #!/usr/bin/perl
    use strict;
    use CGI::Application::Dispatch;

    CGI::Application::Dispatch->dispatch();

=head1 DESCRIPTION 

This module provides a way (as a mod_perl handler or running under vanilla CGI) to look at 
the path (C<< $r->path_info >> or C<< $ENV{PATH_INFO} >>) of the incoming request, parse 
off the desired module and it's run mode, create an instance of that module and run it.

In addition, the portion of the C<PATH_INFO> that is used to derive the module name is
also passed to the C<PARAMS> of the modules C<<new()>> as CGIAPP_DISPATCH_PATH. This can 
be useful if you are programatically generating URLs.

It will translate a URI like this (under mod_perl):

	/app/module_name/run_mode

or this (vanilla cgi)

	/app/index.cgi/module_name/run_mode

into something that will be functionally similar to this

	my $app = Module::Name->new(..);
	$app->mode_param(sub {'run_mode'}); #this will set the run mode

And in both cases the CGIAPP_DISPATCH_PATH value will be 'module_name' so that
you can generate a self referential URL by doing something like the following
inside of your application module:

    my $url = 'http://mysite.com/app/' . $self->param('CGIAPP_DISPATCH_PATH');

=head1 MOTIVATION

To be honest I got tired of writing lots of individual instance scripts, one
for each application module, under the traditional style of CGI::Application
programming. Then when I switched to running my CGI::Application modules as
straight mod_perl handlers I got tired of having to change my httpd.conf file
for every module I introduced and having my configuration file full of C<Location>
sections. Since I had moved all of my configuration variables into config files
and was not passing any values into the PARAMS hash upon module creation I decided
not to write the same code over and over.

I guess it comes down to me just being lazy. :)

=head1 OPTIONS

This section describes the different options that are available to customize
how you dispatch your requests. All of these options can either be set using
'PerlSetVar' (if you're running under mod_perl) or passed directly as name-value
pairs to the L<"dispatch()"> method. When passing them directly as name-value
pairs to the L<"dispatch()"> method you may omit the 'CGIAPP_DISPATCH_' prefix
on the name of each option. So, C<CGIAPP_DISPATCH_PREFIX> can become simply C<PREFIX>.
You can't however use both. We have examples so don't worry too much.

=head2 CGIAPP_DISPATCH_PREFIX

This option will set the string that will be prepended to the name of the application
module before it is loaded and created. So to use our previous example request of

    /app/index.cgi/module_name/run_mode

This would by default load and create a module named 'Module::Name'. But let's say that you
have all of your application specific modules under the 'My' namespace. If you set this option
to 'My' then it would instead load the 'My::Module::Name' application module instead.

=head2 CGIAPP_DISPATCH_RM

This option, if false, will tell C::A::Dispatch to not set the run mode for the application.
By default it is true.

=head2 CGIAPP_DISPATCH_DEFAULT

This option will set a default value if there is no C<< $ENV{PATH_INFO} >>. It will be parsed
to obtain the module name and run mode (if you don't have C<< CGIAPP_DISPATCH_RM >> set to 
false.
 

=head1 METHODS

=head2 handler()

This method is used so that this module can be run as a mod_perl handler. 
When it creates the application module it passes the $r argument into the PARAMS
hash of new()

    <Location /app>
        SetHandler perl-script
        PerlHandler CGI::Application::Dispatch
        PerlSetVar  CGIAPP_DISPATCH_PREFIX  MyApp
        PerlSetVar  CGIAPP_DISPATCH_RM      Off 
        PerlSetVar  CGIAPP_DISPATCH_DEFAULT /module_name
    </Location>

The above example would tell apache that any url beginning with /app will be handled by
CGI::Application::Dispatch. It also sets the prefix used to create the application module
to 'MyApp' and it tells CGI::Application::Dispatch that it shouldn't set the run mode
but that it will be determined by the application module as usual (through the query
string). It also sets a default application module to be used if there is no C<PATH_INFO>.
So, a url of C<< /app/module_name >> would create an instance of C<< MyApp::Module::Name >>.

=cut

sub handler : method {
    my ($self, $r) = @_;
    require Apache::Constants;
    $CGI::Application::Dispatch::Error = '';

    #get the run_mode from the path_info
    my $dir_args = $r->dir_config();
    my $path  = $r->path_info() || $dir_args->{CGIAPP_DISPATCH_DEFAULT};

    my ($module, $partial_path) = $self->get_module_name($path, $dir_args->{CGIAPP_DISPATCH_PREFIX});
    $module = _require_module($module);

    #if we couldn't require that mod
    if ($CGI::Application::Dispatch::Error) {
        #let's check to see if that module could not be found
        my $module_path = $module;
        $module_path =~ s/::/\//g;

        if ( $CGI::Application::Dispatch::Error =~ /Can't locate $module_path.pm/ ) {
            return Apache::Constants::NOT_FOUND();
        }
        #else there was some other error
        else {
            warn "CGI::Application::Dispatch - ERROR $CGI::Application::Dispatch::Error";
            return Apache::Constants::SERVER_ERROR();
        }
    }

    #create an instance of this app and run it
    my $app = $module->new(
        PARAMS => { 
            r                       => $r, 
            CGIAPP_DISPATCH_PATH    => $partial_path, 
        }, 
    );

    #set the run_mode if we want to
    unless ($dir_args->{CGIAPP_DISPATCH_RM} && ( lc $dir_args->{CGIAPP_DISPATCH_RM} eq 'off') ) {
        my $rm = $self->get_runmode($path);
        $app->mode_param( sub { return $rm } ) if ($rm);
    }

    $app->run();
    return Apache::Constants::OK();
}


=head2 dispatch()

This method is primarily used in a non mod_perl setting in an small cgi script
to dispatch requests. You can pass this method the same name value pairs that
you would set for the L<"handler()"> method using the same options mentioned
above.

    #!/usr/bin/perl
    use strict;
    use CGI::Application::Dispatch;

    CGI::Application::Dispatch->dispatch(
            PREFIX  => 'MyApp',
            RM      => 0,
            DEFAULT => 'module_name',
        );

This example would do the same thing that the previous example of how to use the
L<"handler()"> method would do. The only difference is that it is done in a script
and not in the apache configuration file.

The benefit to using CGI::Application::Dispatch in a non mod_perl environment
instead of the traditional instance scripts would only be seen in an application
that has many instance scripts. It would mean your application would only need
one script and many application modules. Since the dispatch script is so simple
you just write it once and forget about it and turn your attention to your modules
and templates.

Any extra params to dispatch() will be passed on to the new() method of the
CGI::Application module being called. 

=cut

sub dispatch {
    my $self = shift;
    my %args = @_;
    $CGI::Application::Dispatch::Error = '';

    my $path_info = $ENV{PATH_INFO} || $args{CGIAPP_DISPATCH_DEFAULT} || $args{DEFAULT};
    my ($module, $partial_path) = $self->get_module_name(
            $path_info,
            ($args{CGIAPP_DISPATCH_PREFIX} || $args{PREFIX})
    );
    $module = _require_module($module);

    croak $CGI::Application::Dispatch::Error
        if($CGI::Application::Dispatch::Error);

    # Add the application name to any params being passed on to new() 
    $args{PARAMS}->{CGIAPP_DISPATCH_PATH} = $partial_path;

    my $app = $module->new(%args);
    #use either the CGIAPP_DISPATCH_RM or the RM argument
    my $use_rm = $args{CGIAPP_DISPATCH_RM} || $args{RM};
    $use_rm = defined($use_rm) ? $use_rm : 1;
    unless(!$use_rm) {
        my $run_mode = $self->get_runmode($path_info);
        $app->mode_param(sub { return $run_mode });
    }

    $app->run();
}

=head2 get_module_name($path_info, $prefix)

This method is used to control how the module name is generated from the C<PATH_INFO>. 
Please see L<"PATH_INFO Parsing"> for more details on how this method performs it's job. 
The main reason that this method exists is so that it can be overridden if it doesn't do 
exactly what you want.

This method will return the name of the module to create. Actually it returns a list of items,
the first being the name of the module, the second being the specific substring of the C<PATH_INFO>
that was used to create the module name. If you decide to override this method to customize 
the PATH_INFO-to-module-name-creation then you must also return this section of the C<PATH_INFO>
that you used if it's not the same as the default. Otherwise the value of the 

=cut

sub get_module_name {
    my ($self, $path_info, $prefix) = @_;

    # get the stuff between first and second '/' (if there is a second '/')
    my $app = (split(/\//, $path_info))[1];   

    # if we are trying to access a mod
    if ($app) {
        # Now translate the module from 'module_name' to 'Module::Name'
        my $module = $app;
        $module = join( '::', ( map { ucfirst } ( split( /_/, $module ) ) ) );
        # putting the prefix on if necessary
        $module = "${prefix}::${module}" if($prefix);
        return ($module, $app);
    }
    return undef;
}


=head2 get_runmode($path_info)

This method is used to control how the run mode is generated from the C<PATH_INFO>. Please
see L<"PATH_INFO Parsing"> for more details on how this method performs it's job. The main 
reason that this method exists is so that it is overridden if it doesn't do exactly what you
want.

You shouldn't actually call this method yourself, just override it if necessary.

=cut
sub get_runmode {
    my $self = shift;
    return (split(/\//, shift))[2];
}


sub _require_module {
    my $module = shift;
    ($module) = ($module =~ /(.*)/);    #untaint the module name
    eval "require $module";

    $CGI::Application::Dispatch::Error = $@ if $@;
    return $module;
}


1;


__END__

=head1 PATH_INFO Parsing

This section will describe how the application module and run mode are determined from
the C<PATH_INFO> and what options you have to customize the process.

=head2 Getting the module name

To put it simply, the C<PATH_INFO> is split on backslahes (C</>). The second element of the
returned list is used to create the application module. So if we have a path info of

    /module_name/mode1

Then the string 'module_name' is used. Underscores (C<_>) are turned into double colons
(C<::>) and each word is passed through C<ucfirst> so that the first letter of each word
is captialized.

Then the C<CGIAPP_DISPATCH_PREFIX> is added to the beginning of this new module name with
a double colon C<::> separating the two. 

If you don't like the exact way that this is done, don't fret you do have an option. Just
override the L<get_module_name()|"get_module_name($path_info, $prefix)"> method by writing 
your own dispatch class that inherits from CGI::Application::Dispatch. 

=head2 Getting the run mode

Just like the module name is retrieved from splitting the C<PATH_INFO> on backslashes, so is the
run mode. Only instead of using the second element of the resulting list, we use the third
as the run mode. So, using the same example, if we have a path info of

    /module_name/mode1

Then the string 'mode1' is used as the run mode unless the CGIAPP_DISPATCH_RM is set to false.
As with the module name this behavior can be changed by overriding the 
L<get_runmode()|"get_runmode($path_info)"> sub.

=head1 MISC NOTES

=over 8

=item * CGI query strings

CGI query strings are unaffected by the use of C<PATH_INFO> to obtain the module name and run mode.
This means that any other modules you use to get access to you query argument (ie, L<CGI>,
L<Apache::Request>) should not be affected. But, since the run mode may be determined by 
CGI::Application::Dispatch having a query argument named 'rm' will be ignored by your application
module (unless your CGIAPP_DISPATCH_RM is false).

=item * ALPHA software

This module is still alpha software so please use it with that in mind. It is still possible that
the API will change (and may even become unrecognizable) so please remeber to keep up to date.

=back

=head1 AUTHOR

Michael Peters <mpeters@plusthree.com>

Thanks to Plus Three, LLC (http://www.plusthree.com) for sponsoring my work on this module

=head1 COMMUNITY

This module is a part of the larger L<CGI::Application> community. If you have questions or
comments about this module then please join us on the cgiapp mailing list by sending a blank
message to "cgiapp-subscribe@lists.erlbaum.net". There is also a community wiki located at
L<http://www.cgi-app.org/>

=head1 CONTRIBUTORS

=over

=item * Drew Taylor <drew@drewtaylor.com>

=item * James Freeman <james.freeman@smartsurf.org>

=item * Michael Graham <magog@the-wire.com>

=back

=head1 SECURITY

Since C::A::Dispatch will dynamically choose which modules to use as the content generators,
it may give someone the ability to execute random modules on your system if those modules can
be found in you path. Of course those modules would have to behave like CGI::Application based
modules, but that still opens up the door more than most want. This should only be a problem
if you don't use the CGIAPP_DISPATCH_PREFIX (or simple PREFIX in L<"dispatch()">) option. By
using this option you are only allowing the url to pick from a certain directory (namespace)
of applications to run.

=head1 SEE ALSO

L<CGI::Application>, L<Apache::Dispatch>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

