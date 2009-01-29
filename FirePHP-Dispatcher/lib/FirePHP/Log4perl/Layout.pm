package FirePHP::Log4perl::Layout;

=pod

=head1 NAME

FirePHP::Log4perl::Layout

=head1 SYNOPSIS


In your C<Log::Log4perl> config:

 log4perl.rootLogger = DEBUG, FIREPHP

 log4perl.appender.FIREPHP = FirePHP::Appender
 log4perl.appender.FIREPHP.layout = FirePHP::Layout

=head1 DESCRIPTION

B<FirePHP::Layout> is a specialized layout for FirePHP
based on (and hopefully mostly compatible to)
L<Log::Log4perl::Layout::PatternLayout>

=cut

use strict;
use warnings;

use base qw/Log::Log4perl::Layout::PatternLayout/;

use Carp;
use Scalar::Util qw/looks_like_number blessed/;
use JSON::Any;


=head1 METHODS

=head2 $class->new

Returns: a FirePHP compatible L<Log::Log4perl::Layout::PatternLayout> object

=cut

sub new {
  my $this = shift;
  my $self = $this->SUPER::new( @_ );
  $self->{info_needed}{$_} = 1 for qw/F L M l/;
  $self->{json} = JSON::Any->new;
  return $self;
}

# unfortunately this had to be lifted almost verbatim from
# Log::Log4perl::Layout::PatternLayout because there is no way
# we can access the the info hash otherwise


=head2 $self->render( $message, $category, $priority, $caller_level )

Overriden L<Log::Log4perl::Layout> renderer.

=cut

sub render {
  my ( $self, $message, $category, $priority, $caller_level ) = @_;

  $caller_level = 0 unless defined  $caller_level;

  my %info    = ();

  $info{m}    = $message;
  # See 'define'
  chomp $info{m} if $self->{message_chompable};

  my @results = ();

  if ($self->{info_needed}->{L} or
        $self->{info_needed}->{F} or
          $self->{info_needed}->{C} or
            $self->{info_needed}->{l} or
              $self->{info_needed}->{M} or
                0
              ) {
    my ($package, $filename, $line,
        $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require,
        $hints, $bitmask) = caller($caller_level);

    # If caller() choked because of a whacko caller level,
    # correct undefined values to '[undef]' in order to prevent
    # warning messages when interpolating later
    unless(defined $bitmask) {
      for ($package,
           $filename, $line,
           $subroutine, $hasargs,
           $wantarray, $evaltext, $is_require,
           $hints, $bitmask) {
        $_ = '[undef]' unless defined $_;
      }
    }

    $info{L} = $line;
    $info{F} = $filename;
    $info{C} = $package;

    if ($self->{info_needed}->{M} or
          $self->{info_needed}->{l} or
            0) {
      # To obtain the name of the subroutine which triggered the
      # logger, we need to go one additional level up.
      my $levels_up = 1;
      {
        $subroutine = (caller($caller_level+$levels_up))[3];
        # If we're inside an eval, go up one level further.
        if (defined $subroutine and
              $subroutine eq "(eval)") {
          $levels_up++;
          redo;
        }
      }
      $subroutine = "main::" unless $subroutine;
      $info{M} = $subroutine;
      $info{l} = "$subroutine $filename ($line)";
    }
  }

  $info{X} = "[No curlies defined]";
  $info{x} = Log::Log4perl::NDC->get() if $self->{info_needed}->{x};
  $info{c} = $category;
  $info{d} = 1;                 # Dummy value, corrected later
  $info{n} = "\n";
  $info{p} = $priority;
  $info{P} = $$;
  $info{H} = $Log::Log4perl::Layout::PatternLayout::HOSTNAME;

  if ( $self->{info_needed}->{r} ) {
    if ( $Log::Log4perl::Layout::PatternLayout::TIME_HIRES_AVAILABLE ) {
      $info{r} = int((
        Time::HiRes::tv_interval(
          $Log::Log4perl::Layout::PatternLayout::PROGRAM_START_TIME
        )) * 1000 );
    } else {
      if ( ! $Log::Log4perl::Layout::PatternLayout::TIME_HIRES_AVAILABLE_WARNED) {
        $Log::Log4perl::Layout::PatternLayout::TIME_HIRES_AVAILABLE_WARNED++;
        # warn "Requested %r pattern without installed Time::HiRes\n";
      }
      $info{r} = time() - $Log::Log4perl::Layout::PatternLayout::PROGRAM_START_TIME;
    }
  }

  # Stack trace wanted?
  if ($self->{info_needed}->{T}) {
    my $mess = Carp::longmess();
    chomp($mess);
    $mess =~ s/(?:\A\s*at.*\n|^\s*Log::Log4perl.*\n|^\s*)//mg;
    $mess =~ s/\n/, /g;
    $info{T} = $mess;
  }

  # As long as they're not implemented yet ..
  $info{t} = "N/A";

  foreach my $cspec (keys %{$self->{USER_DEFINED_CSPECS}}) {
    next unless $self->{info_needed}->{$cspec};
    $info{$cspec} = $self->{USER_DEFINED_CSPECS}->{$cspec}->(
      $self,$message, $category, $priority, $caller_level+1
    );
  }

  # Iterate over all info fields on the stack
  for my $e (@{$self->{stack}}) {
    my($op, $curlies) = @$e;
    if (exists $info{$op}) {
      my $result = $info{$op};
      if ($curlies) {
        $result = $self->curly_action($op, $curlies, $info{$op});
      } else {
        # just for %d
        if ($op eq 'd') {
          $result = $info{$op}->format($self->{time_function}->());
        }
      }
      $result = "[undef]" unless defined $result;
      push @results, $result;
    } else {
      warn "Format %'$op' not implemented (yet)";
      push @results, "FORMAT-ERROR";
    }
  }

  #print STDERR "sprintf $self->{printformat}--$results[0]--\n";

  my $rendered_message = sprintf( $self->{printformat}, @results );

  my ( $type ) = ( grep { $info{p} eq $_ } qw/INFO WARN ERROR/ );
  $type ||= 'INFO';

  my $source = $info{c};

  my ( $source_method ) = reverse split( '::', $info{M} );

  my %info_hash = (
    Type => $type,
    File => $info{F},
    Line => $info{L},
  );

  return $self->{json}->objToJson(
    [ \%info_hash, $rendered_message ]
  );
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


