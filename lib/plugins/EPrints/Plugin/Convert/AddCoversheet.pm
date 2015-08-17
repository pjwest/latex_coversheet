package EPrints::Plugin::Convert::AddCoversheet;

=pod

=head1 NAME

EPrints::Plugin::Convert::AddCoversheet - Prepend front coversheet sheets

=cut

use strict;
use warnings;

use File::Copy;
use Cwd;
#use Encode qw(encode);

use EPrints::Plugin::Convert;
our @ISA = qw/ EPrints::Plugin::Convert /;

our (%FORMATS, @ORDERED, %FORMATS_PREF);
@ORDERED = %FORMATS = qw(
pdf application/pdf
);

# formats pref maps mime type to file suffix. Last suffix
# in the list is used.
for(my $i = 0; $i < @ORDERED; $i+=2)
{
         $FORMATS_PREF{$ORDERED[$i+1]} = $ORDERED[$i];
}

our $EXTENSIONS_RE = join '|', keys %FORMATS;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Coversheet Pages";
	$self->{visible} = "all";

	return $self;
}

sub can_convert
{
	my ( $plugin, $doc ) = @_;

        my %types;

        # Get the main file name
        my $fn = $doc->get_main() or return ();
        
        if( $fn =~ /\.($EXTENSIONS_RE)$/oi )
        {
        	$types{"coverpage"} = { plugin => $plugin, };
        }
        
	return %types;
}


######################################################################
=pod

=item prepare_pages( $self, $doc, $pages )

tests the coversheet pages obtained from the coversheet Dataobj and if
they are LaTeX files the y are converted to pdf files.
The process of converting to a pdf file also inserts the data for any tags
contained in the coversheet pages.

=cut
######################################################################

sub prepare_pages
{
	my ($self, $doc, $pages) = @_;
	my $repo = $self->{repository};
	my $eprint = $doc->get_eprint;
	my $temp_dir = File::Temp->newdir( "ep-coversheetXXXX", TMPDIR => 1 );
	if( !defined $temp_dir )
	{
		EPrints::DataObj::Coversheet->log( $repo, "[Convert::AddCoversheet] Failed to create dir $temp_dir" ) if $self->{_debug};
		return;
	}

	foreach my $coversheet_page (keys %{$pages})
	{
		my $filetype = $pages->{$coversheet_page}->{type};
		my $file_path = $pages->{$coversheet_page}->{path};

		next if( $filetype eq 'none' );

		if ($filetype eq 'ltx')
		{

			if( $repo->can_call( "prepare_latex_pdf" ) )
			{
				$repo->call( "prepare_latex_pdf", $repo, $coversheet_page, $file_path, $eprint, $doc, $temp_dir);
			}
			else
			{
				EPrints::DataObj::Coversheet->log( $repo, "[Convert::AddCoversheet] Cannot call prepare_latex_pdf\n");
			}

		}
		elsif ($filetype eq 'pdf')
		{
			copy($file_path, $temp_dir . "/$coversheet_page.pdf");
		}
		else
		{
			EPrints::DataObj::Coversheet->log( $repo, "[Convert::AddCoversheet] Cannot handle coversheet of format '$filetype'\n");
		}
	}

	return $temp_dir;
}


######################################################################
=pod

=item export( $plugin, $target_dir, $doc, $type )

This is called as part of the convert process.
It calls prepare_pages to obtain a pdf file to use as a front cover.
The tool pdftk or gs is then used to stitch the pdf front cover to
the doc supplied.
The resulting pdf documnet is stored in the $target_dir

=cut
######################################################################

sub export
{
	my ( $plugin, $target_dir, $doc, $type) = @_;

	my $repo = $plugin->get_repository;
	EPrints::DataObj::Coversheet->log( $repo, "[Convert::AddCoversheet] export start\n" ) if $plugin->{_debug};
	my $pages = $plugin->{_pages};
	return unless( defined $pages );
	
	return unless $repo->can_execute( "pdflatex" );

	my $temp_dir = $plugin->prepare_pages($doc, $pages);
	return unless $temp_dir;

	my $frontfile_path = $temp_dir . '/frontfile.pdf';
	if ( ! -e $frontfile_path )
	{
                EPrints::DataObj::Coversheet->log( $repo, "[Convert::AddCoversheet] Unexpected absence of coversheet files." );
                return;
        }

        unless( -d $target_dir )
        {
                EPrints::Platform::mkdir( $target_dir);
        }

	my $output_file = $target_dir."/".$doc->get_main;
	if( -e $output_file )
	{
		# remove old covered file
		unlink( $output_file );
	}

	# EPrints Services/tmb 2011-08-26 get properly escaped filename via File dataobj
	my $doc_path = $doc->get_stored_file( $doc->get_main )->get_local_copy();

	my $temp_output_file = $temp_dir.'/temp.pdf';

	my $sys_call_status;
	# prepend cover page
	if ( "pdftk" eq $repo->get_conf( "coversheet", "stitch_tool" ) )
	{
		my $pdftk = $repo->get_conf( "executables", "pdftk" );
		$sys_call_status = system( $pdftk, $frontfile_path, $doc_path, "cat", "output", $temp_output_file );
	}
	else
	{
		# prepend using GhostScript
		my $gs = $repo->get_conf( "executables", "gs" );
		my $gs_cmd = $repo->get_conf( "gs_pdf_stich_cmd" );
		# add the output file
		$gs_cmd .= $temp_output_file;
		# add the input files
		$gs_cmd .= " '$frontfile_path'" if $frontfile_path;
		$gs_cmd .= " '$doc_path'";
		$sys_call_status = system($gs_cmd);
	}

	# check it worked
	if (0 == $sys_call_status)
	{
		copy($temp_output_file, $output_file);
	}
	else
        {
                EPrints::DataObj::Coversheet->log( $repo, 
			"[Convert::AddCoversheet] ".
			$repo->get_conf( "coversheet", "stitch_tool" ).
			" could not create '$output_file'. ".
			"Check the PDF is not password-protected. Call returned [".$sys_call_status."]\n");
                return;
        }

	EPrints::Utils::chown_for_eprints( $output_file );

	# return the filename without the abs. path
	return( $doc->get_main );
}



1;
