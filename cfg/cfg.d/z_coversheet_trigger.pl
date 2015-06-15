
$c->add_trigger( EP_TRIGGER_DOC_URL_REWRITE, sub
{
	my( %args ) = @_;

	my( $request, $doc, $relations, $filename ) = @args{qw( request document relations filename )};
	return EP_TRIGGER_OK unless defined $doc;

	# check document is a pdf
	my $format = $doc->value( "format" ); # back compatibility
	my $mime_type = $doc->value( "mime_type" );
	return EP_TRIGGER_OK unless( $format eq "application/pdf" || $mime_type eq "application/pdf" || $filename =~ /\.pdf$/i );

	# ignore thumbnails e.g. http://.../8381/1.haspreviewThumbnailVersion/jacqueline-lane.pdf
	foreach my $rel ( @{$relations || []} )
	{
		return EP_TRIGGER_OK if( $rel =~ /^is\w+ThumbnailVersionOf$/ );
	}

	# ignore volatile documents
	return EP_TRIGGER_OK if $doc->has_relation( undef, "isVolatileVersionOf" );

	my $session = $doc->get_session;
	my $eprint = $doc->get_eprint;

	# search for a coversheet that can be applied to this document
	my $coversheet = EPrints::DataObj::Coversheet->search_by_eprint( $session, $eprint );
	return EP_TRIGGER_OK unless( defined $coversheet );

	my $regenerate = 1;

	# check whether there is an existing covered version and whether it needs to be regenerated
	my $current_cs_id = $doc->get_value( 'coversheetid' ) || -1; # coversheet used to cover document
	my $coverdoc; # existing covered version

	if( $coversheet->get_id == $current_cs_id )
	{
		# get the covered version of the document
		$coverdoc = $coversheet->get_coversheet_doc( $doc );

		# compare timestamps
		$regenerate = $coversheet->needs_regeneration( $doc, $coverdoc );
	}

	if( $regenerate )
	{
		# add job to event queue
		EPrints::DataObj::EventQueue->create_unique( $session, {
			unique => "TRUE",
			pluginid => "Event::AddCoversheet",
			action => 'generate',
			params => [
				$doc->internal_uri,
				$coversheet->internal_uri,
				( defined $coverdoc ? $coverdoc->internal_uri : undef )
			],
		});
	}

	if( defined $coverdoc )
	{
		# return the existing covered version
		$coverdoc->set_value( "security", $doc->get_value( "security" ) );
		$request->pnotes( filename => $coverdoc->get_main );
		$request->pnotes( document => $coverdoc );
		$request->pnotes( dataobj => $coverdoc );
	}

	# return the uncovered document

	return EP_TRIGGER_DONE;

}, priority => 100 );
