package FirePHP::LogConnector::Null;

=pod

=head1 NAME

FirePHP::LogConnector::Null

=head1 DESCRIPTION

B<FirePHP::LogConnector::Null> represents an unconnected
connector. This will be useful to streamline the usage
of FirePHP but is just a stub right now.

=cut

use strict;
use warnings;

use base qw/FirePHP::LogConnector/;

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
