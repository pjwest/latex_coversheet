package EPrints::Plugin::Convert::AddCoversheet;

=pod

=head1 NAME

EPrints::Plugin::Convert::AddCoversheet - Prepend front and back coversheet sheets

=cut

use strict;
use warnings;
use encoding 'utf-8';

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
	$self->{visible} = "";

        unless( EPrints::Utils::require_if_exists('EPrints::OpenOfficeService') )
        {
                $self->{disable} = 1;
                return $self;
        }

        my $oosrv = EPrints::OpenOfficeService->new();
        unless( defined $oosrv && $oosrv->is_running() )
        {
                $self->{disable} = 1;
                return $self;
        }

	$self->{visible} = "all";

	if( defined $self->{session} )
	{
		# EPrints Services/sf2 - allow tags to be locally defined
		$self->{tags} = $self->{session}->config( 'coversheet', 'tags' );
	}

	return $self;
}

sub can_convert
{
	my ( $plugin, $doc ) = @_;

	# need Ghostscript and python
	return unless $plugin->get_repository->can_execute( "python" );
	return unless -e $plugin->get_repository->config( "executables", "uno_converter");

        my %types;

        # Get the main file name
        my $fn = $doc->get_main() or return ();
        
        if( $fn =~ /\.($EXTENSIONS_RE)$/oi )
        {
        	$types{"coverpage"} = { plugin => $plugin, };
        }
        
	return %types;
}

sub prepare_pages
{
	my ($self, $doc, $pages) = @_;
	my $eprint = $doc->get_eprint;
	my $temp_dir = File::Temp->newdir( "ep-coversheetXXXX", TMPDIR => 1 );

	my $session = $self->{session};

	foreach my $coversheet_page (keys %{$pages})
	{
		my $filetype = $pages->{$coversheet_page}->{type};
		my $file_path = $pages->{$coversheet_page}->{path};

		next if( $filetype eq 'none' );

		if ($filetype eq 'odt')
		{
			if ( EPrints::Utils::require_if_exists( "OpenOffice::OODoc" ) && $self->oo_is_running())
			{
				copy($file_path, "$temp_dir/$coversheet_page.odt");
				EPrints::Utils::chown_for_eprints( "$temp_dir/$coversheet_page.odt" );

				my $oodoc = OpenOffice::OODoc::odfDocument(file => "$temp_dir/$coversheet_page.odt");
				
				$self->{tags} = $self->{session}->config( 'coversheet', 'tags' );
				foreach my $tag (keys %{$self->{tags}})
				{
					eval
        				{
						my @list = $oodoc->selectElementsByContent( '##'.$tag.'##',  \&{$self->{tags}->{$tag}}, $eprint, $doc,  $oodoc );
					};

                                        if( $@ )
                                        {
                                                $session->log( "[Convert::AddCoversheet] OpenOffice::OODoc failed to insert tag '$tag' on the coversheet: '$@'" );
						next;
                                        }
				}
				my $cwd = getcwd; #a quirk of $oodoc->save is that it saves a temp file to the working directory.
				chdir $temp_dir;
				$oodoc->save();
				chdir $cwd;
				#end of search and replace

				#convert to pdf
				system(
						$session->config( 'executables', 'python' ),
						$session->config( 'executables', 'uno_converter' ),
						"$temp_dir/$coversheet_page.odt",
						"$temp_dir/$coversheet_page.pdf",
				      );

				#end of convert to pdf
				unlink "$temp_dir/$coversheet_page.odt";
			}

			unless( -e "$temp_dir/$coversheet_page.pdf" )
			{
				$session->log("[Convert::AddCoversheet] Failed to add coversheet to document '".$doc->get_id."'\n");
			}
		}
		elsif ($filetype eq 'pdf')
		{
			copy($file_path, $temp_dir . "/$coversheet_page.pdf");
		}
		else
		{
			$session->log("[Convert::AddCoversheet] Cannot handle coversheet of format '$filetype'\n");
		}
	}

	return $temp_dir;
}

sub export
{
	my ( $plugin, $target_dir, $doc, $type) = @_;

	my $pages = $plugin->{_pages};
	return unless( defined $pages );
	
	my $repository = $plugin->get_repository;

	# need Ghostscript and python
	return unless $repository->can_execute( "python" );
	return unless $repository->can_execute( "uno_converter" );

	my $temp_dir = $plugin->prepare_pages($doc, $pages);

	my $frontfile_path = $temp_dir . '/frontfile.pdf';
	my $backfile_path = $temp_dir . '/backfile.pdf';

	if ( ($pages->{frontfile}->{path} && ! -e $frontfile_path) || ($pages->{backfile}->{path} && ! -e $backfile_path) )
        {
                $repository->log( "[Convert::AddCoversheet] Unexpected absence of coversheet files." );
                return;
        }

        unless( -d $target_dir )
        {
                EPrints::Platform::mkdir( $target_dir);
        }

	my $output_file = EPrints::Platform::join_path( $target_dir, $doc->get_main );

	#my $output_file = $target_dir . '/' . $doc->get_main;
	if( -e $output_file )
	{
		# remove old covered file
		unlink( $output_file );
	}

	# EPrints Services/tmb 2011-08-26 get properly escaped filename via File dataobj
	#my $doc_path = $doc->local_path."/".$doc->get_main;
	my $doc_path = $doc->get_stored_file( $doc->get_main )->get_local_copy();

	my @input_files;
	push @input_files, $frontfile_path if( -e $frontfile_path );
	push @input_files, $doc_path;
	push @input_files, $backfile_path if( -e $backfile_path );

	my $temp_output_dir = File::Temp->newdir( "ep-coversheet-finishedXXXX", TMPDIR => 1 );
	my $temp_output_file = $temp_dir.'/temp.pdf';

	# EPrints Services/pjw Modification to use Ghostscript rather than pdftk 
	my $gs_cmd = $plugin->get_repository->get_conf( "gs_pdf_stich_cmd" );
	# add the output file
	$gs_cmd .= $temp_output_file;
	# add the input files
	foreach my $input_file (@input_files)
	{
		$gs_cmd .= " '$input_file'";
	}

	my $sys_call_status = system($gs_cmd);
	# check it worked
	if (0 == $sys_call_status)
	{
		copy($temp_output_file, $output_file);
	}
	else
        {
		my $eprint = $doc->get_eprint;
#               	$repository->mail_administrator( 'Plugin/Screen/Coversheet:email_subject', 
#                                                 'Plugin/Screen/Coversheet:email_body', 
#                                                 eprintid => $eprint->render_value("eprintid"),
#                                                 docid => $doc->render_value("docid") );

                $repository->log("[Convert::AddCoversheet] Ghostscript could not create '$output_file'. Check the PDF is not password-protected.");
                return;
        }

	EPrints::Utils::chown_for_eprints( $output_file );

	# return the filename without the abs. path
	return( $doc->get_main );
}


#will check to see if openoffice is running.
sub oo_is_running
{
	my( $self ) = @_;

        my $oosrv = EPrints::OpenOfficeService->new();

        return 0 unless( defined $oosrv && $oosrv->is_running() );
	return 1;
}

1;
