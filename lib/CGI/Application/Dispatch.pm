package CGI::Application::Dispatch;
use strict;
use warnings;
use Carp qw(carp cluck);
use Exception::Class::TryCatch qw(catch);

our $VERSION = '2.01';
our $DEBUG = 0;

# Used for error handling

# a cache
our %URL_DISPATCH_CACHE = ();
our $URL_DISPATCH_CACHE_MAX = 1000;

BEGIN {
    use constant IS_MODPERL  => exists( $ENV{MOD_PERL} );
    use constant IS_MODPERL2 => (
        IS_MODPERL()
        and exists $ENV{MOD_PERL_API_VERSION} 
        and $ENV{MOD_PERL_API_VERSION} == 2
    );

    if (IS_MODPERL2() ) {
        require Apache2::RequestUtil;
        require Apache2::RequestRec;
        require APR::Table;
        require Apache2::Const;
        Apache2::Const->import(qw(OK SERVER_ERROR HTTP_BAD_REQUEST NOT_FOUND REDIRECT));
    } elsif (IS_MODPERL()) {
        require Apache::Constants;
        Apache::Constants->import(qw(OK SERVER_ERROR BAD_REQUEST NOT_FOUND REDIRECT));
    }
}

# these return values have different values used in different ENV
use Exception::Class (
    'CGI::Application::Dispatch::Exception',
    'CGI::Application::Dispatch::ERROR' => {
        isa         => 'CGI::Application::Dispatch::Exception',
        alias       => 'throw_error',
        description => 500,
    },
    'CGI::Application::Dispatch::NOT_FOUND' => {
        isa         => 'CGI::Application::Dispatch::Exception',
        alias       => 'throw_not_found',
        description => 404,
    },
    'CGI::Application::Dispatch::BAD_REQUEST' => {
        isa         => 'CGI::Application::Dispatch::Exception',
        alias       => 'throw_bad_request',
        description => 400,
    },
);

=pod

=head1 NAME

CGI::Application::Dispatch - Dispatch requests to CGI::Application based objects

=head1 SYNOPSIS

=head2 Out of Box

Under mod_perl

    <Location /app>
        SetHandler perl-script
        PerlHandler CGI::Application::Dispatch
    </Location>

Under normal cgi

    #!/usr/bin/perl
    use strict;
    use CGI::Application::Dispatch;
    CGI::Application::Dispatch->dispatch();

=head2 With a dispatch table

    package MyApp::Dispatch;
    use base 'CGI::Application::Dispatch';

    sub dispatch_args {
        return {
            prefix  => 'MyApp',
            table   => [
                ''                => { app => 'Welcome', rm => 'start' },
                :app/:rm'         => { },
                'admin/:app/:rm'  => { prefix   => 'MyApp::Admin' },
            ],
        };
    }

Under mod_perl

    <Location /app>
        SetHandler perl-script
        PerlHandler MyApp::Dispatch
    </Location>

Under normal cgi

    #!/usr/bin/perl
    use strict;
    use MyApp::Dispatch;
    MyApp::Dispatch->dispatch();

=head1 DESCRIPTION

This module provides a way (as a mod_perl handler or running under vanilla CGI) to look at
the path (C<< $r->path_info >> or C<$ENV{PATH_INFO}>) of the incoming request, parse
off the desired module and it's run mode, create an instance of that module and run it.

It currently supports both generations of mod_perl (1.x and 2.x). Although, for simplicity,
all examples involving Apache configuration and mod_perl code will be shown using mod_perl 1.x.
This may change as mp2 usage increases.

It will translate a URI like this (under mod_perl):

    /app/module_name/run_mode

or this (vanilla cgi)

    /app/index.cgi/module_name/run_mode

into something that will be functionally similar to this

    my $app = Module::Name->new(..);
    $app->mode_param(sub {'run_mode'}); #this will set the run mode

=head1 METHODS

=head2 dispatch()

This is the primary method used during dispatch. Even under mod_perl, the L<handler>
method uses this under the hood.

    #!/usr/bin/perl
    use strict;
    use CGI::Application::Dispatch;

    CGI::Application::Dispatch->dispatch(
        prefix  => 'MyApp',
        default => 'module_name',
    );

This method accepts the following name value pairs:

=over

=item default

Specify a value to use in place of C<PATH_INFO> if C<PATH_INFO> is not provided.
This could be the case if the default page is selected (eg: "/" ).

=item prefix

This option will set the string that will be prepended to the name of the application
module before it is loaded and created. So to use our previous example request of

    /app/index.cgi/module_name/run_mode

This would by default load and create a module named 'Module::Name'. But let's say that you
have all of your application specific modules under the 'My' namespace. If you set this option
to 'My' then it would instead load the 'My::Module::Name' application module instead.

=item args_to_new

This is a hash of arguments that are passed into the C<new()> constructor of the application.

=item table

In most cases, simply using Dispatch with the C<default> and C<prefix> is enough
to simplify your application and your URLs, but there are many cases where you want
more power. Enter the dispatch table. Since this table can be slightly complicated,
a whole section exists on it's use. Please see the L<DISPATCH TABLE> section.

=item debug

Set to a true value to send debugging output for this module to STDERR. Off by default. 

=item not_found

This is a URI to which the application will be redirected if the incoming request's
C<PATH_INFO> does not match anything in the L<DISPATCH TABLE>. This will also be used
if there was a match, but the module could not be loaded, or the run mode did not
exist.

If this value is not present, then Dispatch will return a NOT FOUND error either to the 
browser (under CGI) or to Apache (under mod_perl).

=back

=cut

sub dispatch {
    my ($self, %args) = @_;

    %args = ( %{ $self->dispatch_args(\%args) }, %args);

    $DEBUG = 1 if $args{debug};

    # Immediatey, try a cached result.
    if ( my $final_args = $self->_url_cache() ) {
        if( $DEBUG ) {
            require Data::Dumper;
            warn "[Dispatch] - Found cached version of URL '$ENV{REQUEST_URI}'. "
                . "Using the following args: " . Data::Dumper::Dumper($final_args);
        }
        return $self->_run_app(@$final_args);
    }

    # check for extra args (for backwards compatibility)
    foreach (keys %args) {
        next if(
            $_ eq 'prefix'      or
            $_ eq 'default'     or
            $_ eq 'debug'       or
            $_ eq 'rm'          or
            $_ eq 'args_to_new' or
            $_ eq 'table'       or
            $_ eq 'not_found'
        );
        carp "Passing extra args ('$_') to dispatch() is deprecated! Please use 'args_to_new'";
        $args{args_to_new}->{$_} = delete $args{$_};
    }
    %args = map { lc $_ => $args{$_} } keys %args;  # lc for backwards compatability

    # get the PATH_INFO
    my $path_info = $ENV{PATH_INFO};
    # use the 'default' if we need to
    $path_info = $args{default} || '' if( !$path_info || $path_info eq '/' );
    # make sure they all start and end with a '/', to correspond with the RE we'll make
    $path_info = "/$path_info" unless( index($path_info, '/') == 0 );
    $path_info = "$path_info/" unless( substr($path_info, -1) eq '/');

    my ( $module, $rm, $local_prefix, $local_args_to_new );

    # take args from path
    my $named_args;
    eval {
        $named_args = $self->_parse_path( $path_info, $args{table} )
		    or throw_not_found(
                "Resource not found " . ($ENV{REQUEST_URI} ? "for '$ENV{REQUEST_URI}'" : '')
            );
    }; 
    my $e = catch();
    return $self->http_error($e, $args{not_found}) if( $e );

    if ($DEBUG) {
        require Data::Dumper;
        warn "[Dispatch] Named args from match: "
          . Data::Dumper::Dumper($named_args) . "\n";
    }

    if (exists($named_args->{PARAMS}) || exists($named_args->{TMPL_PATH})) {
        carp "PARAMS and TMPL_PATH are not allowed here. Did you mean to use args_to_new?";
        throw_error("PARAMS and TMPL_PATH not allowed");
    }

    # eval and catch any exceptions that might be thrown
    my ($output, @final_dispatch_args);
    eval {
        ( $module, $local_prefix, $rm, $local_args_to_new ) =
          delete @{$named_args}{qw(app prefix rm args_to_new)};

        $module or throw_error("App not defined");
        $module = $self->translate_module_name($module);

        $local_prefix ||=  $args{prefix};
        $module = $local_prefix . '::' . $module if( $local_prefix );

        $local_args_to_new ||= $args{args_to_new};

        # add the rest of the named_args to PARAMS
        @{ $local_args_to_new->{PARAMS} }{ keys %$named_args } = values %$named_args;

        # load and run the module
        @final_dispatch_args = ($module, $rm, $local_args_to_new);
        $self->require_module($module);
        $output = $self->_run_app($module,$rm,$local_args_to_new);
    };
    $e = catch();
    return $self->http_error($e, $args{not_found}) if( $e );

    # Cache this URL - dispatch map for later use.
    $self->_url_cache(\@final_dispatch_args);

    return $output;
}


# stolen from http_protocol.c in Apache sources
# we don't actually use anything other than 200, 307, 400, 404 and 500
my %status_lines = (
#    100 => 'Continue',
#    101 => 'Switching Protocols',
#    102 => 'Processing',
    200 => 'OK',
#    201 => 'Created',
#    202 => 'Accepted',
#    203 => 'Non-Authoritative Information',
#    204 => 'No Content',
#    205 => 'Reset Content',
#    206 => 'Partial Content',
#    207 => 'Multi-Status',
#    300 => 'Multiple Choices',
#    301 => 'Moved Permanently',
#    302 => 'Found',
#    303 => 'See Other',
#    304 => 'Not Modified',
#    305 => 'Use Proxy',
    307 => 'Temporary Redirect',
    400 => 'Bad Request',
#    401 => 'Authorization Required',
#    402 => 'Payment Required',
#    403 => 'Forbidden',
    404 => 'Not Found',
#    405 => 'Method Not Allowed',
#    406 => 'Not Acceptable',
#    407 => 'Proxy Authentication Required',
#    408 => 'Request Time-out',
#    409 => 'Conflict',
#    410 => 'Gone',
#    411 => 'Length Required',
#    412 => 'Precondition Failed',
#    413 => 'Request Entity Too Large',
#    414 => 'Request-URI Too Large',
#    415 => 'Unsupported Media Type',
#    416 => 'Requested Range Not Satisfiable',
#    417 => 'Expectation Failed',
#    422 => 'Unprocessable Entity',
#    423 => 'Locked',
#    424 => 'Failed Dependency',
    500 => 'Internal Server Error',
#    501 => 'Method Not Implemented',
#    502 => 'Bad Gateway',
#    503 => 'Service Temporarily Unavailable',
#    504 => 'Gateway Time-out',
#    505 => 'HTTP Version Not Supported',
#    506 => 'Variant Also Negotiates',
#    507 => 'Insufficient Storage',
#    510 => 'Not Extended',
);

sub http_error {
    my ($self, $e, $url) = @_;

    warn "[Dispatch] ERROR: '" . $e->error 
        . ( $ENV{REQUEST_URI} ? "' for request '$ENV{REQUEST_URI}'" : "' ") . "\n";
    my $redirect;
    if( $e->isa('CGI::Application::Dispatch::NOT_FOUND') && $url ) {
        $redirect = 1;
        warn "[Dispatch] Redirection for NOT FOUND to $url" if( $DEBUG );
    }
    my $errno;
    if( $e->isa('CGI::Application::Dispatch::Exception') ) {
        $errno = $e->description;
    } else {
        $errno = 500;
    }
warn "\nERRNO: $errno\n\n";

    # if we're under mod_perl
    if (IS_MODPERL) {
        my $r = IS_MODPERL2 ? Apache2::RequestUtil->request : Apache->request;
        # if we just want to redirect
        if( $redirect ) {
            $r->status( $errno );
            $r->headers_out->{'Location'} = $url; 
        } else {
            # next line is for Apache::Registry
            $r->status($errno);
        }
        return '';
    # else print the HTTP stuff ourselves
    } else {
        $errno = 500 if( !exists $status_lines{$errno} );
        my $output = "HTTP/1.0 Status: $errno $status_lines{$errno}\n";
        $output .= "Location: $url\n" if( $redirect );
        $output .= "Content-type: text/html\n\n";

        # TODO: possibly provide more feedback in a way that is XSS safe.
        # (I'm not sure that passing through the raw ENV variable directly is safe.)
        # <P>We tried: $ENV{REQUEST_URI}</P></BODY></HTML>";
        $output .= qq(
            <!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
            <HTML><HEAD>
            <TITLE>$errno $status_lines{$errno}</TITLE>
            </HEAD><BODY>
            <H1>$status_lines{$errno}</H1>
            <P><ADDRESS>)
            . ( $ENV{SERVER_ADMIN} ? "($ENV{SERVER_ADMIN})" : '') 
            . qq(</ADDRESS></P>
            <HR>)
            . ( $ENV{SERVER_SIGNATURE} || '' )
            . qq(</BODY></HTML>);
        # Send output to browser (unless we're in serious debug mode!)
        if (not $ENV{CGI_APP_RETURN_ONLY}) {
            print $output;
        }

        return $output;
    }
}



# protected method - designed to be used by sub classes, not by end users
sub _parse_path {
    my ( $self, $path, $table ) = @_;

    # get the module name from the table
    return unless defined($path);

    unless (ref($table) eq 'ARRAY' ) {
        warn "[Dispatch] Invalid or no dispatch table!\n";
        return;
    }

    for ( my $i = 0 ; $i < scalar(@$table) ; $i += 2 ) {

        # translate the rule into a regular expression, but remember where the named args are
        my $rule = $table->[$i];

        # make sure they start and end with a '/' to match how PATH_INFO is formatted
        $rule = "/$rule" unless ( index( $rule, '/' ) == 0 );
        $rule = "$rule/" if ( substr( $rule, -1 ) ne '/' );

        my @names = ();

        # '/:foo' will become '/([^\/]*)'
        # and
        # '/:bar?' will become '/?([^\/]*)?'
        # and then remember which position it matches

        $rule =~ s{
            (^|/)                 # beginning or a /
            (:([^/\?]+)(\?)?)     # stuff in between
        }{
            push(@names, $3);
            $1 . ($4 ? '?([^/]*)?' : '([^/]*)')
        }gxe;

        warn "[Dispatch] Trying to match '${path}' against rule '$table->[$i]' using regex '${rule}'\n"
			if $DEBUG;

        # if we found a match, then run with it
        if ( my @values = ( $path =~ m#^$rule$# ) ) {

            warn "[Dispatch] Matched!\n" if $DEBUG;

            my %named_args = %{ $table->[ ++$i ] };
            @named_args{@names} = @values  if @names;

            return \%named_args;
        }
    }

    return;
}

# protected method - designed to be used by sub classes, not by end users
sub _url_cache {
    my ( $self, $value ) = @_;
    my $key;

    # may be PATH_TRANSLATED only to use here?
    foreach my $env qw(SERVER_NAME SCRIPT_NAME PATH_INFO) {
        $key .= ":" . ($ENV{$env} || '');
    }

    if ( defined($value) ) {
        # shrink cache, if it's too large
        delete(
            @URL_DISPATCH_CACHE{
                ( keys %URL_DISPATCH_CACHE )
                  [ 0 .. int( $URL_DISPATCH_CACHE_MAX / 3 ) ]
              }
          )
          if ( keys %URL_DISPATCH_CACHE > $URL_DISPATCH_CACHE_MAX );

        $URL_DISPATCH_CACHE{$key} = $value;
    }

    return $URL_DISPATCH_CACHE{$key};
}

sub _run_app {
    my ( $self, $module, $rm, $args ) = @_;

    if ($DEBUG) {
        require Data::Dumper;
        warn "[Dispatch] Final args to pass to new(): "
          . Data::Dumper::Dumper($args) . "\n";
    }

    # now create and run then application object
    warn "[Dispatch] creating instance of $module\n" if( $DEBUG );

    my $output;
    eval {
        my $app = ref($args) eq 'HASH' ? $module->new($args) : $module->new();
        $app->mode_param( sub { return $rm } ) if ($rm);
        $output = $app->run();
    };

    if ($@) {
        # catch invalid run-mode stuff
        if ( $@ =~ /No such run mode/ ) {
            throw_not_found('RM not found') 
        # otherwise, just pass it up the chain
        } else {
            die $@;
        }
    }

    return $output;
}

=head2 handler()

This method is used so that this module can be run as a mod_perl handler.
When it creates the application module it passes the $r argument into the PARAMS
hash of new()

    <Location /app>
        SetHandler perl-script
        PerlHandler CGI::Application::Dispatch
        LerlSetVar  CGIAPP_DISPATCH_PREFIX  MyApp
        PerlSetVar  CGIAPP_DISPATCH_DEFAULT /module_name
    </Location>

The above example would tell apache that any url beginning with /app will be handled by
CGI::Application::Dispatch. It also sets the prefix used to create the application module
to 'MyApp' and it tells CGI::Application::Dispatch that it shouldn't set the run mode
but that it will be determined by the application module as usual (through the query
string). It also sets a default application module to be used if there is no C<PATH_INFO>.
So, a url of C</app/module_name> would create an instance of C<MyApp::Module::Name>.

Using this method will add the C<Apache->request> object to your application's C<PARAMS>
as 'r'.

    # inside your app
    my $request = $self->param('r');

If you need more customization than can be accomplished with just L<prefix>
and L<default>, then it would be best to just subclass CGI::Application::Dispatch
and override L<dispatch_args> since this method uses L<dispatch> to do the heavy lifting.

    package MyApp::Dispatch;
    use base 'CGI::Application::Dispatch';

    sub dispatch_args {
        return {
            prefix  => 'MyApp',
            table   => [
                ''                => { app => 'Welcome', rm => 'start' },
                ':app/:rm'        => { },
                'admin/:app/:rm'  => { prefix   => 'MyApp::Admin' },
            ],
            args_to_new => {
                PARAMS => {
                    foo => 'bar',
                    baz => 'bam',
                },
            }
        };
    }

    1;

And then in your httpd.conf

    <Location /app>
        SetHandler perl-script
        PerlHandler MyApp::Dispatch
    </Location>

=cut

sub handler : method {
    my ($self, $r) = @_;

    # set the PATH_INFO
    $ENV{PATH_INFO} = $r->path_info();

    # setup our args to dispatch()
    my %args;
    my $config_args = $r->dir_config();
    foreach my $var qw(DEFAULT PREFIX) {
        my $dir_var = "CGIAPP_DISPATCH_$var";
        $args{lc($var)} = $config_args->{$dir_var}
            if( $config_args->{$dir_var} );
    }
    # add $r to the args_to_new's PARAMS
    $args{args_to_new}->{PARAMS}->{r} = $r;

    # set debug if we need to
    $DEBUG = 1 if( $config_args->{CGIAPP_DISPATCH_DEBUG} );
    if( $DEBUG ) {
        require Data::Dumper;
        warn "[Dispatch] Calling dispatch() with the following arguments: " . Data::Dumper::Dumper(\%args) . "\n";
    }

    $self->dispatch(%args);

    if( $r->status == 404 ) {
        return NOT_FOUND();
    } elsif( $r->status == 500 ) {
        return SERVER_ERROR();
    } elsif( $r->status == 400 ) {
        return BAD_REQUEST();
    } else {
        return OK();
    }
}

=head2 dispatch_args

Returns a hashref of args that will be passed to L<dispatch>(). It will return the following
structure by default.

    {
        prefix      => '',
        args_to_new => {},
        table       => [
            ':app'      => {},
            ':app/:rm'  => {},
        ],
    }

This is the perfect place to override when creating a subclass to provide a richer dispatch
L<table>.

When called, it receives 1 argument, which is a reference to the hash of args passed into
L<dispatch>.

=cut

sub dispatch_args {
    my ($self, $args) = @_;
    return {
        default     => ( $args->{default} || ''),
        prefix      => ( $args->{prefix}  || ''),
        args_to_new => ( $args->{args_to_new} || {} ),
        table       => [
            ':app'      => {},
            ':app/:rm'  => {},
        ],
    };
}

=head2 translate_module_name

This method is used to control how the module name is translated from
the matching section of the C<PATH_INFO> (see L<"PATH_INFO Parsing">.
The main reason that this method exists is so that it can be overridden if it doesn't do
exactly what you want.

The following transformations are performed on the input:

=over

=item The text is split on '_'s (underscores)
and each word has it's first letter capitalized. The words are then joined
back together and each instance of an underscore is replaced by '::'.


=item The text is split on '-'s (hyphens)
and each word has it's first letter capitalized. The words are then joined
back together and each instance of a hyphen removed.

=back

Here are some examples to make it even clearer:

    module_name         => Module::Name
    module-name         => ModuleName
    admin_top-scores    => Admin::TopScores

=cut

sub translate_module_name {
    my ($self, $input) = @_;

    $input = join('::', map { ucfirst($_) } split(/_/, $input));
    $input = join('',   map { ucfirst($_) } split(/-/, $input));

    return $input;
}

=head2 require_module($module_name)

This class method is used internally by CGI::Application::Dispatch to take a module
name (supplied by L<get_module_name>) and require it in a secure fashion. It
is provided as a public class method so that if you override other functionality of
this module, you can still safely require user specified modules. If there are
any problems requiring the named module, then we will C<croak>.

    CGI::Application::Dispatch->require_module('MyApp::Module::Name');

=cut

sub require_module {
    my ($self, $module) = @_;

    $module or die "STATUS: " . DISPATCH_NOT_FOUND();

    #untaint the module name
    ($module) = ($module =~ /^([A-Za-z][A-Za-z0-9_\-\:\']+)$/);

    unless ($module) {
        throw_bad_request("Invalid characters in module name");
    }

    warn "[Dispatch] loading module $module\n" if ( $DEBUG );
    eval "require $module";
    return unless $@;

    my $module_path = $module;
    $module_path =~ s/::/\//g;

    if ( $@ =~ /Can't locate $module_path.pm/ ) {
        throw_not_found("Can't find module $module");
    } else {
        throw_error("Unable to load module '$module': $@");
    }
}


1;


__END__

=head1 DISPATCH TABLE

Sometimes it's easiest to explain with an example, so here you go:

  CGI::Application::Dispatch->dispatch(
    prefix      => 'MyApp',
    args_to_new => {
        TMPL_PATH => 'myapp/templates'
    },
    table       => [
        ''                         => { app => 'Blog', rm => 'recent'}
        'posts/:category'          => { app => 'Blog', rm => 'posts' },
        ':app/:rm/:id'             => { app => 'Blog' },
        'date/:year/:month?/:day?' => {
            app         => 'Blog',
            rm          => 'by_date',
            args_to_new => { TMPL_PATH = "events/" },
        },
    ]
  );

So first, this call to L<dispatch> set's the L<prefix> and passes a C<TMPL_PATH>
into L<args_to_new>. Next it sets the L<table>.


=head2 VOCABULARY

Just so we all understand what we're talking about....

A table is an array where the elements are gouped as pairs (similar to a hash's
key-value pairs, but as an array to preserve order). The first element of each pair
is called a C<rule>. The second element in the pair is called the rule's C<arg list>.
Inside a rule there are backslashes C</>. Anything set of characters between backslashes
is called a C<token>.

=head2 URL MATCHING

When a URL comes in, Dispatch tries to match it against each rule in the table in
the order in which the rules are given. The first one to match wins.

A rule consists of backslashes and tokens. A token can one of the following types:

=over

=item literal

Any token which does not start with a colon (C<:>) is taken to be a literal
string and must appear exactly as-is in the URL in order to match. In the rule

    'posts/:category'

C<posts> is a literal token.

=item variable

Any token which begins with a colon (C<:>) is a variable token. These are simply
wild-card place holders in the rule that will match anything in the URL that isn't
a backslash. These variables can later be referred to by using the C<< $self->param >>
mechanism. In the rule

    'posts/:category'

C<:category> is a variable token. If the URL matched this rule, then you could retrieve
the value of that token from whithin your application like so:

    my $category = $self->param('category');

There are some variable tokens which are special. These can be used to further customize
the dispatching.

=over

=item :app

This is the module name of the application. The value of this token will be sent to the
L<translate_module_name> method and then prefixed with the L<prefix> if there is one.

=item :rm

This is the run mode of the application. The value of this token will be the actual name
of the run mode used.

=back

=item optional-variable

Any token which begins with a colon (C<:>) and ends with a question mark (<?>) is considered
optional. If the rest of the URL matches the rest of the rule, then it doesn't matter whether
it contains this token or not. It's best to only include optional-variable tokens at the end
of your rule. In the rule

    'date/:year/:month?/:day?'

C<:month?> and C<:day?> are optional-variable tokens.

Just like with L<variable> tokens, optional-variable tokens' values can also be retrieved by
the application, if they existed in the URL.

    if( defined $self->param('month') ) {
        ...
    }

=back

The main reason that we don't use regular expressions for dispatch rules is that regular
expressions provide no mechanism for named back references, like variable tokens do.

=head2 ARG LIST

Each rule can have an accompanying arg-list. This arg list can contain special arguments
that override something set higher up in L<dispatch> for this particular URL, or just
have additional args passed available in C<< $self->param() >>

For instance, if you want to override L<prefix> for a specific rule, then you can do so.

    'admin/:app/:rm' => { prefix => 'MyApp::Admin' },

=head1 PATH_INFO Parsing

This section will describe how the application module and run mode are determined from
the C<PATH_INFO> if no L<DISPATCH TABLE> is present, and what options you have to
customize the process.

=head2 Getting the module name

To get the name of the application module the C<PATH_INFO> is split on backslahes (C</>).
The second element of the returned list is used to create the application module. So if we
have a path info of

    /module_name/mode1

then the string 'module_name' is used. This is passed through the L<translate_module_name>
method. Then if there is a C<prefix> (and there should always be a L<prefix>) it is added
to the beginning of this new module name with a double colon C<::> separating the two.

If you don't like the exact way that this is done, don't fret you do have a couple of options.
First, you can specify a L<DISPATCH TABLE> which is much more powerfule and flexible (in fact
this default behavior is actually implemented internally with a dispatch table).
Or if you want something a little simpler, you can simply subclass and extend the
L<translate_module_name> method.

=head2 Getting the run mode

Just like the module name is retrieved from splitting the C<PATH_INFO> on backslashes, so is the
run mode. Only instead of using the second element of the resulting list, we use the third
as the run mode. So, using the same example, if we have a path info of

    /module_name/mode2

Then the string 'mode2' is used as the run mode.

=head1 MISC NOTES

=over 8

=item * CGI query strings

CGI query strings are unaffected by the use of C<PATH_INFO> to obtain the module name and run mode.
This means that any other modules you use to get access to you query argument (ie, L<CGI>,
L<Apache::Request>) should not be affected. But, since the run mode may be determined by
CGI::Application::Dispatch having a query argument named 'rm' will be ignored by your application
module.

=back

=head1 CLEAN URLS WITH MOD_REWRITE

With a dispatch script, you can fairly clean URLS like this:

 /cgi-bin/dispatch.cgi/module_name/run_mode

However, including "/cgi-bin/dispatch.cgi" in ever URL doesn't add any value to the URL,
so it's nice to remove it. This is easily done if you are using the Apache web server with
C<mod_rewrite> available. Adding the following to a C<.htaccess> file would allow you to
simply use:

 /module_name/run_mode

If you have problems with mod_rewrite, turn on debugging to see exactly what's happening:

 RewriteLog /home/project/logs/alpha-rewrite.log
 RewriteLogLevel 9

=head2 mod_rewrite related code in the dispatch script.

This seemed necessary to put in the dispatch script to make mod_rewrite happy.
Perhaps it's specific to using C<RewriteBase>. Refactorings welcome!

  # mod_rewrite alters the PATH_INFO by turning it into a file system path,
  # so we repair it.
  use FindBin qw/$Bin/;
  use Cwd 'abs_path';
  chdir $Bin;
  # Location of the www root in relation to the dispatcher. (Adjust as needed!)
  my $www = abs_path("../");
  # fix /home versus /usr/home difference
  $www =~ s{/usr}{};

  # the final removal of the file system stuff mod_rewrite added.
  # PATH_INFO won't defined if "/" is requested.
  $ENV{PATH_INFO} =~ s/^$www//g if defined $ENV{PATH_INFO};


=head2 Simple Apache Example

  RewriteEngine On

  # You may want to change the base if you are using the dispatcher within a
  # specific directory.
  RewriteBase /

  # If an actual file or directory is requested, serve directly
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d

  # Otherwise, pass everything through to the dispatcher
  RewriteRule ^(.*)$ /cgi-bin/dispatch.cgi$1 [L,QSA]

=head2 More complex rewrite: dispatching "/" and multiple developers

Here is a more complex example that dispatches "/", which would otherwise
be treated as a directory, and also supports multiple developer directories,
so C</~mark> has its own seperate dispatching system beneath it.

Note that order matters here! The Location block for "/" needs to come before the
user blocks.

  <Location />
    RewriteEngine On
    RewriteBase /

    # Run "/" through the dispatcher
    RewriteRule ^home/project/www/$ /cgi-bin/dispatch.cgi [L,QSA]

    # Don't apply this rule to the users sub directories.
    RewriteCond %{REQUEST_URI} !^/~.*$
    # If an actual file or directory is requested, serve directly
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    # Otherwise, pass everything through to the dispatcher
    RewriteRule ^(.*)$ /cgi-bin/dispatch.cgi/$1 [L,QSA]
  </Location>

  <Location /~mark>
    RewriteEngine On
    RewriteBase /~mark

    # Run "/" through the dispatcher
    RewriteRule ^/home/mark/www/$ /~mark/cgi-bin/dispatch.cgi [L,QSA]

     # Otherwise, if an actual file or directory is requested, serve directly
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d

     # Otherwise, pass everything through to the dispatcher
    RewriteRule ^(.*)$ /~mark/cgi-bin/dispatch.cgi$1 [L,QSA]

    # These examples may also be helpful, but are unrelated to dispatching.
    SetEnv DEVMODE mark
    SetEnv PERL5LIB /home/mark/perllib:/home/mark/config
    ErrorDocument 404 /~mark/errdocs/404.html
    ErrorDocument 500 /~mark/errdocs/500.html
  </Location>

=head1 SUBCLASSING

While Dispatch tries to be flexible, it won't be able to do everything that people want. Hopefully
we've made it flexible enough so that if it doesn't do I<The Right Thing> you can easily subclass
it.

=head2 PROTECTED METHODS

The following methods are intended to be overridden by subclasses if necessary. They are not
part of the public API since end users will never touch them. However, to ensure that your
subclass of Dispatch does not break with a new release, they are documented here and are considered
to be part of the API and will not be changed without very good reasons.

=over

=item _get_cache

This method will return the arguments that would have been determined from parsing the PATH_INFO
(and possibly using the Dispatch Table), but that were stored in the cache from a previous run.
It receives the URL of the request to use as the key:

    my $args = $self->_get_cache($url)

=item _set_cache

This method sets the arguments determined form parsing the PATH_INFO to be used for this URL
for future requests to the same URL.
It receives the URL of the request (to be used as the key to the cache) and a reference to
the data being stored:

    $self->_set_cache($url, $args);

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

=item * Mark Stosberg <mark@summersault.com>

=item * Viacheslav Sheveliov <slavash@aha.ru>

=back

=head1 SECURITY

Since C::A::Dispatch will dynamically choose which modules to use as the content generators,
it may give someone the ability to execute random modules on your system if those modules can
be found in you path. Of course those modules would have to behave like L<CGI::Application> based
modules, but that still opens up the door more than most want. This should only be a problem
if you don't use a L<prefix>. By using this option you are only allowing Dispatch to pick from
a namespace of modules to run.

=head1 SEE ALSO

L<CGI::Application>, L<Apache::Dispatch>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

