package FirePHP::Example::Catalyst::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';


# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
__PACKAGE__->config->{namespace} = '';

=head1 NAME

FirePHP::Example::Catalyst::Controller::Root - Just creates a few log messages

=head1 DESCRIPTION

Just creates a few log messages that will be send to the FirePHP console

=head1 METHODS

=cut

=head2 default

=cut

sub begin : Private {
  my ( $self, $c ) = @_;
  $c->log->warn( 'Hello from BEGIN' );
}

sub auto : Private {
  my ( $self, $c ) = @_;
  $c->log->warn( 'Hello from AUTO' );
  return 1;
}

sub default : Private {
  my ( $self, $c ) = @_;

  # Hello World
  $c->log->warn( 'Greetings from your <br /> WARN log level' );
  $c->log->info( <<MSG );
Greetings from your INFO log level
MSG

  $c->forward( 'nested' );

  $c->firephp_log->info({struct => 'HASH', through => 'FirePHP::Dispatcher'});
  $c->firephp_log->log(['struct', 'ARRAY', 'through', 'FirePHP::Dispatcher']);
  $c->log->_dump({ logging => 'direct', through => 'Catalyst::Log' });

  $c->log->debug( 'Greetings from your DEBUG log level' );

}

sub nested : Private {
  my ( $self, $c ) = @_;
  $c->log->info( 'I am nested!!' );
}


=head2 end

Attempt to render a view, if needed.

=cut

sub end :Private {
  my ( $self, $c ) = @_;
  $c->log->warn( 'Hello from END' );
  $c->log->_dump([ map{[ caller($_) ]} 1 .. 12 ]);
  $c->response->body( $c->welcome_message );
}

1;
