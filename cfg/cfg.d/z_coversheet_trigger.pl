# 
# Settings and trigger for the coversheet process
#

# flag to say whether a watermark is required
$c->{add_coversheet} = 1;

$c->add_trigger( EP_TRIGGER_DOC_URL_REWRITE, sub
{
	my( %args ) = @_;

print STDERR "EP_TRIGGER_DOC_URL_REWRITE\n";

	my( $request, $doc, $relations, $filename ) = @args{qw( request document relations filename )};
	return EP_TRIGGER_OK unless defined $doc;
	my $repo = $doc->repository;

	my $debug = 0;
        my $uri = URI::http->new( $request->unparsed_uri );
        my %request_args = $uri->query_form();

	if ($request_args{debug})
	{
		$debug = 1;
	}

	$repo->log( "[AddCoversheet] start add_coversheet[".$repo->config( "add_coversheet" )."]\n" ) if $debug;
	return EP_TRIGGER_OK unless $repo->config( "add_coversheet" );
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
	return EP_TRIGGER_OK if $doc->has_relation( undef, "isCoversheetVersionOf" );

	my $eprint = $doc->get_eprint;

	$repo->log( "[AddCoversheet] correct type of relation\n" ) if $debug;

	# search for a coversheet that can be applied to this document
	my $coversheet = EPrints::DataObj::Coversheet->search_by_eprint( $repo, $eprint );
	$repo->log( "[AddCoversheet] no coversheet found for item \n" ) if $debug && ! $coversheet;
	return EP_TRIGGER_OK unless( defined $coversheet );

	$repo->log( "[AddCoversheet] request is for a pdf and there is a coversheet to apply id[".$coversheet->get_id()."]\n" ) if $debug;

	my $regenerate = 1;

	# check whether there is an existing covered version and whether it needs to be regenerated
	my $current_cs_id = $doc->get_value( 'coversheetid' ) || -1; # coversheet used to cover document
	# get the existing covered version of the document
	my $coverdoc = $coversheet->get_coversheet_doc( $doc );

	if( $coversheet->get_id == $current_cs_id )
	{
		# compare timestamps
		$regenerate = $coversheet->needs_regeneration( $doc, $coverdoc );
	}

	$repo->log( "[AddCoversheet] need to regenerate the cover [".$regenerate."]\n" ) if $debug;
	if( $regenerate || $debug )
	{

        	if( defined $coverdoc )
        	{
			$repo->log( "[AddCoversheet] remove old cover [".$coverdoc->get_id()."]\n" ) if $debug;
			# remove existing covered version
                	$doc->get_eprint->set_under_construction( 1 );
                	$doc->remove_object_relations( $coverdoc ); # may not be required?
                	$coverdoc->remove();
                	$doc->get_eprint->set_under_construction( 0 );
        	}

		# generate new covered version
        	my $plugin = $repo->plugin( "Convert::AddCoversheet" );
		unless( defined $plugin )
        	{
                	$repo->log( "[AddCoversheet] Could not load Convert::AddCoversheet plugin\n" );
			return EP_TRIGGER_OK;
        	}

		my $pages = $coversheet->get_pages;
                $repo->log( "[AddCoversheet] no coversheet pages defined [".$pages."]\n" ) unless $pages;
               	return EP_TRIGGER_OK unless $pages;
		$plugin->{_pages} = $pages;
		$plugin->{_debug} = $debug;
 	
		my $newcoverdoc = $plugin->convert( $doc->get_eprint, $doc, "application/pdf" );
		unless( defined $newcoverdoc )
        	{
                	$repo->log( "[AddCoversheet] Could not create coversheet document\n" );
                	return EP_TRIGGER_OK;
        	}

		# add relation to new covered version
		$newcoverdoc->add_relation( $doc, "isCoversheetVersionOf" );

		$doc->get_eprint->set_under_construction( 1 );

		$newcoverdoc->set_value( "security", $doc->get_value( "security" ) );
		$newcoverdoc->commit;
	
		# record which coversheet was used
		$doc->set_value( 'coversheetid', $coversheet->get_id );
		$doc->commit;
	
		$doc->get_eprint->set_under_construction( 0 );
		$coverdoc = $newcoverdoc;
	}

	if( defined $coverdoc )
	{
		$repo->log( "[AddCoversheet] got covered version doc id[".$coverdoc->get_id."] \n" ) if $debug;
		# return the covered version
		$coverdoc->set_value( "security", $doc->get_value( "security" ) );
		$request->pnotes( filename => $coverdoc->get_main );
		$request->pnotes( document => $coverdoc );
		$request->pnotes( dataobj => $coverdoc );
	}

	# return the uncovered document
	$repo->log( "[AddCoversheet] finished \n" ) if $debug;

	return EP_TRIGGER_DONE;

}, priority => 100 );


