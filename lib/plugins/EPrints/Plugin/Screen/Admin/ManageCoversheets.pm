=head1 NAME

EPrints::Plugin::Screen::Admin::ManageCoversheets

=cut

package EPrints::Plugin::Screen::Admin::ManageCoversheets;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{ 
			place => "admin_actions_system", 
			position => 1274, 
		},
	];
	$self->{actions} = []; 

	return $self;
}

sub from
{
	my( $self ) = @_;
	my $url = URI->new( $self->{repository}->config( "userhome" ) );
	$url->query_form(
		screen => "Coversheet::Listing",
		dataset => "coversheet",
		#dataobj => $savedsearch->id,
	);
	$self->{repository}->redirect( $url );
}

1;


