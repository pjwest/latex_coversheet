=head1 NAME

EPrints::Plugin::Screen::Coversheet::Destroy

=cut

package EPrints::Plugin::Screen::Coversheet::Destroy;

@ISA = ( 'EPrints::Plugin::Screen::Workflow::Destroy' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ remove cancel /];

	$self->{icon} = "action_remove.png";

	$self->{appears} = [
		{
			place => "coversheet_actions",
			position => 1600,
		},
	];
	
	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

        my $ds = $self->{processor}->{dataset}; # set by Coversheet::Listing

	if( defined $ds && $ds->base_id eq 'coversheet' )
	{
		return $self->allow( "coversheet/write" ) 
	}
	return 0;
}

sub view_screen { "Coversheet::View" }
sub listing_screen { "Coversheet::Listing" }


1;


