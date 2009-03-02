package FirePHP::Dispatcher;

use strict;
use warnings;

BEGIN { require 5.008001; }

use version;
our $VERSION = '0.02_01';

=head1 NAME

FirePHP::Dispatcher - sends log messages to a FirePHP console

=head1 SYNOPSIS

 use FirePHP::Dispatcher;

 my $fire_php = FirePHP::Dispatcher->new(
   $reference_to_http_headers_of_current_request
 );

 $fire_php->log( 'Hello world' );

 $fire_php->start_group( 'Levels:' );
 $fire_php->info ( 'Log informational message' );
 $fire_php->warn ( 'Log warning message' );
 $fire_php->error( 'Log error message' );
 $fire_php->end_group;

 $fire_php->start_group( 'Propably empty:' );
 $fire_php->dismiss_group;

 $fire_php->finalize;

=head1 DESCRIPTION

B<FirePHP::Dispatcher> implements the basic interface
for logging to a FirePHP console. It is no logger on its own
but rather a basic API that can be used by front-end loggers to
divert or copy messages to a FirePHP console.

=cut

use base qw/Class::Accessor::Fast/;

use Carp;
use Scalar::Util qw/looks_like_number blessed/;
use JSON::Any;


__PACKAGE__->mk_accessors(
  qw/http_headers message_index stash json group_stack/
);


=head1 GENERAL METHODS

=head2 $class->new( $http_headers )

Creates a new instance of C<FirePHP::Dispatcher> and binds it
to the L<HTTP::Headers> object given as parameter.

Returns: a new C<FirePHP::Dispatcher> object

=cut

sub new {
  my ( $class, $http_headers ) = @_;
  croak "FirePHP::Dispatcher needs a HTTP::Headers object"
    unless blessed( $http_headers ) and $http_headers->isa( 'HTTP::Headers' );
  $class->SUPER::new({
    http_headers  => $http_headers,
    message_index => 0,
    group_stack   => [],
    stash         => {},
    json          => JSON::Any->new(),
  });
}


=head2 $self->finalize

Add the needed protocol headers and meta infos to the
L<HTTP::Headers> object if anything has been logged to it.
Without C<finalize>, FirePHP will ignore all messages.

=cut

sub finalize {
  my $self = shift;
  my $http = $self->http_headers or return;
  return unless $self->message_index;

  $http->header(
    'X-Wf-Protocol-1'     => 'http://meta.wildfirehq.org/' .
      'Protocol/JsonStream/0.2',
    'X-Wf-1-Plugin-1'     => 'http://meta.firephp.org/' .
      'Wildfire/Plugin/FirePHP/Library-FirePHPCore/0.2.0',
    'X-Wf-1-Structure-1'  => 'http://meta.firephp.org/' .
      'Wildfire/Structure/FirePHP/FirebugConsole/0.1',
    'X-Wf-1-Index'        => $self->message_index,
  );
}


=head1 LOGGING METHODS

=head2 $self->log( $message )

Log a plain message to the FirePHP console

=cut

sub log {
  my ( $self, $message ) = @_;
  $self->send_headers( $self->format_message({ Type => 'LOG' }, $message ));
}


=head2 $self->info( $message )

Log a informational message to the FirePHP console

Returns: Return value

=cut

sub info {
  my ( $self, $message ) = @_;
  $self->send_headers( $self->format_message({ Type => 'INFO' }, $message ));
}


=head2 $self->warn( $message )

Log a warning message to the FirePHP console

=cut

sub warn {
  my ( $self, $message ) = @_;
  $self->send_headers( $self->format_message({ Type => 'WARN' }, $message ));
}


=head2 $self->error( $message )

Log a error message to the FirePHP console

=cut

sub error {
  my ( $self, $message ) = @_;
  $self->send_headers( $self->format_message({ Type => 'ERROR' }, $message ));
}

=head1 TABLE METHODS

=head2 $self->table( $label, $table )

Prints the L<FirePHP::SimpleTable> or L<Text::SimpleTable> object
to the FirePHP console

=cut

sub table {
  my ( $self, $label, $table ) = @_;
  $label = '' unless defined $label;

  my $report;
  if ( blessed $table and $table->isa( 'Text::SimpleTable' ) ) {
    if ( not $table->isa('FirePHP::SimpleTable') ) {
      require FirePHP::SimpleTable;
      bless $table, 'FirePHP::SimpleTable';
    }
    $report = $table->draw;
  } elsif ( ref $table eq 'ARRAY' ) {
    $report = $table;
  } else {
    die "$table is neither an instance of Text::SimpleTable nor an array ref";
  }

  $self->send_headers(
    $self->format_message({ Type => 'TABLE' }, [ $label, $report ] )
  );
}


=head1 GROUPING METHODS

=head2 $self->start_group( $name )

Starts a new, collapsable logging group named C<$name>.
Nesting groups is entirly possible.

=cut

sub start_group {
  my ( $self, $label ) = @_;
  croak 'A group needs a label' unless $label;
  my $http = $self->http_headers
    or return;
  my $hdr = $self->next_message_header;
  push @{ $self->group_stack }, $self->message_index;
  my $msg = $self->format_message({ Type => 'GROUP_START', Label => $label });
  $http->header( $hdr => sprintf( '%d|%s|', length( $msg ),  $msg ) );
}


=head2 $self->dismiss_group

Dismisses the current group. In later versions this will most propable
delete contained messages. Right now just a warning is issued and the current
group is closed with C<end_group>.

=cut

sub dismiss_group {
  my $self = shift;
  my $current_group = ${ $self->group_stack }[ -1 ]
    or return;
  if ( $current_group < $self->message_index ) {
    carp "Dismissing a group with content is not implemented right now, " .
      "just closing it instead now";
    $self->end_group;
  } else {
    $self->rollback_last_message;
  }
  pop @{ $self->group_stack };
}


=head2 $self->end_group

Closes the current group and reenter the parent group if available.

=cut

sub end_group {
  my $self = shift;
  my $current_group = ${ $self->group_stack }[ -1 ]
    or die "no current group";
  my $http = $self->http_headers
    or return;
  my $hdr  = $self->next_message_header;
  my $msg  = $self->format_message({ Type => 'GROUP_END' });
  $http->header( $hdr => sprintf( '%d|%s|', length( $msg ),  $msg ) );
  pop @{ $self->group_stack };
}


=head2 $self->end_or_dismiss_group

Close the current group if it containes messages, otherwise just dismiss it.

=cut

sub end_or_dismiss_group {
  my $self = shift;
  my $current_group = ${ $self->group_stack }[ -1 ]
    or die "no current group";
  if ( $current_group < $self->message_index ) {
    $self->end_group;
  } else {
    $self->dismiss_group;
  }
}


=head1 INTERNAL METHODS

=head2 $self->format_message( $attr, $message )

Renders the message with the given attributs into a
message string that is understood by FirePHP. In
version 0.2 of the FirePHP protocol this means just
an ordered L<JSON> dump.

=cut

sub format_message {
  my ( $self, $attr, $message ) = @_;
  $self->json->objToJson( [ $attr, $message ] );
}


=head2 $self->next_message_header

Iterator for FirePHP headers. Calling it advances
the internal message cursor so ensure that you either
fill it or rollback the message.

Returns: the next header field name for messages

=cut

sub next_message_header {
  my $self = shift;
  return sprintf( "X-Wf-1-1-1-%d", ++$self->{message_index} );
}


=head2 $self->rollback_last_message

Rolls back the last message and decreases the message cursor.
This can be used to dismiss groups and delete recent messages
from the stack.

CAVEAT: currently doesn't work correctly for multi-part messages
that contain more than 5000 characters.

=cut

sub rollback_last_message {
  my $self = shift;
  my $http = $self->http_headers or return;
  return unless $self->{message_index};
  my $hdr = sprintf( "X-Wf-1-1-1-%d", $self->{message_index}-- );
  $http->remove_header( $hdr );
}


=head2 %headers = $self->build_message_headers( $message )

Builds the full header structure for the given message string
automatically splitting it into multipart messages when the
character limit of 5000 is reached. The message cursor will be
advanced accordingly.

Returns: a hash containing all HTTP headers representing the given message

=cut

sub build_message_headers {
  my ( $self, $message ) = @_;
  my $len = length $message;

  # split message into handable chunks
  my @parts = grep{$_} split /(.{5000})/, $message;

  my %headers;
  for ( 0 .. $#parts ) {
    $headers{ $self->next_message_header } =
      (!$_ ? $len : '') . '|' . $parts[$_] . '|' . ($_ < $#parts ? '\\' : '');
  }

  return %headers;
}


=head2 $self->send_headers( $message )

Just a small wrapper that builds and sends all headers for the given message.

=cut

sub send_headers {
  my ( $self, $message ) = @_;
  my $http = $self->http_headers or return;
  $http->header( $self->build_message_headers( $message ) );
}

1;

__END__


=head1 ACCESSORS

=head2 $self->http_headers

The bound L<HTTP::Headers> object

=head2 $self->message_index

The number of messages already send (actually the message header cursor,
you are responsible to ensure this is correct if you don't use the logging
or iterator functions provided by this class)

=head2 $self->stash

A hasref that can be used by clients to store information about this
logging session

=head2 $self->json

The C<JSON> parser in use to format messages

=head2 $self->group_stack

Internal stack used to track groups

=head1 DEVELOPER NOTES

=head2 PROTOCOL NOTES

Header:
  X-Wf-1-[ STRUCTURE TYPE INDEX ]-1-[ MESSAGE INDEX ]

Structure type index:
  1 - LOG ( and most others? )
  2 - DUMP


Content:
  [TOTAL LENGTH] \| \[ \{ [JSON MESSAGE PARAMS] \} \]

Json message params:
  Type: LOG|TRACE|EXCEPTION|TABLE|DUMP

=head1 SEE ALSO

L<http://www.firephp.org>, L<HTTP::Headers>

=head1 AUTHOR

Sebastian Willert, C<willert@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Sebastian Willert E<lt>willert@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

