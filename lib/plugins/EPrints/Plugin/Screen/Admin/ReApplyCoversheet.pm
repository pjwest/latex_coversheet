=head1 NAME

EPrints::Plugin::Screen::Admin::ReApplyCoversheet

=cut

package EPrints::Plugin::Screen::Admin::ReApplyCoversheet;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{ 
			place => "admin_actions_system", 
			position => 1275, 
		},
	];
	$self->{actions} = [qw/ cover cancel /]; 
	$self->{cover_limit} = 1;

	return $self;
}

sub allow_cancel
{
	my( $self ) = @_;
        return 1;
}

sub action_cancel
{
        my( $self ) = @_;

        $self->{processor}->{screenid} = "Admin";
}
sub allow_cover
{
	my( $self ) = @_;

	return $self->allow( "coversheet/reapply" );
}

sub action_cover
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $ds = $repo->dataset( "eprint" );

	my $entered_ids = $repo->param( "epids_input" );

	unless( EPrints::Utils::is_set( $entered_ids ) )
	{
		$self->{processor}->add_message(
			"warning",
			$self->html_phrase( "no_ids" ) );
		return;
	}
	my @raw_ids = split(",", $entered_ids); 
	my @ids = ();
	foreach my $id ( @raw_ids ) 
	{
		$id =~ s/^\s+//g;
		$id =~ s/\s+$//g;
		my $item = $ds->dataobj( $id );
		if ( $item )
		{
			push @ids, $id;
		}
	}

	unless ( scalar @ids )
	{
		$self->{processor}->add_message(
			"warning",
			$self->html_phrase( "no_valid_ids" ) );
		return;
	}
	if ( scalar @ids > $self->{cover_limit} )
	{
		@ids = splice @ids, 0, $self->{send_limit};

		$self->{processor}->add_message(
			"warning",
			$self->html_phrase( "too_many_ids", limit=>$xml->create_text_node( $self->{cover_limit} ) ) );
	}

       	my $plugin = $repo->plugin( "Convert::AddCoversheet" );
	unless( defined $plugin )
       	{
               	$self->{processor}->add_message(
                        "warning",
                        $self->html_phrase( "no_plugin" ) ); 
		return;
       	}

	my @covered_ids = ();
	foreach my $id ( @ids ) 
	{
		my $item = $ds->dataobj( $id );
		if ( $item )
		{
			my $covered = $repo->call( "cover_eprint_docs" , $repo, $item, $plugin );
			push @covered_ids, $id if $covered;
		}
	}

	$self->{processor}->add_message(
		"message",
		$self->html_phrase( "covered", 
				items => $xml->create_text_node( join(", ", @covered_ids ) ) ) );
	
	return;
}	

sub render
{
        my( $self ) = @_;

        my $repo = $self->{repository};

	my $entered_ids = $repo->param( "epids_input" );

	my $xml = $repo->xml;
        my $page = $xml->create_element( "div", class=>"ep_block" );

        $page->appendChild( $self->html_phrase( "blurb", limit=>$xml->create_text_node( $self->{cover_limit} ) ) );

        my %buttons = (
                cancel => $self->phrase( "action:cancel:title" ),
                cover => $self->phrase( "action:cover:title" ),
                _order => [ "cover", "cancel" ]
        );

        my $form = $repo->render_form( "GET" );
        $form->appendChild( $repo->render_hidden_field ( "screen", "Admin::ReApplyCoversheet" ) );

        my $div = $xml->create_element( "div", style=>"margin-bottom: 1em" );
        $div->appendChild( $self->html_phrase( "input" ) );
        $div->appendChild(
                $xml->create_element(
                        "input",
                        "maxlength"=>"255",
                        "name"=>"epids_input",
			"value" => $entered_ids,
                        "id"=>"epids_input",
                        "class"=>"ep_form_text",
                        "size"=>"40", ));
        $form->appendChild( $div );
        $form->appendChild( $repo->render_action_buttons( %buttons ) );

        $page->appendChild( $form );

        return( $page );
}


1;


