package FirePHP::SimpleTable;

=pod

=head1 NAME

FirePHP::SimpleTable

=head1 SYNOPSIS

 use FirePHP::SimpleTable;
 my $foo = FirePHP::SimpleTable->new();

=head1 DESCRIPTION

B<FirePHP::SimpleTable> is a sub-class of L<Text::SimpleTable> that
can be used to write a table to the FirePHP console

=cut

use strict;
use warnings;

use base qw/Text::SimpleTable/;

use Carp;
use Scalar::Util qw/looks_like_number blessed/;

=head1 METHODS

=head2 $self->draw

Returns an array ref suitable for use with L<FirePHP::Dispatcher>'s
table method

=cut

sub draw {
  my $self = shift;
  return unless $self->{columns};
  my $rows    = @{ $self->{columns}->[0]->[1] } - 1;
  my $columns = @{ $self->{columns} } - 1;

  my $title = 0;
  for my $column ( @{ $self->{columns} } ) {
    $title = @{ $column->[2] } if $title < @{ $column->[2] };
  }

  my @result = ( \ my @header );
  if ( $title ) {
    for my $j ( 0 .. $columns ) {
      push @header, join(
        "\n", @{$self->{columns}->[$j]->[2]}[ 0 .. $title - 1 ]
      ) || '';
    }
  }

  # Rows
  for my $i ( 0 .. $rows ) {
    push @result, \ my @row;
    for my $j ( 0 .. $columns ) {
      my $column = $self->{columns}->[$j];
      my $text = ( defined $column->[1]->[$i] ) ? $column->[1]->[$i] : '';
      push @row, $text;
    }
  }

  return \@result;
}

sub _wrap {
  my ( $self, $text, $width ) = @_;
  return [ $text ];
}

1;

__END__

=head1 SEE ALSO

L<perl>, L<FirePHP::Dispatcher>

=head1 AUTHOR

Sebastian Willert, C<willert@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Sebastian Willert E<lt>willert@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


