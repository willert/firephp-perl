package FirePHP::LogConnector;

=pod

=head1 NAME

FirePHP::LogConnector

=head1 DESCRIPTION

B<FirePHP::LogConnector> is an abstract base class for
FirePHP log connectors.

=cut

use strict;
use warnings;

use base qw/Class::Accessor::Fast/;
__PACKAGE__->mk_accessors( qw/enabled fire_php/ );

use Carp;
use Scalar::Util qw/blessed/;

=head1 METHODS

=head2 $class->new

Returns a new abstract log connector

=cut

sub new {
  my $class = shift;
  my %opts;
  %opts = %{ $_[0] } if ref $_[0] eq 'HASH';
  $opts{enabled} = 0 unless exists $opts{enabled};
  $opts{fire_php} = 0 unless exists $opts{fire_php};

  return $class->SUPER::new( \%opts );
}

=head2 $self->prepare_grouping

Subclasses that need to prepare the opening or closing
of a group (e.g. flushing the logs) should implement it here.

=cut

sub prepare_grouping {}

=head2 $self->dispatch_request( $coderef, @args )

Handler for controlling the dispatch cycle and binding L<FirePHP::Dispatcher>
to the current response headers.

=cut

sub dispatch_request { croak 'Method needs to be defined in a subclass' }

=head2 $self->flush_log

Method to write all pending FirePHP messages (not necessarily all
log messages) to the response headers.

=cut

sub flush_log { croak 'Method needs to be defined in a subclass' }

=head2 $self->fetch_dispatcher

Returns the current L<FirePHP::Dispatcher> object.

=cut

sub fetch_dispatcher {
  my $self = shift;
  return $self->{fire_php};
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
