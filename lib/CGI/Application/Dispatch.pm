package CGI::Application::Dispatch;
use strict;
use warnings;
use Carp;

$CGI::Application::Dispatch::Error = '';
$CGI::Application::Dispatch::VERSION = '1.03';
my $MP2;

BEGIN {
    if( $ENV{MOD_PERL} ) {
        require mod_perl;
        $MP2 = $mod_perl::VERSION >= 1.99 ? 1 : 0;
        if( $MP2 ) {
            require Apache::Const;
            require Apache::RequestUtil;
            require Apache::RequestRec;
            require APR::Table;
        } else {
            require Apache::Constants;
        }
    }
}

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

It currently supports both generations of mod_perl (1.x and 2.x). Although, for simplicity,
all examples involving apache configuration and mod_perl code will be shown using mod_perl 1.x.
This may change as mp2 usage increases.

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

=head2 CGIAPP_DISPATCH_TABLE

This option will tell CGI::Application::Dispatch to use either a provided hash or subroutine
to translate the C<< $ENV{PATH_INFO} >> into the module name. The retrieved value will also
be combined with the L<CGIAPP_DISPATCH_PREFIX> value if it exists.

=over 8

=item * TABLE with mod_perl

If you are using this under mod_perl and enjoy using PerlAddVar directives, then your httpd.conf
might look something like this (under mod_perl 1)


  <Location /app>
    SetHandler perl-script
    PerlHandler CGI::Application::Dispatch
    PerlSetVar CGIAPP_DISPATCH_PREFIX MyApp
    PerlSetVar CGIAPP_DISPATCH_RM Off

    PerlSetVar CGIAPP_DISPATCH_TABLE foo
    PerlAddVar CGIAPP_DISPATCH_TABLE Some::Name
    PerlAddVar CGIAPP_DISPATCH_TABLE bar
    PerlAddVar CGIAPP_DISPATCH_TABLE Some::OtherName
    PerlAddVar CGIAPP_DISPATCH_TABLE baz
    PerlAddVar CGIAPP_DISPATCH_TABLE Yet::AnotherName
  </Location>

And then Dispatch will turn the all those PerlSetVar and PerlAddVars into a hash.

=item * TABLE with vanilla CGI

Or if you are using Dispatch under vanilla cgi then an equivalent .cgi script would be:

  #!/usr/bin/perl
  use strict;
  use CGI::Application::Dispatch;

  CGI::Application::Dispatch->dispatch(
    PREFIX  => 'MyApp',
    RM      => 0,
    TABLE   => {
        'foo'     => 'Some::Name',
        'bar'     => 'Some::OtherName',
        'baz'     => 'Yet::AnotherName',
    },
  );

=back

In all these cases a url or '/foo/rm2' will be translated into the module 
'MyApp::Some::Name' and run mode 'rm2'. This will allow more flexibility
in PATH_INFO to module name translation and also provide more security for
those who want to restrict what options are available for translation. If
the PATH_INFO contains a value that is not a key in your table hash, then
Dispatch will t

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
    $CGI::Application::Dispatch::Error = '';

    #get the run_mode from the path_info
    my $dir_args = $r->dir_config();
    my $path_info  = $r->path_info();
    # if we don't have a path_info or it's just '/' then use the default
    if( !$path_info || $path_info eq '/') {
        $path_info = $dir_args->{CGIAPP_DISPATCH_DEFAULT};
    }

    my ($module, $partial_path);
    # get the dispatch TABLE if we have it
    my $table;
    my @table_dirs = $r->dir_config->get('CGIAPP_DISPATCH_TABLE');
    if( @table_dirs ) {
        $table = { @table_dirs };
    }
    # get the module's name and the PATH
    ($module, $partial_path) = $self->get_module_name(
            $path_info, 
            $dir_args->{CGIAPP_DISPATCH_PREFIX},
            $table,
        );
    $module = $self->require_module($module);

    #if we couldn't require that mod
    if ($CGI::Application::Dispatch::Error) {
        #let's check to see if that module could not be found
        my $module_path = $module;
        $module_path =~ s/::/\//g;

        if ( $CGI::Application::Dispatch::Error =~ /Can't locate $module_path.pm/ ) {
            return $MP2 ? Apache::NOT_FOUND() : Apache::Constants::NOT_FOUND();
        }
        #else there was some other error
        else {
            warn "CGI::Application::Dispatch - ERROR $CGI::Application::Dispatch::Error";
            return $MP2 ? Apache::SERVER_ERROR() : Apache::Constants::SERVER_ERROR();
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
        my $rm = $self->get_runmode($path_info);
        $app->mode_param( sub { return $rm } ) if ($rm);
    }

    $app->run();
    return $MP2 ? Apache::OK() : Apache::Constants::OK();
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

    # get the PATH_INFO
    my $path_info = $ENV{PATH_INFO};
    my $prefix = ($args{CGIAPP_DISPATCH_PREFIX} || $args{PREFIX});
    if( !$path_info || $path_info eq '/' ) {
        $path_info = $args{CGIAPP_DISPATCH_DEFAULT} || $args{DEFAULT};
    } 
    # find out if we have a dispatch table
    my $table = $args{CGIAPP_DISPATCH_TABLE} || $args{TABLE} || undef;
    # get the module name and the path
    my ($module, $partial_path) = $self->get_module_name( 
            $path_info, 
            $prefix,
            $table,
    );

    # require the module or croak if we can't
    $module = $self->require_module($module);

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
        $app->mode_param(sub { return $run_mode })
            if( $run_mode );
    }
    $app->run();
}

=head2 get_module_name($path_info, $prefix, [$table])

This method is used to control how the module name is generated from the C<PATH_INFO>. 
Please see L<"PATH_INFO Parsing"> for more details on how this method performs it's job. 
The main reason that this method exists is so that it can be overridden if it doesn't do 
exactly what you want.

This method will recieve three arguments in the following order:

=over 8

=item * $path_info

The PATH_INFO string

=item * $prefix

The value of the CGIAPP_DISPATCH_PREFIX parameter.

=item * $table

A hash reference containing the value of the CGIAPP_DISPATCH_TABLE
parameter.

=back

This method will return the name of the module to create. Actually it returns a list of items,
the first being the name of the module, the second being the specific substring of the C<PATH_INFO>
that was used to create the module name. If you decide to override this method to customize 
the PATH_INFO-to-module-name-creation then you must also return this section of the C<PATH_INFO>
that you used if it's not the same as the default. Otherwise the value of 
L<CGIAPP_DISPATCH_PREFIX> will be C<< undef >>.

=cut

sub get_module_name {
    my ($self, $path_info, $prefix, $table) = @_;

    # make sure that there is at least a first '/'
    $path_info = "/$path_info" if(index($path_info, '/') != 0);

    # get the stuff between first and second '/' (if there is a second '/')
    my $partial_path = (split(/\//, $path_info))[1];   

    # if we are trying to access a mod
    if ($partial_path) {
        # Now translate the module from 'module_name' to 'Module::Name'
        my $module = $partial_path;
        # use the dispatch table if we have one
        if( $table ) {
            $module = $table->{$module};
        } else {
            $module = join( '::', ( map { ucfirst } ( split( /_/, $module ) ) ) );
        }
        # putting the prefix on if necessary
        $module = "${prefix}::${module}" if($prefix);
        return ($module, $partial_path);
    }
    return;
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


=head2 require_module($module_name)

This class method is used internally by CGI::Application::Dispatch to take a module
name (supplied by L<get_module_name>) and require it in a secure fashion. It
is provided as a public class method so that if you override other functionality of
this module, you can still safely require user specified modules. If there are
any problems requiring the named module, the C<< $CGI::Application::Dispatch::Error >>
variable will be set.


    CGI::Application::Dispatch->require_module('MyApp::Module::Name');

    if( $CGI::Application::Dispatch::Error ) {
        die "Could not require module MyApp::Module::Name "
            . $CGI::Application::Dispatch::Error
    }

=cut

sub require_module {
    my ($self, $module) = @_;
    if( $module ) {
        #untaint the module name
        ($module) = ($module =~ /^([A-Za-z][A-Za-z0-9_\-\:\']+)$/);   
        unless ($module) {
        $CGI::Application::Dispatch::Error = "Invalid characters used in module name";
        return;
        }
        eval "require $module";
    
        $CGI::Application::Dispatch::Error = $@ if $@;
        return $module;
    } else {
        return;
    }
}


1;


__END__

=head1 PATH_INFO Parsing

This section will describe how the application module and run mode are determined from
the C<PATH_INFO> and what options you have to customize the process.

=head2 Getting the module name

To put it simply, if you don't use a L<CGIAPP_DISPATCH_TABLE> then the C<PATH_INFO> 
is split on backslahes (C</>). The second element of the
returned list is used to create the application module. So if we have a path info of

    /module_name/mode1

Then the string 'module_name' is used. Underscores (C<_>) are turned into double colons
(C<::>) and each word is passed through C<ucfirst> so that the first letter of each word
is captialized.

Then the C<CGIAPP_DISPATCH_PREFIX> is added to the beginning of this new module name with
a double colon C<::> separating the two. 

If you don't like the exact way that this is done, don't fret you do have a couple of options. 
First, you can specify a L<CGIAPP_DISPATCH_TABLE> on a project-by-project basis to explicitly
perform the C<PATH_INFO> to module-name translation. If you are looking for something more generic
that you can later reuse, you can subclass Dispatch and override the 
L<get_module_name()|"get_module_name($path_info, $prefix)"> to do whatever you wish.

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

=back

=head1 AUTHOR

Michael Peters <mpeters@plusthree.com>

Thanks to Plus Three, LP (http://www.plusthree.com) for sponsoring my work on this module

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

=item * Cees Hek <ceeshek@gmail.com>

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

