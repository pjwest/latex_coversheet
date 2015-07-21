package EPrints::Plugin::Convert::AddCoversheet;

=pod

=head1 NAME

EPrints::Plugin::Convert::AddCoversheet - Prepend front coversheet sheets

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
	$self->{visible} = "all";

	if( defined $self->{session} )
	{
		$self->{tags} = $self->{session}->config( 'coversheet', 'tags' );
	}

	return $self;
}

sub can_convert
{
	my ( $plugin, $doc ) = @_;

	# need Ghostscript and python
#	return unless $plugin->get_repository->can_execute( "python" );
#	return unless -e $plugin->get_repository->config( "executables", "uno_converter");

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
	my $repo = $self->{repository};
	my $eprint = $doc->get_eprint;
	my $temp_dir = File::Temp->newdir( "ep-coversheetXXXX", TMPDIR => 1 );
	if( !defined $temp_dir )
	{
		$repo->log( "[Convert::AddCoversheet] Failed to create dir $temp_dir" ) if $self->{_debug};
		return;
	}

	foreach my $coversheet_page (keys %{$pages})
	{
		my $filetype = $pages->{$coversheet_page}->{type};
		my $file_path = $pages->{$coversheet_page}->{path};

		next if( $filetype eq 'none' );

		if ($filetype eq 'ltx')
		{

print STDERR "get latex content\n";
			my $pdflatex = $repo->get_conf( "executables", "pdflatex" );

			my $content;
#if( $repo->can_call( "coverpage", "get_content" ) )
#{
#$content = $repo->call( [ "coverpage", "get_content" ], $repo, $doc->get_eprint, $doc );
#}

			open LTXFILE, $file_path || die ( "unable to open latex coversheet page $file_path" );
			while (<LTXFILE>) { $content .= $_; }
			close LTXFILE;
print STDERR "got latex content [$content]\n";

			return unless defined $content;

print STDERR "\n\n\n modify latex to content for tags \n";
			$self->{tags} = $self->{session}->config( 'coversheet', 'tags' );
			foreach my $tag (keys %{$self->{tags}})
			{
print STDERR "tag [$tag] content [".$self->{tags}->{$tag}."]\n"; 
print STDERR "attempt to replace [$tag] with [".&{$self->{tags}->{$tag}}( $eprint, $doc )."]\n"; 
				#my $latex_tag = "\\#\\#".$tag."\\#\\#";
				my $latex_tag = '\\'."#".$tag;
				my $value = &{$self->{tags}->{$tag}}( $eprint, $doc );
				$content =~ s/\\#\\#$tag\\#\\#/$value/g;
			}

print STDERR "\n\n\ngot  NEW latex content [$content]\n";
			# write coverpage content to cover.tex
			my $latex_file = $temp_dir."/".$coversheet_page.".tex";
			if( !open( LATEX, '+>'.$latex_file ))
			{
				$repo->log( "[CoverPDF] Failed to create file $latex_file" );
				return;
			}
			print LATEX $content;
			close( LATEX );

	
print STDERR "\n\n\n written latex to file [$temp_dir] [$latex_file] now convert to pdf \n";

			# attempt to create pdf cover page from the latex data
			system( $pdflatex, "-interaction=nonstopmode", "-output-directory=$temp_dir", $latex_file );

print STDERR " called pdflatex [$temp_dir]\n\n\n";

			# check it worked
			my $pdf_file = $temp_dir."/".$coversheet_page.".pdf";
			unless( -e $pdf_file )
			{
				$repo->log( "[Convert::AddCoversheet] Could not generate $pdf_file. Check that coverpage content is valid LaTeX." );
				my $str;
				open LFILE, $temp_dir."/".$coversheet_page.".log" || die( "unable to open pdflatex log file to report errors");
				while (<LFILE>) { $str .= $_; } 
				close LFILE;
				print STDERR "\n\npdflatex Log: $str\n\n";
				return;
			}

			EPrints::Utils::chown_for_eprints( $pdf_file );
		}
		elsif ($filetype eq 'pdf')
		{
			copy($file_path, $temp_dir . "/$coversheet_page.pdf");
		}
		else
		{
			$repo->log("[Convert::AddCoversheet] Cannot handle coversheet of format '$filetype'\n");
		}
	}

	return $temp_dir;
}

sub export
{
	my ( $plugin, $target_dir, $doc, $type) = @_;

	my $repo = $plugin->get_repository;
	$repo->log( "[Convert::AddCoversheet] export start\n" ) if $plugin->{_debug};
	my $pages = $plugin->{_pages};
	return unless( defined $pages );
	
	return unless $repo->can_execute( "pdflatex" );
	return unless $repo->can_execute( "pdftk" );

	my $pdftk = $repo->get_conf( "executables", "pdftk" );

	my $temp_dir = $plugin->prepare_pages($doc, $pages);
	return unless $temp_dir;

	my $frontfile_path = $temp_dir . '/frontfile.pdf';
	if ( ! -e $frontfile_path )
	{
                $repo->log( "[Convert::AddCoversheet] Unexpected absence of coversheet files." );
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
print STDERR " removed old output file [$output_file]\n";
	}

	# EPrints Services/tmb 2011-08-26 get properly escaped filename via File dataobj
	my $doc_path = $doc->get_stored_file( $doc->get_main )->get_local_copy();

	my $temp_output_file = $temp_dir.'/temp.pdf';

print STDERR "calling pdftk [$frontfile_path] [$doc_path] [$temp_output_file]\n";
	# prepend cover page
	my $sys_call_status = system( $pdftk, $frontfile_path, $doc_path, "cat", "output", $temp_output_file );

	# check it worked
	if (0 == $sys_call_status)
	{
print STDERR "copy [$temp_output_file] to[$output_file]\n";
		copy($temp_output_file, $output_file);
	}
	else
        {
                $repo->log("[Convert::AddCoversheet] pdftk could not create '$output_file'. Check the PDF is not password-protected. Call returned [".$sys_call_status."]\n");
                return;
        }

	EPrints::Utils::chown_for_eprints( $output_file );

	# return the filename without the abs. path
	return( $doc->get_main );
}

sub export_mostly_old
{
	my ( $plugin, $target_dir, $doc, $type) = @_;

	my $repo = $plugin->get_repository;
	$repo->log( "[Convert::AddCoversheet] export start\n" ) if $plugin->{_debug};
	my $pages = $plugin->{_pages};
	return unless( defined $pages );
	


print STDERR "get latex from phrase\n";
    my $content;
    if( $repo->can_call( "coverpage", "get_content" ) )
    {
        $content = $repo->call( [ "coverpage", "get_content" ], $repo, $doc->get_eprint, $doc );
    }
print STDERR "get latex content [$content]\n";
    return unless defined $content;


	my $temp_dir = $plugin->prepare_pages($doc, $pages);

	my $frontfile_path = $temp_dir . '/frontfile.pdf';

	if ( ! -e $frontfile_path )
        {
                $repo->log( "[Convert::AddCoversheet] Unexpected absence of coversheet files." );
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

	my $temp_output_dir = File::Temp->newdir( "ep-coversheet-finishedXXXX", TMPDIR => 1 );
	my $temp_output_file = $temp_dir.'/temp.pdf';

	# EPrints Services/pjw Modification to use Ghostscript rather than pdftk 
	my $gs_cmd = $repo->get_conf( "gs_pdf_stich_cmd" );
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
#               	$repo->mail_administrator( 'Plugin/Screen/Coversheet:email_subject', 
#                                                 'Plugin/Screen/Coversheet:email_body', 
#                                                 eprintid => $eprint->render_value("eprintid"),
#                                                 docid => $doc->render_value("docid") );

                $repo->log("[Convert::AddCoversheet] Ghostscript could not create '$output_file'. Check the PDF is not password-protected.");
                return;
        }

	EPrints::Utils::chown_for_eprints( $output_file );

	# return the filename without the abs. path
	return( $doc->get_main );
}



1;
