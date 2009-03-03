package Catalyst::Plugin::FirePHP;

use strict;
use warnings;

use 5.008005;

use version;
our $VERSION = '0.01_03';

=head1 NAME

Catalyst::Plugin::FirePHP - sends Catalyst log messages to a FirePHP console

=head1 SYNOPSIS

In your application class (e.g. MyApp.pm):

 use Catalyst ( ..., '+Catalyst::Plugin::FirePHP' );
 use Catalyst::Log::Log4perl;

 __PACKAGE__->config(
   name => 'Just a Catalyst application',
   FirePHP => { action_grouping => 1, compact => 1 }
 );

 # only if you want to change the appender layout to use cspecs
 __PACKAGE__->log( Catalyst::Log::Log4perl->new(
   'log4perl.conf', override_cspecs => 1
 ));

In your log4perl config (only if you want to change the message layout):

 log4perl.rootLogger = DEBUG, SCREEN, FIREPHP
 log4perl.appender.SCREEN = Log::Log4perl::Appender::Screen
 log4perl.appender.SCREEN.layout = SimpleLayout

 log4perl.appender.FIREPHP = FirePHP::Log4perl::Appender
 log4perl.appender.FIREPHP.layout = FirePHP::Log4perl::Layout

And later...

 $c->log->debug("This is using log4perl AND FirePHP!");

=head1 DESCRIPTION

B<Catalyst::Plugin::FirePHP> automatically binds the current response headers
to a newly created L<FirePHP::Dispatcher> in use and on demand creates nested
groups for all called actions.

The only thing you need to do to start using FirePHP is include this
plugin in your plugin list. Everything else should happen automatically,
no config is needed.

This plugin tries to be as unintrusive as possible if your application
doesn't run in debug mode, but it is highly recommended to drop it
altogether in production servers.

=cut

use MRO::Compat;

use Carp;
use Scalar::Util qw/looks_like_number blessed/;

use Scope::Guard;
use FirePHP::Dispatcher;
use List::Util qw/first/;
use Class::BlackHole;

use Catalyst::Utils qw//;


=head1 ACCESSORS

=head2 firephp_log

Direct access to the L<FirePHP::Dispatcher> in use.
Returns a L<Class::BlackHole> instance if none is
available so doesn't blow up your application
in case you forget to call it conditionally as in

  $c->firephp_log->info( 'Foo' ) if $c->firephp_log;

=cut

sub firephp_log {
  my $c = shift;
  my $connector = $c->_firephp_log_connector;
  return bless( {}, qw/Class::BlackHole/ )
    unless $connector and $connector->enabled;
  my $fire_php = $connector->fetch_dispatcher;
  $fire_php ||= bless( {}, qw/Class::BlackHole/ );
  return $fire_php;
}

=head1 EXTENDS

=head2 setup_components

After setup_components is executed this plugin tries to amend or hijack
the logger and create a suitable log connector, defaulting to
L<FirePHP::LogConnector::Catalyst::Log> which replaces the original
logger and tries to forward as much as possible.

=cut

sub setup_components {
  my $class = shift;
  $class->next::method( @_ );
  $class->mk_classdata( '_firephp_log_connector' );
  my $org_logger = blessed( $class->log );
  my $logging_class = $org_logger;
  my $connector;
  while ( 1 ) {
    $connector = "FirePHP::LogConnector::${logging_class}";
    eval{ Catalyst::Utils::ensure_class_loaded( $connector ) };
    warn $@ if $@ and $@ !~ m/can't locate/i;
    last unless $@;
    if ( $logging_class !~ /^Catalyst::Log/ ) {
      $logging_class = 'Catalyst::Log::Log4perl';
      next;
    } elsif ( $logging_class =~ /^Catalyst::Log::/ ) {
      my @parts = split '::', $logging_class;
      pop @parts;
      $logging_class = join '::', @parts;
      next;
    } elsif ( $logging_class ne "Catalyst::Log" ) {
      $class->log->warn(
        "Can't load connector for ${org_logger}, trying to use the " .
          "(somewhat generic) connector for Catalyst::Log instead\n  [$@]"
        );
      $logging_class = "Catalyst::Log";
    } else {
      die "Can't load connector for ${org_logger} and default doesn't work";
    }
  }
  $class->_firephp_log_connector( $connector->new( $class ) );
  return;
}


=head2 dispatch

Small wrapper that delegates all the work to the log connector if
FirePHP logging is enabled. If not, the normal call chain is resumed

Unfortunatly log connectors are responsible to ensure that the log is
flushed after the dispatch cycle ends. This can not easily be changed
due to various scoping issues.

=cut

sub dispatch {
  my $c = shift;

  # only fuck around with internals if the log connector is enabled
  return $c->next::method( @_ ) unless $c->_firephp_log_connector->enabled;

  my $guard = Scope::Guard->new(
    sub{ $c->log->error( $@ ? $@:(), @{ $c->error }) if @{ $c->error } or $@ }
  );
  $c->_firephp_log_connector->dispatch_request( $c->next::can, $c, @_ );
}

=head2 execute

Implements action grouping

=cut

sub execute {
  my $c = shift;
  my $action = $_[-1];

  goto EXECUTE unless $c->config->{FirePHP}{action_grouping};

  goto EXECUTE unless $c->_firephp_log_connector->enabled;
  goto EXECUTE if $action->name =~ m/^_/; # ignore build-ins

  goto EXECUTE unless blessed $action and $action->isa('Catalyst::Action');

  my $category      = join( '->', $action->class, $action->name );
  my $log_connector = $c->_firephp_log_connector;
  my $fire_php      = $log_connector->fetch_dispatcher;

  goto EXECUTE unless $fire_php;

  $log_connector->prepare_grouping;
  $fire_php->start_group( $category );

  my $close_group = sub{
    $log_connector->prepare_grouping;
    if ( $c->config->{FirePHP}{compact} ) {
      $fire_php->end_or_dismiss_group
    } else {
      $fire_php->end_group
    }
  };

  my $cleanup = Scope::Guard->new( $close_group );

 EXECUTE:
  $c->next::method( @_ );
}

1;

__END__

=head1 INTERNALS

=head2 _firephp_log_connector

Access to the L<FirePHP::LogConnector> in use.
This might return a L<FirePHP::LogConnector::Null>
in later versions. Right now, it defaults to
L<FirePHP::LogConnector::Catalyst::Log> regardless
of debug mode.

=head1 BUGS

Plenty, I guess. This is a pre-release version of
B<Catalyst::Plugin::FirePHP> and hasn't seen wide-spread
testing.

=head1 SOURCE AVAILABILITY

This code is in Github:

 git://github.com/willert/firephp-perl.git

A small wiki with sample screenshots is available at:

 L<http://wiki.github.com/willert/firephp-perl>

=head1 SEE ALSO

L<http://www.firephp.org>, L<Catalyst>, L<FirePHP::Dispatcher>

=head1 AUTHOR

Sebastian Willert, C<willert@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Sebastian Willert E<lt>willert@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
