package DBIx::Class::Storage::Statistics::SimpleTable;

use warnings;
use strict;

use 5.008005;

use version;
our $VERSION = '0.02';

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
use Scalar::Util qw/weaken blessed/;
use Carp;

=head1 METHODS

=head2 $class->new( ?$table_class, \%opts )

Creates a new statistics object, optionally using the
L<Text::SimpleTable> sub-class given as argument.

Options include:

=over 4

=item threshold

Queries with a run-time below this number of seconds (with floating point
precision) won't be logged. This is useful for slow query reporting.

=item skip_params

Don't create and log to the params column

=back

=cut

sub new {
  my ( $class, $table_class, $opts ) = @_;
  if ( ref $table_class eq 'HASH' ) {
    $opts = $table_class;
    undef $table_class;
  }

  $table_class ||= 'Text::SimpleTable';
  $opts        ||= {};

  die "$table_class is no Text::SimpleTable"
    unless $table_class->isa('Text::SimpleTable');

  my $self = $class->next::method();
  $self->{table_class}      = $table_class;
  $self->{total_time}       = 0.0;
  $self->{query_count}      = 0;
  $self->{report_row_count} = 0;
  $self->{skip_params}      = delete $opts->{skip_params};
  $self->{threshold}        = delete $opts->{threshold} || 0;
  $self->{initiator}        = caller;

  $self->{report_header}    = delete $opts->{header}
    || [[ 30, 'SQL' ],  [ 28, 'Params' ],  [ 9, 'Time' ]];

  $self->_build_report_header;

  croak "Unknown options: " . join( ', ', keys %$opts ) if %$opts;

  return $self;
}

sub _build_report_header {
  my $self = shift;
  if ( @{ $self->{report_header} } == 3 and $self->{skip_params} ) {
    $self->{report_header}[0][0] += $self->{report_header}[1][0] + 3;
    splice @{ $self->{report_header} }, 1, 1;
  }

  croak "Invalid column count in report_header" unless
    @{$self->{report_header}} == 3 or
      ( @{$self->{report_header}} == 2 and $self->{skip_params} );
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
(or as the sub-class chosen at object creation).

It tries its best to return the report you are interested in
when multiple B<DBIx::Class::Storage::Statistics::SimpleTable> are chained
together. This is currently bound to the package that created the statistics
object, i.E. when you are guaranteed to get the correct report when the
creation happened in the same package as reported by C<caller()>.

This behavior might change in later versions when somebody comes up
with a better idea how to handle these situations.

=cut

sub report {
  my $self = shift;

  my $this = $self;
  my @report_chain = $this;

  while ( my $next_report = $this->{storage_debugobj} ) {
    if ( blessed $next_report and $next_report->isa( __PACKAGE__ ) ) {
      push @report_chain, $next_report;
    }
    $this = $next_report;
  }

  my ( $report ) = grep{
    scalar caller() eq $_->{initiator} and $_->{report_table}
  } @report_chain;
  $report ||= $self;

  return $report->{report_table};

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

=head2 $self->report_row_count

Returns the number of queries actually included in the report.

=cut

sub report_row_count {
  my $self = shift;
  return $self->{report_row_count};
}

=head1 OVERRIDDEN METHODS

=head2 $self->query_start

Logs the starting time of the request

=cut

sub query_start {
  my $self = shift;
  $self->{query_started} = [ gettimeofday() ];
  $self->{storage_debugobj}->query_start( @_ )
    if $self->{storage_debugobj}->isa(__PACKAGE__) or $self->{storage_debug};
}

=head2 $self->query_end( $sql, @params )

Write the query string, parameters and elapsed time to the statistics table.

=cut

sub query_end {
  my ( $self, $sql, @params ) = @_;

  $self->{total_time} += my $elapsed = sprintf(
    '%0.6f', tv_interval( delete $self->{query_started} )
  );

  $self->{query_count} += 1;

  if ( not $self->{report_table} ) {
    $self->{report_table} = $self->{table_class}->new(
      @{ $self->{report_header} }
    );
  }

  goto NEXT_STATS_INSTANCE if $elapsed < $self->{threshold};

  $self->{report_table}->row(
    $sql, $self->{skip_params} ? () : join( ', ', @params ) || '', $elapsed
  );

 NEXT_STATS_INSTANCE:
  $self->{storage_debugobj}->query_end( $sql, @params )
    if $self->{storage_debugobj}->isa(__PACKAGE__) or $self->{storage_debug};

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

=head1 BUGS

Plenty, I guess. Especially because this is release has no tests
apart from standard loading and critics stuff. Patches or pull requests
welcome.

=head1 SOURCE AVAILABILITY

This code is in Github:

 git://github.com/willert/fierphp-perl.git

=head1 SEE ALSO

L<http://github.com/willert/firephp-perl/>,
L<perl>, L<Text::SimpleTable>, L<FirePHP::Dispatcher>

=head1 AUTHOR

Sebastian Willert, C<willert@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Sebastian Willert E<lt>willert@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
