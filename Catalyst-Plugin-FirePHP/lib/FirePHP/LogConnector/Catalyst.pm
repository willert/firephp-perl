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


=head2 $self->prepare_dispatcher

Support method for LogConnector instances. Requires the
L<FirePHP::Dispatcher> instance to be already in place.

Right now, this basically handles logging request parameters.

=cut

sub prepare_dispatcher {
  my ( $self, $c ) = @_;

  # error reporting is unreliable in this stage
  local $SIG{__DIE__} = sub{
    $c->log->error( @_ );
    die @_ if $^S;
  };

  my $fire_php = $self->fetch_dispatcher
    or die( "Couldn't find FirePHP::Dispatcher while preparing dispatcher" );

  # mostly verbatim from Catalyst.pm (prepare_parameters)
  if ( keys %{ $c->request->query_parameters } ) {
    my $t = Text::SimpleTable->new( [ 35, 'Parameter' ], [ 36, 'Value' ] );
    for my $key ( sort keys %{ $c->req->query_parameters } ) {
      my $param = $c->req->query_parameters->{$key};
      my $value = defined($param) ? $param : '';
      $t->row( $key, ref $value eq 'ARRAY' ? join( ', ', @$value ) : $value );
    }
    $fire_php->table( "Query Parameters" => $t );
  }

  # mostly verbatim from Catalyst.pm (prepare_body)
  if ( keys %{ $c->req->body_parameters } ) {
    my $t = Text::SimpleTable->new( [ 35, 'Parameter' ], [ 36, 'Value' ] );
    for my $key ( sort keys %{ $c->req->body_parameters } ) {
      my $param = $c->req->body_parameters->{$key};
      my $value = defined($param) ? $param : '';
      $t->row( $key, ref $value eq 'ARRAY' ? join( ', ', @$value ) : $value );
    }
    $fire_php->table( "Body Parameters" => $t );
  }

  # mostly verbatim from Catalyst.pm (prepare_uploads)
  if ( keys %{ $c->request->uploads } ) {
    my $t = Text::SimpleTable->new(
      [ 12, 'Parameter' ],
      [ 26, 'Filename' ],
      [ 18, 'Type' ],
      [ 9,  'Size' ]
    );
    for my $key ( sort keys %{ $c->request->uploads } ) {
      my $upload = $c->request->uploads->{$key};
      for my $u ( ref $upload eq 'ARRAY' ? @{$upload} : ($upload) ) {
        $t->row( $key, $u->filename, $u->type, $u->size );
      }
    }
    $fire_php->table( "File Uploads" => $t );
  }

  for my $model ( map{ $c->model( $_ ) } $c->models ) {
    if ( $model->isa('Catalyst::Model::DBIC::Schema') ) {
      my $profiler = 'DBIx::Class::Storage::Statistics::SimpleTable';
      eval{ "require $profiler" } or next;
      $profiler->new('FirePHP::SimpleTable')->install( $model->storage );
    }
  }

}

=head2 $self->finalization_method

Returns a closure that can be used by subclassed during their dispatch cycle

=cut

sub finalization_method {
  my ( $self, $c ) = @_;
  my $fire_php = $self->fetch_dispatcher
    or die( "Couldn't find FirePHP::Dispatcher for finalization method" );

  return sub{

    # error reporting is unreliable in this stage
    local $SIG{__WARN__} = sub{ $c->log->warn( @_ ); };
    local $SIG{__DIE__}  = sub{ $c->log->error( @_ ); die @_ if $^S; };

    # flushing the log before we loose our headers object
    $self->flush_log;

    my $finalize = Scope::Guard->new(sub{ $fire_php->finalize });

    # scan our models for supported base classes
    for my $name ( $c->models ) {
      my $model = $c->model( $name );
      if ( $model->isa( 'Catalyst::Model::DBIC::Schema' ) ) {
        my $stats = $model->storage->debugobj;
        next unless $stats->isa(
          'DBIx::Class::Storage::Statistics::SimpleTable'
        ) and $stats->query_count;
        $fire_php->table( sprintf(
          "SQL Profile for ${name} (%d queries in %.4f sec)",
          $stats->query_count, $stats->elapsed_time,
        ) => $stats->report );
        $stats->uninstall;
      }
    }

    # override Text::SimpleTable to use the reporting of facility of
    # Catalyst::Stats (or generic stats packages that use Text::SimpleTable)
    my $new_table = \ &Text::SimpleTable::new;
    my $t = do{
      no warnings 'redefine';
      local *Text::SimpleTable::new = sub {
        bless $new_table->( @_ ), 'FirePHP::SimpleTable';
      };
      $c->stats->report;
    };
    $fire_php->table( "Request Statistics" => $t );

  };
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

