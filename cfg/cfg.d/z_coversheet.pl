
# Bazaar Configuration

$c->{plugins}{"Convert::AddCoversheet"}{params}{disable} = 0;
$c->{plugins}{"Event::AddCoversheet"}{params}{disable} = 0;
$c->{plugins}{"Screen::Coversheet::Activate"}{params}{disable} = 0;
$c->{plugins}{"Screen::Coversheet::Deprecate"}{params}{disable} = 0;
$c->{plugins}{"Screen::Coversheet::Edit"}{params}{disable} = 0;
$c->{plugins}{"Screen::Coversheet::New"}{params}{disable} = 0;
$c->{plugins}{"Screen::EPMC::Coversheet"}{params}{disable} = 0;
$c->{plugins}{"Screen::Admin::ReApplyCoversheet"}{params}{disable} = 0;


$c->{executables}->{pdflatex} = "/usr/bin/pdflatex";
$c->{executables}->{pdftk} = "/usr/bin/pdftk";

my $coverpage = {};
$c->{coverpage} = $coverpage;

# phrase file used to specify coverpage content
$coverpage->{phrase_file} = $c->{archiveroot}."/cfg/lang/en/phrases/coverpage.xml";

# return coverpage content in the form of a LaTeX document
$coverpage->{get_content} = sub {

    my ( $session, $eprint, $doc ) = @_;
print STDERR "coverpage {get_content} called doc_type[".$doc->get_type."] status[".$eprint->get_value( "eprint_status" )."] \n";

#    return unless $doc->get_type eq "application/pdf";
 #   return unless $eprint->get_value( "eprint_status" ) eq "archive";

    my %bits = (
        citation => EPrints::Utils::tree_to_utf8( $eprint->render_citation() ),
        url => $eprint->get_url,
    );

    return $session->phrase( "coverpage:general", %bits );
};




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

# Ghostscript command to stitch the pdfs
$c->{gs_pdf_stich_cmd} = "gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile=";

# Fields used for applying coversheets
$c->{license_application_fields} = [ "type" ];

#new permissions for coversheet toolkit
$c->{roles}->{"coversheet-editor"} =
[
	"coversheet/destroy",
        "coversheet/write",
        "coversheet/activate",
        "coversheet/deprecate",
        "coversheet/view",
        "coversheet/reapply",
];

push @{$c->{user_roles}->{editor}}, 'coversheet-editor';
push @{$c->{user_roles}->{admin}}, 'coversheet-editor';
push @{$c->{user_roles}->{local_admin}}, 'coversheet-editor';

# Tags may be defined locally, see Plugin/Convert/AddCoversheet.pm
# $c->{coversheet}->{tags} = {};

