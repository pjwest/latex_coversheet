=head1 NAME

EPrints::Plugin::Screen::Coversheet::View

=cut

package EPrints::Plugin::Screen::Coversheet::View;

@ISA = ( 'EPrints::Plugin::Screen::Workflow' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_view.png";

	$self->{appears} = [
		{
			place => "coversheet_actions",
			position => 250,
		},
	];

	$self->{actions} = [qw/ /];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

        my $ds = $self->{processor}->{dataset}; # set by Coversheet::Listing

	if( defined $ds && $ds->base_id eq 'coversheet' )
	{
		return $self->allow( "coversheet/preview" ) 
	}
	return 0;
}


sub render_title
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my $screen = $self->view_screen();

	my $dataset = $self->{processor}->{dataset};
	my $dataobj = $self->{processor}->{dataobj};

	my $listing;
	my $priv = $dataset->id . "/preview";
	if( $self->EPrints::Plugin::Screen::allow( $priv ) )
	{
		my $url = URI->new( $repo->current_url );
		$url->query_form(
			screen => "Coversheet::Listing",
			dataset => $dataset->id
		);
		$listing = $repo->render_link( $url );
		$listing->appendChild( $dataset->render_name( $repo ) );
	}
	else
	{
		$listing = $dataset->render_name( $repo );
	}

	my $desc = $dataobj->render_description();

	return $self->html_phrase( "page_title",
		listing => $listing,
		desc => $desc,
	);
}

sub render
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $dataset = $self->{processor}->{dataset};
	my $dataobj = $self->{processor}->{dataobj};

	my $frag = $repo->make_doc_fragment;

	
	$frag->appendChild( $self->render_links );
	$frag->appendChild( $dataobj->render_citation( "details" ) );

	return $frag;
}

sub render_links
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $dataset = $self->{processor}->{dataset};
	my $dataobj = $self->{processor}->{dataobj};

	my $frag = $repo->make_doc_fragment;
	my $h2 = $frag->appendChild( $repo->xml->create_element( "h2" ) );
	$h2->appendChild( $repo->html_phrase ( "coversheet_fieldname_frontfile" ) );

	my $latex_file = "frontfile.ltx";
	my $preview_file = "preview.pdf";
        my $latex_path = $dataobj->get_path() . '/' . $latex_file;
        my $preview_path = $dataobj->get_path() . '/' . $preview_file;
	if ( -e $latex_path )
	{
 		my $cs_url = $repo->config( 'coversheet', 'url' ) . '/' . $dataobj->get_id . '/' . $latex_file;

		my $link = $repo->render_link( $cs_url );
		$link->appendChild( $repo->make_text( $cs_url ) );
		my $plink = $repo->make_doc_fragment;
		# attempt to create a new preview.
		unlink ( $preview_path ) if ( -e $preview_path );
		my $preview_item_id = $repo->config( 'coversheet', 'preview_item' );
		my $dataset = $repo->dataset( "archive" );
		my $preview_item = $dataset->dataobj( $preview_item_id );
		my @docs = $preview_item->get_all_documents() if $preview_item;
		my $preview_doc = $docs[0] if @docs;
                if( $repo->can_call( "prepare_latex_pdf" ) && $preview_item && $preview_doc )
                {
			my $temp_dir = File::Temp->newdir( "ep-coversheetXXXX", TMPDIR => 1 );
                        $repo->call( "prepare_latex_pdf", $repo, "frontfile", $latex_path, $preview_item, $preview_doc, $temp_dir);
        		my $frontfile_path = $temp_dir . '/frontfile.pdf'; 
        		if ( ! -e $frontfile_path )
        		{
				EPrints::DataObj::Coversheet->log( $repo, 
					"[Convert::AddCoversheet] Unexpected absence of coversheet pdf file." );
			}       
			else
			{
				use File::Copy;
				copy($frontfile_path, $preview_path);
				EPrints::Utils::chown_for_eprints( $preview_path );
			}
		}
		else
		{
			EPrints::DataObj::Coversheet->log( $repo, "[Convert::AddCoversheet] Cannot call prepare_latex_pdf\n");
		}

		if ( -e $preview_path )
		{
 			my $preview = $repo->config( 'coversheet', 'url' ) . '/' . $dataobj->get_id . '/' . $preview_file;
			$plink = $repo->render_link( $preview );
			$plink->appendChild( $repo->make_text( $preview ) );
		}
		else
		{
			$plink =  $self->html_phrase( "no_preview" );
		}
		$frag->appendChild( $self->html_phrase( "page_detail", l_url=>$link, p_url=>$plink ) );
	}
	return $frag;
}


1;


