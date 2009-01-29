package FirePHP::Log4perl::Appender;

use warnings;
use strict;

=head1 NAME

FirePHP::Log4perl::Appender

=head1 SYNOPSIS

In your C<Log::Log4perl> config:

 log4perl.rootLogger = DEBUG, FIREPHP

 log4perl.appender.FIREPHP = FirePHP::Appender
 log4perl.appender.FIREPHP.layout = FirePHP::Layout
 log4perl.appender.FIREPHP.layout.ConversionPattern = [ %c ] %m

In the dispatcher of your application:

 my $appender = first { $_->isa( 'FirePHP::Log4perl::Appender' ) }
   map{ $_->{appender} } values %{ Log::Log4perl->appenders() };
 local $appender->{fire_php} =
   FirePHP::Dispatcher->new( $your_http_headers_compatile_object );

 # the normal dispatch stuff

 $appender->fire_php->finalize;

=head1 DESCRIPTION

This is a very simple appender for writing to a FirePHP console.
Nontheless it is not easy to use because of scoping and threading
issues because L<Log::Log4perl> normally just provides an application
wide appender object that has no access whatsoever to the L<HTTP::Headers>
object of the current object. Your best bet is to use a plugin that is
spezialised for your framework.

=cut

use base qw/Log::Log4perl::Appender/;

use Carp;
use Scalar::Util qw/looks_like_number blessed weaken/;
use Data::Dump qw/dump/;

=head1 METHODS

=head2 $class->new( %options )

This creates a new, unassociated appender object. Most of the time
you do not want to bind to a L<FirePHP::Dispatcher> object during
creation but directly set (and un-set) it in the appropriate time
during your application life-cycle.

Returns: a new C<FirePHP::Log4perl::Appender> object

=cut


sub new {
  my $class = shift;
  my $self = bless { @_ }, $class;
}


=head2 $self->fire_php

Returns: the associated L<FirePHP::Dispatcher> or C<undef>
if the appender is not bound to one

=cut

sub fire_php {
  my $self = shift;
  return $self->{fire_php};
}


=head2 $self->log( %params )

Used by L<Log::Log4perl::Appender> to send messages
to the FirePHP console

=cut

sub log {
  my ( $self, %p ) = @_;
  return unless $self->fire_php;
  $self->fire_php->send_headers( $p{message} );
  return 1;
}

1;

__END__

=head1 SEE ALSO

L<http://www.firephp.org>, L<Log::Log4perl>, L<FirePHP::Catalyst::Plugin>

=head1 AUTHOR

Sebastian Willert, C<willert@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Sebastian Willert E<lt>willert@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

