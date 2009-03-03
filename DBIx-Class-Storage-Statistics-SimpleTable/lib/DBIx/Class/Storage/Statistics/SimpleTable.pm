package DBIx::Class::Storage::Statistics::SimpleTable;

use warnings;
use strict;

use 5.008005;

use version;
our $VERSION = '0.01_01';

=head1 NAME

DBIx::Class::Storage::Statistics::SimpleTable - DBIC statistics in a table

=head1 SYNOPSIS

 use My::DBIC::Schema;
 use DBIx::Class::Storage::Statistics::SimpleTable;

 my $dbic_schema = My::DBIC::Schema->connect;

 # using DBIx::Class::Storage::Statistics::SimpleTable as single debug object
 my $profiler = DBIx::Class::Storage::Statistics::SimpleTable->new();
 $dbic_schema->storage->debugobj( $profiler );
 $dbic_schema->debug( 1 );
 # ... do stuff with your schema ...
 print $profiler->report->draw;

 # using DBIx::Class::Storage::Statistics::SimpleTable with delegation
 # to the original object and FirePHP::Dispatcher support
 my $profiler = DBIx::Class::Storage::Statistics::SimpleTable
   ->new( 'FirePHP::SimpleTable' );
 $profiler->install( $dbic_schema );
 # ... do stuff with your schema ...
 $firephp_dispatcher->table( 'DBIC Profile' => $profiler->report );

=head1 DESCRIPTION

B<DBIx::Class::Storage::Statistics::SimpleTable> is a
L<DBIx::Class::Storage::Statistics> subclass that gathers
L<DBIx::Class> profiling information in a L<Text::SimpleTable>
class or sub-class.

This module was created to support L<Catalyst::Plugin::FirePHP>
but maybe some will find it useful one its own.

=cut

use base qw/DBIx::Class::Storage::Statistics/;

use Time::HiRes qw/gettimeofday tv_interval/;
use MRO::Compat;
use Text::SimpleTable;
use Scalar::Util qw/weaken/;

=head1 METHODS

=head2 $class->new( ?$table_class )

Creates a new statistics object, optionally using the
L<Text::SimpleTable> sub-class given as argument

=cut

sub new {
  my ( $class, $table_class ) = @_;
  $table_class ||= 'Text::SimpleTable';
  die "$table_class is no Text::SimpleTable"
    unless $table_class->isa('Text::SimpleTable');
  my $self = $class->next::method();
  $self->{table_class} = $table_class;
  $self->{total_time} = 0.0;
  $self->{query_count} = 0;
  return $self;
}

=head2 $self->install( $storage )

Installs this statistics instance into a L<DBIx::Class::Storage> object.
The original C<debugobj> and C<debug> state will be preserved and all
statistic events delegated to the original object.

=cut

sub install {
  my ( $self, $storage ) = @_;
  $self->{storage_object} = $storage;
  weaken $self->{storage_object};
  $self->{storage_debugobj} = $storage->debugobj;
  $storage->debugobj( $self );
}

=head2 $self->uninstall

Removes this statistics instance from the associated L<DBIx::Class::Storage>
object and restores its original state.

=cut

sub uninstall {
  my $self = shift;
  return unless $self->{storage_object};
  $self->{storage_object}->debugobj( delete $self->{storage_debugobj} );
  $self->{storage_object}->debug( delete $self->{storage_debug} );
  delete $self->{storage_object};
}

=head1 INFORMATIONAL METHODS

=head2 $self->report

Returns the gathered statistics as L<Text::SimpleTable> object
(or as the sub-class choosen at object creation)

=cut

sub report {
  my $self = shift;
  return $self->{report_table};
}

=head2 $self->elapsed_time

Returns the total time spend in L<DBIx::Class> queries.

=cut

sub elapsed_time {
  my $self = shift;
  return $self->{total_time};
}


=head2 $self->query_count

Returns the number of queries processed.

=cut

sub query_count {
  my $self = shift;
  return $self->{query_count};
}

=head1 OVERRIDDEN METHODS

=head2 $self->query_start

Logs the starting time of the request

=cut

sub query_start {
  my $self = shift;
  $self->{query_started} = [ gettimeofday() ];
  $self->{storage_debugobj}->query_start( @_ )
    if $self->{storage_debug};
}

=head2 $self->query_end( $sql, @params )

Write the query string, parameters and elepsed time to the statistics table.

=cut

sub query_end {
  my ( $self, $sql, @params ) = @_;

  $self->{total_time} += my $elapsed = sprintf(
    '%0.4f', tv_interval( delete $self->{query_started} )
  );

  $self->{query_count} += 1;

  $self->{report_table} ||= $self->{table_class}->new(
    [ 30, 'SQL'    ],
    [ 28, 'Params' ],
    [  9, 'Time'   ],
  );

  $self->report->row( $sql, join( ', ', @params ) || '', $elapsed );
  $self->{storage_debugobj}->query_end( $sql, @params )
    if $self->{storage_debug};
}


sub DESTROY {
  my $self = shift;
  $self->uninstall;
}

our $AUTOLOAD;
sub AUTOLOAD {
  my $self = shift;

  my $method = $AUTOLOAD;
  $method =~ s/^.*://;

  croak( "Method $method not found" )
    unless $self and $self->{storage_debugobj};

  return unless $self->{storage_debug};

  return $self->stats_object->$method(@_)
    if $self->stats_object->can( $method );

  croak( "Method $method not found" );
}

1;

__END__

=head1 SEE ALSO

L<perl>, L<Text::SimpleTable>, L<FirePHP::Dispatcher>

=head1 AUTHOR

Sebastian Willert, C<willert@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Sebastian Willert E<lt>willert@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
