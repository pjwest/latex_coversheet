=head1 NAME

EPrints::Plugin::Screen::Coversheet::Listing

=cut

package EPrints::Plugin::Screen::Coversheet::Listing;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen::Listing' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
#		{
#			place => "key_tools",
#			position => 100,
#		}
	];

	$self->{actions} = [qw/ search newsearch col_left col_right remove_col add_col /];

	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	my $priv = $self->{processor}->{dataset}->id . "/preview";

	return $self->allow( $priv ) || $self->allow( "$priv:owner" ) || $self->allow( "$priv:editor" );
}

sub allow_action
{
	my( $self, $action ) = @_;

	return $self->can_be_viewed();
}

sub action_search
{
}

sub action_newsearch
{
}

sub __render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $user = $session->current_user;
	my $imagesurl = $session->config( "rel_path" )."/style/images";

	my $chunk = $session->make_doc_fragment;

	$chunk->appendChild( $self->render_top_bar() );

	$chunk->appendChild( $self->render_filters() );

	### Get the items owned by the current user
	my $ds = $self->{processor}->{dataset};

	my $search = $self->{processor}->{search};
	my $list = $self->perform_search;
	my $exp;
	if( !$search->is_blank )
	{
		$exp = $search->serialise;
	}

	my $columns = $self->{processor}->{columns};

	my $len = scalar @{$columns};

	my $final_row = $session->make_element( "tr" );
	foreach my $i (0..$#$columns)
	{
		# Column headings
		my $td = $session->make_element( "td", class=>"ep_columns_alter" );
		$final_row->appendChild( $td );

		my $acts_table = $session->make_element( "table", cellpadding=>0, cellspacing=>0, border=>0, width=>"100%" );
		my $acts_row = $session->make_element( "tr" );
		my $acts_td1 = $session->make_element( "td", align=>"left", width=>"14px" );
		my $acts_td2 = $session->make_element( "td", align=>"center", width=>"100%");
		my $acts_td3 = $session->make_element( "td", align=>"right", width=>"14px" );
		$acts_table->appendChild( $acts_row );
		$acts_row->appendChild( $acts_td1 );
		$acts_row->appendChild( $acts_td2 );
		$acts_row->appendChild( $acts_td3 );
		$td->appendChild( $acts_table );

		if( $i > 0 )
		{
			my $form_l = $self->render_form;
			$form_l->appendChild( $session->render_hidden_field( "column", $i ) );
			$form_l->appendChild( $session->make_element( 
				"input",
				type=>"image",
				value=>$session->phrase( "lib/paginate:move_left" ),
				title=>$session->phrase( "lib/paginate:move_left" ),
				src => "$imagesurl/left.png",
				alt => "<",
				name => "_action_col_left" ) );
			$acts_td1->appendChild( $form_l );
		}
		else
		{
			$acts_td1->appendChild( $session->make_element("img",src=>"$imagesurl/noicon.png",alt=>"") );
		}

		my $msg = $self->phrase( "remove_column_confirm" );
		my $form_rm = $self->render_form;
		$form_rm->appendChild( $session->render_hidden_field( "column", $i ) );
		$form_rm->appendChild( $session->make_element( 
			"input",
			type=>"image",
			value=>$session->phrase( "lib/paginate:remove_column" ),
			title=>$session->phrase( "lib/paginate:remove_column" ),
			src => "$imagesurl/delete.png",
			alt => "X",
			onclick => "if( window.event ) { window.event.cancelBubble = true; } return confirm( ".EPrints::Utils::js_string($msg).");",
			name => "_action_remove_col" ) );
		$acts_td2->appendChild( $form_rm );

		if( $i < $#$columns )
		{
			my $form_r = $self->render_form;
			$form_r->appendChild( $session->render_hidden_field( "column", $i ) );
			$form_r->appendChild( $session->make_element( 
				"input",
				type=>"image",
				value=>$session->phrase( "lib/paginate:move_right" ),
				title=>$session->phrase( "lib/paginate:move_right" ),
				src => "$imagesurl/right.png",
				alt => ">",
				name => "_action_col_right" ) );
			$acts_td3->appendChild( $form_r );
		}
		else
		{
			$acts_td3->appendChild( $session->make_element("img",src=>"$imagesurl/noicon.png",alt=>"")  );
		}
	}
	my $td = $session->make_element( "td", class=>"ep_columns_alter ep_columns_alter_last" );
	$final_row->appendChild( $td );

	# Paginate list
	my $row = 0;
	my %opts = (
		params => {
			screen => $self->{processor}->{screenid},
			exp => $exp,
			$self->hidden_bits,
		},
		custom_order => $search->{custom_order},
		columns => [(map{ $_->name } @{$columns}), undef ],
		above_results => $session->make_doc_fragment,
		render_result => sub {
			my( undef, $dataobj ) = @_;

			local $self->{processor}->{dataobj} = $dataobj;
			my $class = "row_".($row % 2 ? "b" : "a");

			my $tr = $session->make_element( "tr", class=>$class );

			my $first = 1;
			for( map { $_->name } @$columns )
			{
				my $td = $session->make_element( "td", class=>"ep_columns_cell".($first?" ep_columns_cell_first":"")." ep_columns_cell_$_"  );
				$first = 0;
				$tr->appendChild( $td );
				$td->appendChild( $dataobj->render_value( $_ ) );
			}

			my $td = $session->make_element( "td", class=>"ep_columns_cell ep_columns_cell_last", align=>"left" );
			$tr->appendChild( $td );
			$td->appendChild( $self->render_dataobj_actions( $dataobj ) );

			++$row;

			return $tr;
		},
		rows_after => $final_row,
	);

	$opts{page_size} = $self->param( 'page_size' );

	$chunk->appendChild( EPrints::Paginate::Columns->paginate_list( $session, "_listing", $list, %opts ) );


	# Add form
	my $div = $session->make_element( "div", class=>"ep_columns_add" );
	my $form_add = $self->render_form;

	my %col_shown = map { $_->name() => 1 } @$columns;
	my $fieldnames = {};
	foreach my $field ( $ds->fields )
	{
		next if !$field->get_property( "show_in_fieldlist" );
		next if $col_shown{$field->name};
		my $name = EPrints::Utils::tree_to_utf8( $field->render_name( $session ) );
		my $parent = $field->get_property( "parent_name" );
		if( defined $parent ) 
		{
			my $pfield = $ds->field( $parent );
			$name = EPrints::Utils::tree_to_utf8( $pfield->render_name( $session )).": $name";
		}
		$fieldnames->{$field->name} = $name;
	}

	my @tags = sort { $fieldnames->{$a} cmp $fieldnames->{$b} } keys %$fieldnames;

	$form_add->appendChild( $session->render_option_list( 
		name => 'column',
		height => 1,
		multiple => 0,
		'values' => \@tags,
		labels => $fieldnames ) );
		
	$form_add->appendChild( 
			$session->render_button(
				class=>"ep_form_action_button",
				name=>"_action_add_col", 
				value => $session->phrase( "lib/paginate:add_column" ),
			) );
	$div->appendChild( $form_add );
	$chunk->appendChild( $div );
	# End of Add form

	return $chunk;
}

sub __hidden_bits
{
	my( $self ) = @_;

	return(
		dataset => $self->{processor}->{dataset}->id,
		_listing_order => $self->{processor}->{search}->{custom_order},
		$self->SUPER::hidden_bits,
	);
}

sub __render_top_bar
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $chunk = $session->make_doc_fragment;

	if( $session->get_lang->has_phrase( $self->html_phrase_id( "intro" ), $session ) )
	{
		my $intro_div_outer = $session->make_element( "div", class => "ep_toolbox" );
		my $intro_div = $session->make_element( "div", class => "ep_toolbox_content" );
		$intro_div->appendChild( $self->html_phrase( "intro" ) );
		$intro_div_outer->appendChild( $intro_div );
		$chunk->appendChild( $intro_div_outer );
	}

	# we've munged the argument list below
	$chunk->appendChild( $self->render_action_list_bar( "dataobj_tools", {
		dataset => $self->{processor}->{dataset}->id,
	} ) );

	return $chunk;
}

sub render_dataobj_actions
{
	my( $self, $dataobj ) = @_;

	my $datasetid = $self->{processor}->{dataset}->base_id;

	return $self->render_action_list_icons( ["${datasetid}_item_actions", "coversheet_actions"], {
			dataset => $datasetid,
			dataobj => $dataobj->id,
		} );
}


1;


