
package EPrints::Plugin::Screen::Coversheet::New;

use EPrints::Plugin::Screen::NewDataobj;

@ISA = ( 'EPrints::Plugin::Screen::NewDataobj' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
                {	# Listing
                        place => "dataobj_tools",
                        action => "create",
                        position => 100,
                }
	];

	return $self;
}

sub allow_create
{
	my ( $self ) = @_;

        my $ds = $self->{processor}->{dataset}; # set by Screen::Listing

        if( defined $ds && $ds->base_id eq 'coversheet' )
        {
		return $self->allow( "coversheet/write" );
	}

	return 0;
}

sub action_create
{
	my( $self ) = @_;

	my $ds = $self->{processor}->{session}->dataset( "coversheet" );

	my $user = $self->{session}->current_user;

	$self->{processor}->{dataobj} = $ds->create_object( $self->{session}, { 
		userid => $user->get_value( "userid" ) } );

	if( !defined $self->{processor}->{dataobj} )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{processor}->{session}->log( "Database Error: $db_error" );
		$self->{processor}->add_message( 
			"error",
			$self->html_phrase( "db_error" ) );
		return;
	}

	$self->{processor}->{screenid} = "Coversheet::Edit";
}


1;
