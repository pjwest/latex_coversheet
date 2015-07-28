package EPrints::Plugin::Screen::Coversheet::Activate;

our @ISA = ( 'EPrints::Plugin::Screen::Workflow' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_approve.png";

	$self->{appears} = [
                {       # Coversheet::Listing
                        place => "coversheet_actions",
                        position => 400,
                },
	];
	
	$self->{actions} = [qw/ activate cancel /];

	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

        my $ds = $self->{processor}->{dataset}; # set by Coversheet::Listing

        if( defined $ds && $ds->base_id eq 'coversheet' )
        {
		if( defined $self->{processor}->{dataobj} && $self->{processor}->{dataobj}->get_value('status') eq 'active' )
		{
			return 0;
		}
                return $self->allow( "coversheet/activate" );
        }
	return 0;
}

sub render
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );

	$div->appendChild( $self->html_phrase("sure_activate",
		title=>$self->{processor}->{dataobj}->render_value('name') ) );

	my %buttons = (
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		activate => $self->{session}->phrase(
				"lib/submissionform:action_activate" ),
		_order => [ "activate", "cancel" ]
	);

	my $form= $self->render_form;
	$form->appendChild( 
		$self->{session}->render_action_buttons( 
			%buttons ) );
	$div->appendChild( $form );

	return( $div );
}	

sub allow_activate
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub allow_cancel
{
	my( $self ) = @_;

	return 1;
}

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Coversheet::Listing";
}

sub action_activate
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Coversheet::Listing";

	$self->{processor}->{dataobj}->set_value('status', 'active');
	$self->{processor}->{dataobj}->commit();

	$self->{processor}->add_message( "message", $self->html_phrase( "item_activated" ) );
}


1;
