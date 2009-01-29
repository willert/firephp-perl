package FirePHP::LogConnector::Catalyst;

=pod

=head1 NAME

FirePHP::LogConnector::Catalyst

=head1 SYNOPSIS

 use FirePHP::LogConnector::Catalyst;
 my $foo = FirePHP::LogConnector::Catalyst->new();

=head1 DESCRIPTION

B<FirePHP::LogConnector::Catalyst> provides some simple
Catalyst related infrastructure to log connectors

=cut

use strict;
use warnings;

use base qw/FirePHP::LogConnector/;

use Carp;
use Scalar::Util qw/blessed weaken/;
__PACKAGE__->mk_accessors( qw/catalyst logger / );


=head1 METHODS

=head2 $class->new( $app )

Returns a new abstract log connector with a
reference to the application class in C<catalyst>
and enabled based on the classes debug mode.

=cut

sub new {
  my ($class, $catalyst ) = @_;

  my $app = blessed( $catalyst ) || $catalyst;

  my $self = $class->SUPER::new({
    catalyst  => $app,
    enabled   => $app->debug ? 1 : 0,
    logger    => $app->log,
  });

  weaken $self->{logger};
  return $self;
}


=head2 $self->enabled

Returns true if the FirePHP dispatcher is enabled and the logger not aborted

=cut

sub enabled {
  my $self = shift;
  return if $self->logger->{abort};
  return $self->SUPER::enabled;
}


=head2 $self->finalization_method

Returns a closure that can be used by subclassed during their dispatch cycle

=cut

sub finalization_method {
  my $self = shift;
  return sub{
    # flushing the log before we loose our headers object
    $self->flush_log;
    $self->fetch_dispatcher->finalize;
  }
}


=head2 $self->flush_log

Generic log flush for catalyst loggers

=cut

sub flush_log {
  my $self = shift;
  # $log->{abort} fits most Catalyst loggers $log->abort is inconsistent
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

