package FirePHP::Example::Catalyst;

use strict;
use warnings;

use Catalyst::Runtime '5.70';

=head1 NAME

FirePHP::Example::Catalyst - FirePHP example application

=head1 SYNOPSIS

    bin/start_server.pl

=cut

use parent qw/Catalyst/;
use Catalyst qw/Static::Simple FirePHP/;

our $VERSION = '0.01';

__PACKAGE__->config(
  name => 'FirePHP::Example::Catalyst',
  FirePHP => { action_grouping => 1, compact => 1 }
);
__PACKAGE__->setup();

1;

__END__


=head1 SEE ALSO

L<FirePHP::Dispatcher>, L<Catalyst>, L<Catalyst::Log::Log4perl>

=head1 AUTHOR

Sebastian Willert, C<willert@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Sebastian Willert E<lt>willert@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
