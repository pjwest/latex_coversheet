package EPrints::Plugin::Screen::EPMC::LatexCoversheet;

use EPrints::Plugin::Screen::EPMC;

@ISA = ( 'EPrints::Plugin::Screen::EPMC' );

use strict;

sub new
{
      my( $class, %params ) = @_;

      my $self = $class->SUPER::new( %params );

      $self->{actions} = [qw( enable disable )];
      $self->{disable} = 0; # always enabled, even in lib/plugins

      $self->{package_name} = "latexcoversheet";

      return $self;
}

=item $screen->action_enable( [ SKIP_RELOAD ] )

Enable the L<EPrints::DataObj::EPM> for the current repository.

If SKIP_RELOAD is true will not reload the repository configuration.

=cut


sub action_enable
{
	my( $self, $skip_reload ) = @_;

     	$self->SUPER::action_enable( $skip_reload );
 
	$self->reload_config if !$skip_reload;
}

sub action_disable
{
	my( $self, $skip_reload ) = @_;

      	$self->SUPER::action_disable( $skip_reload );

	my $repo = $self->{repository};
}

sub render_messages
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( $repo->render_message( 'message', $self->html_phrase( 'ready' ) ) );

	return $frag;
}



1;
