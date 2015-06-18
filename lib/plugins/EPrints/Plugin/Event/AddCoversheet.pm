package EPrints::Plugin::Event::AddCoversheet;

use EPrints::Plugin::Event;
@ISA = qw( EPrints::Plugin::Event );

sub generate
{
	my( $self, $doc, $coversheet, $coverdoc ) = @_;

	# check we still need to generate a covered version
	my $current_cs_id = $doc->get_value( 'coversheetid');
 	if( defined $current_cs_id && $current_cs_id == $coversheet->get_id )
	{
		# do not pass our current coverdoc obj to the regeneration test as
		# this could be an old one that has been superseded by a previous
		# invocation of this event. 
		return unless $coversheet->needs_regeneration( $doc, undef );
	}

        if( defined $coverdoc )
        {
		# remove existing covered version
                $doc->get_eprint->set_under_construction( 1 );
                $doc->remove_object_relations( $coverdoc ); # may not be required?
                $coverdoc->remove();
                $doc->get_eprint->set_under_construction( 0 );
        }

	my $session = $self->{session};

	# generate new covered version
        my $plugin = $session->plugin( "Convert::AddCoversheet" );
        unless( defined $plugin )
        {
                $session->log( "[Event::AddCoversheet] Couldn't load Convert::AddCoversheet plugin\n" );
		return EPrints::Const::HTTP_NOT_FOUND;
        }

	my $pages = $coversheet->get_pages || return;
	$plugin->{_pages} = $pages;
 
	my $newcoverdoc = $plugin->convert( $doc->get_eprint, $doc, "application/pdf" );
	unless( defined $newcoverdoc )
        {
                $session->get_repository->log( "[Event::AddCoversheet] Couldn't create coversheet document\n" );
                return EPrints::Const::HTTP_NOT_FOUND;
        }

	# add relation to new covered version
	$newcoverdoc->add_relation( $doc, "isCoversheetVersionOf" );

	$doc->get_eprint->set_under_construction( 1 );

	# http://servicesjira.eprints.org:8080/browse/BATH-62
	# add the correct security setting
	# when the security setting changes on the original document, this will change the eprint.lastmod
	# which will generate a new coversheet
	$newcoverdoc->set_value( "security", $doc->get_value( "security" ) );
	$newcoverdoc->commit;
	
	# record which coversheet was used
	$doc->set_value( 'coversheetid', $coversheet->get_id );
	$doc->commit;
	
	$doc->get_eprint->set_under_construction( 0 );

	return;
}

1;
