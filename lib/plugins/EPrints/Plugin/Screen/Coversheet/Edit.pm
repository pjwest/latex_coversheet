
package EPrints::Plugin::Screen::Coversheet::Edit;

use File::Copy;

@ISA = ( 'EPrints::Plugin::Screen::Workflow' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

        $self->{icon} = "action_edit.png";

        $self->{appears} = [
                {	# Listing
                        place => "dataobj_actions",
                        position => 300,
                },
        ];

	$self->{actions} = [qw/ update exit delete_frontfile delete_backfile /];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

        my $ds = $self->{processor}->{dataset}; # set by Screen::Listing

	if( defined $ds && $ds->base_id eq 'coversheet' )
	{
		return $self->allow( "coversheet/write" ) 
	}
	return 0;
}

sub from
{
	my( $self ) = @_;

	if( defined $self->{processor}->{internal} )
	{
		my $from_ok = $self->workflow->update_from_form( $self->{processor},undef,1 );
		$self->uncache_workflow;
		return unless $from_ok;
	}

	$self->EPrints::Plugin::Screen::from;
}

sub allow_exit
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_exit
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = 'Listing';	
}	

sub allow_delete_frontfile
{
	my( $self ) = @_;

	if( $self->{processor}->{dataobj}->get_page_type('frontfile') ne 'none' )
	{
		return $self->can_be_viewed;
	}
	return 0;
}

sub action_delete_frontfile
{
	my( $self ) = @_;

	$self->_delete_file('frontfile');
}	

sub allow_delete_backfile
{
	my( $self ) = @_;

	if( $self->{processor}->{dataobj}->get_page_type('backfile') ne 'none' )
	{
		return $self->can_be_viewed;
	}
	return 0;
}

sub action_delete_backfile
{
	my( $self ) = @_;

	$self->_delete_file('backfile');
}	

sub _delete_file
{
	my ($self, $fieldname) = @_;

	$self->{processor}->{dataobj}->erase_page($fieldname);

	$self->{processor}->add_message( 'message', $self->html_phrase('file_removed'));

	$self->{processor}->{screenid} = "Coversheet::Edit";
}

sub allow_update
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_update
{
	my( $self ) = @_;

	$self->workflow->update_from_form( $self->{processor} );

	my $errors = 0;
	foreach (qw/ frontfile backfile /)
	{
		my $status = $self->save_file( $_ . '_input', $_ );
		if( !$status )
		{
			$self->{processor}->add_message( 'error', $self->html_phrase('file_not_ok'));
			$errors++;
		}
	}

	my @problems = $self->workflow->validate();
	$errors += scalar @problems;

	$self->uncache_workflow;

	unless ($errors)
	{
		$self->{processor}->add_message( 'message', $self->html_phrase('coversheet_saved'));
	}
	$self->{processor}->{screenid} = "Coversheet::Edit";
}

sub save_file
{
	my ($self, $cgi_param, $fieldname) = @_;

	my $session = $self->{session};
	my $coversheet = $self->{processor}->{dataobj};

	my $fh = $session->get_query->upload( $cgi_param );
	my $filename = $session->get_query->param( $cgi_param );

	if( defined( $fh ) )
	{
		binmode($fh);

		$filename =~ m/[^\.]*$/;
		my $extension = $&;
		my $tmpfile = File::Temp->new( SUFFIX => ".$extension" );
		binmode($tmpfile);

		use bytes;
		while(sysread($fh,my $buffer,4096)) {
			syswrite($tmpfile,$buffer);
		}
		seek($tmpfile, 0, 0);

		if ($coversheet->valid_file($tmpfile))
		{
			$coversheet->erase_page($fieldname);
			my $abs_file = $coversheet->get_path() . "/$fieldname." . lc($extension);

			copy($tmpfile, $abs_file);

			$coversheet->commit; #update lastmod
			return 1 if -e $abs_file;
		}
		return 0;
	}
	return 1;#there wasn't a file, but that's OK
}


sub screen_after_flow
{
	my( $self ) = @_;

	return "Listing";
}

sub render
{
	my( $self ) = @_;

	my $form = $self->render_form;

	$form->appendChild( $self->render_buttons );
	$form->appendChild( $self->workflow->render );
	$form->appendChild( $self->render_file_buttons );
	$form->appendChild( $self->render_buttons );
	
	return $form;
}


sub render_delete_button
{
	my ($self, $fieldname) = @_;

	my %buttons = ( _order=>[], _class=>"ep_form_button_bar" );

	push @{$buttons{_order}}, "delete_$fieldname";
	$buttons{cancel} = $self->phrase( "delete_file" );

	return $self->{session}->render_action_buttons( %buttons );
}

sub render_file_buttons
{
	my( $self ) = @_;

	my $frag = $self->{session}->make_doc_fragment;
	my %buttons = ( _order=>[], _class=>"ep_form_button_bar" );

	my $button_count = 0;
	foreach my $fieldname (qw/ frontfile backfile /)
	{
		if ($self->{processor}->{dataobj}->get_page_type($fieldname) ne 'none')
		{
			push @{$buttons{_order}}, "delete_$fieldname";
			$buttons{"delete_$fieldname"} = $self->phrase( "delete_$fieldname" );
			$button_count++;
		}
	}

	$frag->appendChild($self->{session}->render_action_buttons( %buttons )) if $button_count;
	return $frag;

}

sub render_buttons
{
	my( $self ) = @_;

	my %buttons = ( _order=>[], _class=>"ep_form_button_bar" );

	if( defined $self->workflow->get_prev_stage_id || defined $self->workflow->get_next_stage_id )
	{
		print STDERR "Multistage coversheet workflows are unsupported\n";
	}

	push @{$buttons{_order}}, "update", "exit" ;
	$buttons{'exit'} = $self->phrase( "exit" );
	$buttons{update} = $self->phrase( "update" );

	return $self->{session}->render_action_buttons( %buttons );
}

1;


