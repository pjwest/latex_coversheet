######################################################################
=pod

=head1 z_coversheet.pl 

This file contains the main configuration for the Latex coversheet
package. 
Of particular importance this config file adds the coversheetid field 
to the document dataset to record the id of the coversheet used for
that document. It also adds the appropriate roles to control who
can modify the coversheet configuration.

This file also contains the utility routines 
prepare_latex_pdf and
cover_eprint_docs

=cut
######################################################################


# Bazaar Configuration

$c->{plugins}{"Convert::AddCoversheet"}{params}{disable} = 0;
$c->{plugins}{"Event::AddCoversheet"}{params}{disable} = 0;
$c->{plugins}{"Screen::Coversheet::Activate"}{params}{disable} = 0;
$c->{plugins}{"Screen::Coversheet::Deprecate"}{params}{disable} = 0;
$c->{plugins}{"Screen::Coversheet::Listing"}{params}{disable} = 0;
$c->{plugins}{"Screen::Coversheet::Edit"}{params}{disable} = 0;
$c->{plugins}{"Screen::Coversheet::View"}{params}{disable} = 0;
$c->{plugins}{"Screen::Coversheet::New"}{params}{disable} = 0;
$c->{plugins}{"Screen::Coversheet::Destroy"}{params}{disable} = 0;
$c->{plugins}{"Screen::EPMC::Coversheet"}{params}{disable} = 0;
$c->{plugins}{"Screen::Admin::ReApplyCoversheet"}{params}{disable} = 0;
$c->{plugins}{"Screen::Admin::ManageCoversheets"}{params}{disable} = 0;


$c->{executables}->{pdflatex} = "/usr/bin/pdflatex";
$c->{executables}->{pdftk} = "/usr/bin/pdftk";
$c->{gs_pdf_stich_cmd} = "gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile=";
#$c->{coversheet}->{stitch_tool} = "gs";   # "pdftk" or "gs"
$c->{coversheet}->{stitch_tool} = "pdftk";   # "pdftk" or "gs"

$c->{coversheet_log} = $c->{"var_path"}."/coversheet.log";
$c->{coversheet}->{preview_item} = 2;

# Stores the id of the Coversheet Dataobj that was used to generated the CS'ed document
push @{$c->{fields}->{document}},
        {
                name => 'coversheetid',
                type => 'int',
        };

# Where the coversheets are stored:
$c->{coversheet}->{path_suffix} = '/coversheets';
$c->{coversheet}->{path} = $c->{archiveroot}.'/cfg/static/coversheets';
$c->{coversheet}->{url} = $c->{base_url}.'/coversheets';

# Fields used for applying coversheets
$c->{license_application_fields} = [ "subjects", "type" ];

#new permissions for coversheet toolkit
$c->{roles}->{"coversheet-editor"} =
[
	"coversheet/destroy",
        "coversheet/write",
        "coversheet/activate",
        "coversheet/deprecate",
        "coversheet/preview",
        "coversheet/reapply",
];

push @{$c->{user_roles}->{editor}}, 'coversheet-editor';
push @{$c->{user_roles}->{admin}}, 'coversheet-editor';
push @{$c->{user_roles}->{local_admin}}, 'coversheet-editor';


######################################################################
=pod

=item prepare_latex_pdf( $repo, $coversheet_page, $file_path, $eprint, $doc, $temp_dir, $debug )

Reads the LaTeX file specfied in $file_path and applies the tag data
with data from the $eprint and the $doc.
The modified LaTeX code is written to a .tex file which is then converted
to a PDF file using pdflatex.
The pdf file is saved in the dir $temp_dir with the file name $coversheet_page
and file extension ".pdf"

If the debug flag is true then additional information is output to the
coversheet log file.

=cut
######################################################################

$c->{prepare_latex_pdf} = sub 
{
	my ( $repo, $coversheet_page, $file_path, $eprint, $doc, $temp_dir, $debug ) = @_;
	my $pdflatex = $repo->get_conf( "executables", "pdflatex" );

	my $content;
	open LTXFILE, $file_path || die ( "unable to open latex coversheet page $file_path" );
	while (<LTXFILE>) { $content .= $_; }
	close LTXFILE;
	EPrints::DataObj::Coversheet->log( $repo, "[prepare_latex_pdf] Got latex content [$content]" ) if $debug;

	return unless defined $content;

	my $tags = $repo->config( 'coversheet', 'tags' );
	foreach my $tag (keys %{$tags})
	{
		EPrints::DataObj::Coversheet->log( $repo, 
			"[prepare_latex_pdf] Attempt to replace [$tag] with [".&{$tags->{$tag}}( $eprint, $doc )."]" ) if $debug; 
		my $value = &{$tags->{$tag}}( $eprint, $doc );
		$content =~ s/\\#\\#$tag\\#\\#/$value/g;
	}

	EPrints::DataObj::Coversheet->log( $repo, "[prepare_latex_pdf] Updated latex content [$content]" ) if $debug;
	# write coverpage content to cover.tex
	my $latex_file = $temp_dir."/".$coversheet_page.".tex";
	if( !open( LATEX, '+>'.$latex_file ))
	{
		EPrints::DataObj::Coversheet->log( $repo, "[prepare_latex_pdf] Failed to create file $latex_file" );
		return;
	}
	print LATEX $content;
	close( LATEX );
	
	# attempt to create pdf cover page from the latex data
	system( $pdflatex, "-interaction=nonstopmode", "-output-directory=$temp_dir", $latex_file );

	# check it worked
	my $pdf_file = $temp_dir."/".$coversheet_page.".pdf";
	unless( -e $pdf_file )
	{
		EPrints::DataObj::Coversheet->log( $repo, "[prepare_latex_pdf] Could not generate $pdf_file. Check that coverpage content is valid LaTeX." );
		my $str;
		open LFILE, $temp_dir."/".$coversheet_page.".log" || die( "unable to open pdflatex log file to report errors");
		while (<LFILE>) { $str .= $_; } 
		close LFILE;
		EPrints::DataObj::Coversheet->log( $repo, "\n\npdflatex Log: $str\n\n");
		return;
	}

	EPrints::Utils::chown_for_eprints( $pdf_file );
	return;
};

######################################################################
=pod

=item cover_eprint_docs( $repo, $eprint, $plugin )

Tests each document owned by the EPrint item and if appropriate uses the
specified plugin to apply a coversheet to the document.

The document field coversheetid is updated with the id of the coversheet
used

=cut
######################################################################

$c->{cover_eprint_docs} = sub 
{
	my ( $repo, $eprint, $plugin, $new_only ) = @_;
	
	return 0 unless $eprint;
	my $covered = 0;
	foreach my $doc ( $eprint->get_all_documents ) 
	{
		my $is_thumbnail = 0;
		foreach my $rel ( @{$doc->get_value("relation") || []} )
		{
			$is_thumbnail++ if( $rel =~ /^is\w+ThumbnailVersionOf$/ );
		}
		next if $is_thumbnail;
		next if $doc->has_relation( undef, "isVolatileVersionOf" );
		next if $doc->has_relation( undef, "isCoversheetVersionOf" );
		my $filename = $doc->get_main;
		my $format = $doc->value( "format" ); # back compatibility
		my $mime_type = $doc->value( "mime_type" );
		next unless $filename;
		next unless( $format eq "application/pdf" || $mime_type eq "application/pdf" || $filename =~ /\.pdf$/i );

		# check whether there is an existing covered version and delete it
		my $coverdoc = EPrints::DataObj::Coversheet->get_coversheet_doc( $doc );
		next if $new_only && $coverdoc;

        	if( defined $coverdoc )
        	{
			my $current_cs_id = $doc->get_value( 'coversheetid' ) || -1; # coversheet used to cover document
			# remove existing covered version
                	$doc->get_eprint->set_under_construction( 1 );
                	$doc->remove_object_relations( $coverdoc ); # may not be required?
                	$coverdoc->remove();
			$doc->set_value( 'coversheetid', undef );
			$doc->commit();
                	$doc->get_eprint->set_under_construction( 0 );

			EPrints::DataObj::Coversheet->log( $repo, 
			"[AddCoversheet] Removed coversheet time[".EPrints::Time::get_iso_timestamp()."] ".
			"EPrint [".$eprint->get_id."] Document [".$doc->get_id."] Cover [".$current_cs_id."] \n" );
        	}

		my $coversheet = EPrints::DataObj::Coversheet->search_by_eprint( $repo, $eprint );
		next unless( defined $coversheet );

		# generate new covered version
		my $pages = $coversheet->get_pages;
                EPrints::DataObj::Coversheet->log( $repo, "[AddCoversheet] no coversheet pages defined [".$pages."]\n" ) unless $pages;
               	next unless $pages;
		$plugin->{_pages} = $pages;
 	
		my $newcoverdoc = $plugin->convert( $eprint, $doc, "application/pdf" );
               	EPrints::DataObj::Coversheet->log( $repo, "[AddCoversheet] Could not create coversheet document\n" ) unless $newcoverdoc;
		next unless $newcoverdoc;

		# add relation to new covered version
		$newcoverdoc->add_relation( $doc, "isCoversheetVersionOf" );

		$eprint->set_under_construction( 1 );

		$newcoverdoc->set_value( "security", $doc->get_value( "security" ) );
		$newcoverdoc->commit;
	
		# record which coversheet was used
		$doc->set_value( 'coversheetid', $coversheet->get_id );
		$doc->commit;
	
		$eprint->set_under_construction( 0 );
		$covered++;
               	EPrints::DataObj::Coversheet->log( $repo, 
			"[AddCoversheet] Applied coversheet time[".EPrints::Time::get_iso_timestamp()."] ".
			"EPrint [".$eprint->get_id."] Document [".$doc->get_id."] Cover [".$coversheet->get_id."] \n" );
	}

	return $covered;
};
