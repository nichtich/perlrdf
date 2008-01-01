# RDF::Trice::Iterator::Bindings
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trice::Iterator::Bindings - Stream (iterator) class for bindings query results.

=head1 SYNOPSIS

    use RDF::Trice::Iterator;
    my $query	= RDF::Query->new( '...query...' );
    my $stream	= $query->execute();
    while (my $row = $stream->next) {
    	my @vars	= @$row;
    	# do something with @vars
    }

=head1 METHODS

=over 4

=cut

package RDF::Trice::Iterator::Bindings;

use strict;
use warnings;
use Data::Dumper;

use JSON 2.0;
use Scalar::Util qw(reftype);

use RDF::Trice::Iterator qw(smap);
use base qw(RDF::Trice::Iterator);

our ($REVISION, $VERSION, $debug);
use constant DEBUG	=> 0;
BEGIN {
	$debug		= DEBUG;
	$REVISION	= do { my $REV = (qw$Revision: 293 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
	$VERSION	= '1.000';
}

=item C<new ( \@results, \@names, %args )>

=item C<new ( \&results, \@names, %args )>

Returns a new SPARQL Result interator object. Results must be either
an reference to an array containing results or a CODE reference that
acts as an iterator, returning successive items when called, and
returning undef when the iterator is exhausted.

$type should be one of: bindings, boolean, graph.

=cut

sub new {
	my $class	= shift;
	my $stream	= shift || sub { undef };
	my $names	= shift || [];
	Carp::confess unless (scalar(@_) % 2 == 0);
	my %args	= @_;
	
	my $type	= 'bindings';
	my $self	= $class->SUPER::new( $stream, $type, $names, %args );
	
	my $s 	= $args{ sorted_by } || [];
	Carp::confess unless (reftype($s) eq 'ARRAY');
	$self->{sorted_by}	= $s;
	return $self;
}

sub _new {
	my $class	= shift;
	my $stream	= shift;
	my $type	= shift;
	my $names	= shift;
	my %args	= @_;
	return $class->new( $stream, $names, %args );
}

=item C<< project ( @columns ) >>

Returns a new stream that projects the current bindings to only the given columns.

=cut

sub project {
	my $self	= shift;
	my $class	= ref($self);
	my @proj	= @_;
	
	my $sub		= sub {
		my $row	= $self->next;
		return unless ($row);
		my $p	= { map { $_ => $row->{ $_ } } @proj };
		return $p;
	};
	
	my $args	= $self->_args();
	my $proj	= $class->new( $sub, [@proj], %$args );
	return $proj;
}

=item C<join_streams ( $stream, $stream, $bridge )>

Performs a natural, nested loop join of the two streams, returning a new stream
of joined results.

=cut

sub join_streams {
	my $self	= shift;
	my $a		= shift;
	my $b		= shift;
	my $bridge	= shift;
	my %args	= @_;
	
#	my $debug	= $args{debug};
	
	Carp::confess unless ($a->isa('RDF::Trice::Iterator::Bindings'));
	Carp::confess unless ($b->isa('RDF::Trice::Iterator::Bindings'));
	
	my @join_sorted_by;
	if (my $o = $args{ orderby }) {
		my $req_sort	= join(',', map { $_->[1]->name => $_->[0] } @$o);
		my $a_sort		= join(',', $a->sorted_by);
		my $b_sort		= join(',', $b->sorted_by);
		
		if (DEBUG) {
			warn '---------------------------';
			warn 'REQUESTED SORT in JOIN: ' . Dumper($req_sort);
			warn 'JOIN STREAM SORTED BY: ' . Dumper($a_sort);
			warn 'JOIN STREAM SORTED BY: ' . Dumper($b_sort);
		}
		my $actual_sort;
		if (substr( $a_sort, 0, length($req_sort) ) eq $req_sort) {
			warn "first stream is already sorted. using it in the outer loop.\n" if (DEBUG);
		} elsif (substr( $b_sort, 0, length($req_sort) ) eq $req_sort) {
			warn "second stream is already sorted. using it in the outer loop.\n" if (DEBUG);
			($a,$b)	= ($b,$a);
		} else {
			my $a_common	= join('!', $a_sort, $req_sort);
			my $b_common	= join('!', $b_sort, $req_sort);
			if ($a_common =~ qr[^([^!]+)[^!]*!\1]) {	# shared prefix between $a_sort and $req_sort?
				warn "first stream is closely sorted ($1).\n" if (DEBUG);
			} elsif ($b_common =~ qr[^([^!]+)[^!]*!\1]) {	# shared prefix between $b_sort and $req_sort?
				warn "second stream is closely sorted ($1).\n" if (DEBUG);
				($a,$b)	= ($b,$a);
			}
		}
		@join_sorted_by	= ($a->sorted_by, $b->sorted_by);
	}
	
	my $stream	= $self->SUPER::join_streams( $a, $b, $bridge, %args );
	warn "JOINED stream is sorted by: " . join(',', @join_sorted_by) . "\n" if (DEBUG);
	$stream->{sorted_by}	= \@join_sorted_by;
	return $stream;
}

=item C<< next_result >>

Returns the next binding result.

=cut

sub next_result {
	my $self	= shift;
	my $data	= $self->SUPER::next_result();
	if (defined($data)) {
		Carp::confess "not a HASH ref" unless (reftype($data) eq 'HASH');
	}
	return $data;
}

=item C<< sorted_by >>

=cut

sub sorted_by {
	my $self	= shift;
	my $sorted	= $self->{sorted_by};
	return @$sorted;
}

=item C<< binding_value_by_name ( $name ) >>

Returns the binding of the named variable in the current result.

=cut

sub binding_value_by_name {
	my $self	= shift;
	my $name	= shift;
	my $row		= ($self->open) ? $self->current : $self->next;
	if (exists( $row->{ $name } )) {
		return $row->{ $name };
	} else {
		warn "No variable named '$name' is present in query results.\n";
	}
}

=item C<< binding_value ( $i ) >>

Returns the binding of the $i-th variable in the current result.

=cut

sub binding_value {
	my $self	= shift;
	my $val		= shift;
	my @names	= $self->binding_names;
	return $self->binding_value_by_name( $names[ $val ] );
}


=item C<binding_values>

Returns a list of the binding values from the current result.

=cut

sub binding_values {
	my $self	= shift;
	my $row		= ($self->open) ? $self->current : $self->next;
	return @{ $row }{ $self->binding_names };
}


=item C<binding_names>

Returns a list of the binding names.

=cut

sub binding_names {
	my $self	= shift;
	my $names	= $self->{_names};
	return @$names;
}

=item C<binding_name ( $i )>

Returns the name of the $i-th result column.

=cut

sub binding_name {
	my $self	= shift;
	my $val		= shift;
	my $names	= $self->{_names};
	return $names->[ $val ];
}


=item C<bindings_count>

Returns the number of variable bindings in the current result.

=cut

sub bindings_count {
	my $self	= shift;
	my $names	= $self->{_names};
	my $row		= ($self->open) ? $self->current : $self->next;
	return scalar( @$names ) if (scalar(@$names));
	return 0 unless ref($row);
	return scalar( @{ [ keys %$row ] } );
}

=item C<is_bindings>

Returns true if the underlying result is a set of variable bindings.

=cut

sub is_bindings {
	my $self			= shift;
	return 1;
}

=item C<as_json ( $max_size )>

Returns a JSON serialization of the stream data.

=cut

sub as_json {
	my $self			= shift;
	my $max_result_size	= shift || 0;
	my $width			= $self->bindings_count;
	my $bridge			= $self->bridge;
	
	my @variables;
	for (my $i=0; $i < $width; $i++) {
		my $name	= $self->binding_name($i);
		push(@variables, $name) if $name;
	}
	
	my $count	= 0;
	my $parsed	= $bridge->parsed;
	my $order	= ref($parsed->{options}{orderby}) ? JSON::true : JSON::false;
	my $dist	= $parsed->{options}{distinct} ? JSON::true : JSON::false;
	
	my $data	= {
					head	=> { vars => \@variables },
					results	=> { ordered => $order, distinct => $dist },
				};
	my @bindings;
	while (!$self->finished) {
		my %row;
		for (my $i = 0; $i < $width; $i++) {
			my $name		= $self->binding_name($i);
			my $value		= $self->binding_value($i);
			if (my ($k, $v) = format_node_json($bridge, $value, $name)) {
				$row{ $k }		= $v;
			}
		}
		
		push(@{ $data->{results}{bindings} }, \%row);
		last if ($max_result_size and ++$count >= $max_result_size);
	} continue { $self->next_result }
	
	return to_json( $data );
}

=item C<as_xml ( $max_size )>

Returns an XML serialization of the stream data.

=cut

sub as_xml {
	my $self			= shift;
	my $max_result_size	= shift || 0;
	my $width			= $self->bindings_count;
	my $bridge			= $self->bridge;
	
	my @variables;
	for (my $i=0; $i < $width; $i++) {
		my $name	= $self->binding_name($i);
		push(@variables, $name) if $name;
	}
	
	my $count	= 0;
	my $t	= join("\n\t", map { qq(<variable name="$_"/>) } @variables);
	my $xml	= <<"END";
<?xml version="1.0"?>
<sparql xmlns="http://www.w3.org/2001/sw/DataAccess/rf1/result2">
<head>
	${t}
</head>
<results>
END
	while (!$self->finished) {
		my @row;
		$xml	.= "\t\t<result>\n";
		for (my $i = 0; $i < $width; $i++) {
			my $name		= $self->binding_name($i);
			my $value		= $self->binding_value($i);
			$xml	.= "\t\t\t" . $self->format_node_xml($bridge, $value, $name) . "\n";
		}
		$xml	.= "\t\t</result>\n";
		
		last if ($max_result_size and ++$count >= $max_result_size);
	} continue { $self->next_result }
	$xml	.= <<"EOT";
</results>
</sparql>
EOT
	return $xml;
}

=begin private

=item C<format_node_json ( $node, $name )>

Returns a string representation of C<$node> for use in a JSON serialization.

=end private

=cut

sub format_node_json ($$$) {
	my $bridge	= shift;
	return undef unless ($bridge);
	
	my $node	= shift;
	my $name	= shift;
	my $node_label;
	
	if(!defined $node) {
		return;
	} elsif ($bridge->is_resource($node)) {
		$node_label	= $bridge->uri_value( $node );
		return $name => { type => 'uri', value => $node_label };
	} elsif ($bridge->is_literal($node)) {
		$node_label	= $bridge->literal_value( $node );
		return $name => { type => 'literal', value => $node_label };
	} elsif ($bridge->is_blank($node)) {
		$node_label	= $bridge->blank_identifier( $node );
		return $name => { type => 'bnode', value => $node_label };
	} else {
		return;
	}
}

=item C<< construct_args >>

Returns the arguments necessary to pass to the stream constructor _new
to re-create this stream (assuming the same closure as the first
argument).

=cut

sub construct_args {
	my $self	= shift;
	my $type	= $self->type;
	my @names	= $self->binding_names;
	my $args	= $self->_args || {};
	return ($type, \@names, %{ $args });
}


1;

__END__

=back

=head1 DEPENDENCIES

L<JSON|JSON>

L<Scalar::Util|Scalar::Util>


=head1 AUTHOR

Gregory Todd Williams  C<< <greg@evilfunhouse.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Gregory Todd Williams C<< <gwilliams@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

