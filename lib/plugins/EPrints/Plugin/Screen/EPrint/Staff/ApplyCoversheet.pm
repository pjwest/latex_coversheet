=head1 NAME

EPrints::Plugin::Screen::EPrint::Staff::ApplyCoversheet

=cut

package EPrints::Plugin::Screen::EPrint::Staff::ApplyCoversheet;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ cover /];

	$self->{appears} = [ {
		place => "eprint_editor_actions",
		action => "cover",
		position => 1880,
	}, ];

	return $self;
}

sub obtain_lock
{
	my( $self ) = @_;

	return $self->could_obtain_eprint_lock;
}

sub about_to_render 
{
	my( $self ) = @_;

	$self->EPrints::Plugin::Screen::EPrint::View::about_to_render;
}


sub allow_cover
{
	my( $self ) = @_;

	return 0 unless $self->could_obtain_eprint_lock;
	return $self->allow( "eprint/edit:editor" ) &&
		$self->allow( "coversheet/reapply" );
}

sub action_cover {
	my( $self ) = @_;

	$self->{processor}->{screenid} = "EPrint::View";

	my $repo = $self->{repository};
	my $eprint = $self->{processor}->{eprint};

       	my $plugin = $repo->plugin( "Convert::AddCoversheet" );
	unless( defined $plugin )
       	{
               	$self->{processor}->add_message(
                        "warning",
                        $self->html_phrase( "no_plugin" ) ); 
		return;
       	}
	my $covered = $repo->call( "cover_eprint_docs" , $repo, $eprint, $plugin );

	if ( $covered )
	{
		$self->{processor}->add_message( "message",
			$self->html_phrase( "covered" ) );
	}
	else
	{
		$self->{processor}->add_message( "warning",
			$self->html_phrase( "not_covered" ) );
	}
	return;
}



1;


