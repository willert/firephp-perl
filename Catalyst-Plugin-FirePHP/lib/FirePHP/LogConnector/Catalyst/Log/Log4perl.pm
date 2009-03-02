package FirePHP::LogConnector::Catalyst::Log::Log4perl;

=pod

=head1 NAME

FirePHP::LogConnector::Catalyst::Log::Log4perl

=head1 SYNOPSIS

 use FirePHP::LogConnector::Catalyst::Log::Log4perl;
 my $foo = FirePHP::LogConnector::Catalyst::Log::Log4perl->new();

=head1 DESCRIPTION

B<FirePHP::LogConnector::Catalyst::Log::Log4perl> connects
a L<Catalyst::Log::Log4perl> instance to the FirePHP::Dispatcher

=cut

use strict;
use warnings;

use base qw/FirePHP::LogConnector::Catalyst/;

use Carp;
use Scope::Guard;
use Scalar::Util qw/weaken blessed/;
use List::Util   qw/first/;

use Log::Log4perl;
use FirePHP::Log4perl::Appender;
use FirePHP::Log4perl::Layout;

__PACKAGE__->mk_accessors( qw/appender/ );

=head1 METHODS

=head2 $class->new( $catalyst )

Returns a new log connector for L<Catalyst::Log::Log4perl> loggers

=cut

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( @_ );

  return unless $self->enabled;

  # try to respect custom appender configs
  my $appender = first { $_->isa( 'FirePHP::Log4perl::Appender' ) }
    map{ $_->{appender} } values %{ Log::Log4perl->appenders() };

  if ( not $appender ) {
    # Auto-create an appender if none has been configured
    my $wrapper = Log::Log4perl::Appender->new(
      "FirePHP::Log4perl::Appender",
      name => 'Default FirePHP appender'
    );

    # Set the appender's layout
    $wrapper->layout( FirePHP::Log4perl::Layout->new() );

    # get the root logger (as described in the Log4perl docs)
    # and add the FirePHP appender
    my $logger = Log::Log4perl->get_logger('');
    $logger->add_appender( $wrapper );

    $appender = $wrapper->{appender};
  }

  die "Internal error while creating appender instance" unless $appender;

  printf STDERR "Ready: $appender\n", ;

  $self->appender( $appender );

  # override log4perl's _dump method because to much info
  # is lost when the layout gets hold of it
  my $logger_class = blessed( $self->logger );

  printf STDERR "Logger is: $logger_class\n", ;

  my $original_dumper = $logger_class->can( '_dump' );
  if ( $original_dumper ) {
    no strict 'refs';
    no warnings 'redefine';
    *{"${logger_class}::_dump"} = sub {
      my $log = shift;

      # send the variable directly to the FirePHP dispatcher
      # that will produce a dump on its own
      $appender->{fire_php}->log( @_ ) if $appender->{fire_php};

      # this is ugly, ugly, ugly: we need to flush before and after
      # the original dump to ensure that no messages are lost but
      # the appender gets called right away so it will notice that
      # its FirePHP dispatcher is missing
      $self->flush_log;
      # temporarily disable the appender so we don't get
      # duplicate messages
      local $appender->{fire_php};
      my $res = $original_dumper->( $log, @_ );
      $self->flush_log;
      return $res
    }
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

  local $self->{appender}{fire_php} = $fire_php;
  my $finalize = Scope::Guard->new( $self->finalization_method( $c ) );

  $self->prepare_dispatcher( $c, @_ );

  $dispatch->( $c, @_ );
}

=head2 $self->fetch_dispatcher

Returns the current L<FirePHP::Dispatcher> object.

=cut

sub fetch_dispatcher {
  my $self = shift;
  return unless $self->{appender};
  return $self->{appender}->fire_php;
}

=head2 $self->prepare_grouping

Due to the sequential nature of FirePHP log messages
and groups all logs need to be flushed before opening
or closing a message group.

=cut

sub prepare_grouping {
  my $self = shift;
  $self->logger->_flush unless $self->logger->{abort};
  return;
}

1;

__END__

=head1 SEE ALSO

L<http://www.firephp.org>, L<FirePHP::Dispatcher>

=head1 AUTHOR

Sebastian Willert, C<willert@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Sebastian Willert E<lt>willert@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

