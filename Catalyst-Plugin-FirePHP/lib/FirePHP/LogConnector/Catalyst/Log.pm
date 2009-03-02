package FirePHP::LogConnector::Catalyst::Log;

=pod

=head1 NAME

FirePHP::LogConnector::Catalyst::Log

=head1 SYNOPSIS

In your MyApp.pm:

  use Catalyst qw/ ... +FirePHP /;

=head1 DESCRIPTION

B<FirePHP::LogConnector::Catalyst::Log> hijacks a L<Catalyst::Log> instance,
connects itself to the current L<FirePHP::Dispatcher> and delegates all log
messages to both simultaneously.

=cut

use strict;
use warnings;

use base qw/FirePHP::LogConnector::Catalyst/;

use Carp;
use Scope::Guard;

use Sub::Uplevel;

__PACKAGE__->mk_accessors( qw/logger/ );

our $AUTOLOAD;

=head1 METHODS

=head2 $class->new( $catalyst )

Returns a new log connector for L<Catalyst::Log> loggers

=cut

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( @_ );

  if ( $self->enabled ) {
    # reestablish a strong logger relationship that has been
    # weakend in our superclass
    $self->logger( $self->logger );
    # inject myself between the app and its logger
    $self->catalyst->log( $self );
  }

  return $self;
}


=head2 $self->dispatch_request

Handler for controlling the dispatch cycle and binding L<FirePHP::Dispatcher>
to the current response headers.

=cut

sub dispatch_request {
  my ( $self, $dispatch, $c ) = splice @_, 0, 3;

  my $fire_php = FirePHP::Dispatcher->new( $c->response->headers  );

  local $self->{fire_php} = $fire_php;
  my $finalize = Scope::Guard->new( $self->finalization_method( $c ) );

  $self->prepare_dispatcher( $c, @_ );

  uplevel 1, sub{ $dispatch->( $c, @_ ) };
}


=head2 $self->flush_log

Method to write all pending FirePHP messages to the response headers
and flushes the logging cache

=cut

sub flush_log {
  my $self = shift;
  $self->logger->_flush unless $self->logger->abort;
  return;
}


=head2 $this->can

Overrides can to accommodate delegation to the original logger

=cut


sub can {
  my $this = shift;
  my $res = $this->SUPER::can( @_ );
  $res ||=  $this->logger->can( @_ ) if defined $this->logger;
  return unless $res;
  return $res;
}


=head2 $self->debug( $message )

Sends a debug log message to both the logger and FirePHP.
The FirePHP message uses the 'info' priority.

=head2 $self->info( $message )

Sends a informational log message to both the logger and FirePHP.

=head2 $self->warn( $message )

Sends a warning message to both the logger and FirePHP.

=head2 $self->error( $message )

Sends a error message to both the logger and FirePHP.

=head2 $self->fatal( $message )

Sends a fatal error message to both the logger and FirePHP.
The FirePHP message uses the 'error' priority.

=cut

{
  my @levels = qw[ debug info warn error fatal ];
  my %in_firephp = ( debug => 'info', fatal => 'error' );

  for my $level ( @levels ) {

    no strict 'refs';

    *{$level} = sub {
      my $self = shift;
      return unless $self->logger;
      my $is_enabled = "is_${level}";
      if ( $self->logger->$is_enabled ) {
        $self->logger->$level( @_ );
        return unless $self->{fire_php};
        my $firephp_level = $in_firephp{ $level } || $level;
        $self->{fire_php}->$firephp_level( @_ );
      }
    };
  }
}

sub _dump {
  my $self = shift;
  return unless $self->logger;
  if ( $self->logger->is_info ) {
    $self->logger->_dump( @_ );
    return unless $self->{fire_php};
    $self->{fire_php}->log( @_ );
  }
}

sub AUTOLOAD {
  my $self = shift;

  my $method = $AUTOLOAD;
  $method =~ s/^.*://;

  return if ( $method eq 'DESTROY' );

  return $self->logger->$method(@_)
    if $self->logger->can( $method );

  croak( "Method $method not found" );
}

1;

__END__


=head1 SEE ALSO

L<http://www.firephp.org>, L<Catalyst>, L<Catalyst::Log>,
L<FirePHP::Dispatcher>, L<FirePHP::LogConnector>

=head1 AUTHOR

Sebastian Willert, C<willert@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Sebastian Willert E<lt>willert@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
