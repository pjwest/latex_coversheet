
# define the Coversheet dataset
$c->{datasets}->{coversheet} = {
	class => "EPrints::DataObj::Coversheet",
	sqlname => "coversheet",
        sql_counter => "coversheetid",
};

# Define the default columns (fields) shown on the Manage Records Screens
$c->{datasets}->{coversheet}->{columns} = [ 'coversheetid', 'status', 'name', 'frontfile', 'backfile' ];

{
no warnings;
package EPrints::DataObj::Coversheet;

our @ISA = qw( EPrints::DataObj );

use strict;

sub valid_file_extensions
{
	return [ 'pdf', 'odt' ];
}

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
                { name=>"coversheetid", type=>"counter", required=>1, can_clone=>0,
                        sql_counter=>"coversheetid" },

		{ name=>"datestamp", type=>"time", required=>1, text_index=>0 },

		{ name=>"lastmod", type=>"time", required=>0, import=>0,
                	render_res=>"minute", render_style=>"short", can_clone=>0 },

		{ name=>"userid", type=>"itemref", datasetid=>"user", required=>1, text_index=>0 },

		{ name=>"status", type=>"set", required=>1, text_index=>0,
			options => [qw/ draft active deprecated /] },

		{ name=>"name", type=>"text", required=>1 },

		{ name=>"description", type=>"longtext", required => 1 },

		{ name=>"official_url", type=>"url" },

		{ name=>"version_comments", type=>"longtext" },

		{ name=>"notes", type=>"longtext" },

		{
			name=>"frontfile",
			type=>"file",
			render_value=>"EPrints::DataObj::Coversheet::render_coversheet_file",
			render_input => "EPrints::DataObj::Coversheet::render_coversheet_file_input"
		},
		{
			name=>"backfile",
			type=>"file",
			render_value=>"EPrints::DataObj::Coversheet::render_coversheet_file",
			render_input => "EPrints::DataObj::Coversheet::render_coversheet_file_input"
		},

		{
			name => "apply_priority",
			type => "int",
		},
		{
			name => "apply_to",
			type => "search",
			datasetid => "eprint",
			fieldnames_config => "license_application_fields",
		},


	);
}

######################################################################

=back

=head2 Constructor Methods

=over 4

=cut

######################################################################

=item $thing = EPrints::DataObj::Coversheet->new( $session, $id )

The data object identified by $id.

=cut

sub new
{
	my( $class, $session, $id ) = @_;

	return $session->get_database->get_single( 
			$session->get_repository->get_dataset( "coversheet" ),
			$id );
}

=item $thing = EPrints::DataObj::Coversheet->new_from_data( $session, $known )

A new C<EPrints::DataObj::Coversheet> object containing data $known (a hash reference).

=cut

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	return $class->SUPER::new_from_data(
			$session,
			$known,
			$session->get_repository->get_dataset( "coversheet" ) );
}

######################################################################

=item $defaults = EPrints::DataObj::Coversheet->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut

######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;

        if( !defined $data->{coversheetid} )
        {
                $data->{coversheetid} = $session->get_database->counter_next( "coversheetid" );
        }
	
	$data->{status} = 'draft';
	$data->{datestamp} = EPrints::Time::get_iso_timestamp();

	return $data;
}


######################################################################
=pod

=item $user->commit( [$force] )

Write this object to the database.

As modifications to files don't make any changes to the metadata, this will
always write back to the database.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;

        if( !$self->is_set( "datestamp" ) )
        {
                $self->set_value(
                        "datestamp" ,
                        EPrints::Time::get_iso_timestamp() );
        }

	$self->set_value("lastmod" , EPrints::Time::get_iso_timestamp() );

	my $coversheet_ds = $self->{session}->get_repository->get_dataset( "coversheet" );
	$self->tidy;

	# EPrints Services/sf2: adapted to 3.2 API (i.e. let the SUPER class write to the DB)
	my $success = $self->SUPER::commit( $force );

	return( $success );
}


######################################################################

=head2 Object Methods

=cut

######################################################################

=item $foo = $thing->remove()

Remove this record from the data set (see L<EPrints::Database>).

=cut

sub remove
{
	my( $self ) = @_;
	
	my $rc = 1;

	foreach (qw/ frontfile backfile /) #get rid of the documents
	{
		$self->erase_page($_);
	}
	
	my $database = $self->{session}->get_database;

	$rc &&= $database->remove(
		$self->{dataset},
		$self->get_id );

	return $rc;
}

######################################################################
# =pod
# 
# =item $dataobj = EPrints::DataObj->create_from_data( $session, $data, $dataset )
# 
# Create a new object of this type in the database. 
# 
# $dataset is the dataset it will belong to. 
# 
# $data is the data structured as with new_from_data.
# 
# =cut
######################################################################

sub get_dataset_id
{
	return 'coversheet';
}

sub create_from_data
{
        my( $class, $session, $data, $dataset ) = @_;

        my $new_coversheet = $class->SUPER::create_from_data( $session, $data, $dataset );

        $session->get_database->counter_minimum( "coversheetid", $new_coversheet->get_id );

        return $new_coversheet;
}

# return the applicable Coversheet, given an eprint object
sub search_by_eprint
{
	my( $class, $session, $eprint ) = @_;

        my $list = $session->dataset( $class->get_dataset_id )->search(
                filters => [
                        { meta_fields => [qw( status )], value => 'active' },
                ],
                custom_order => '-apply_priority/-coversheetid',
        );

	my $cs;
	foreach my $possible_cs ( $list->get_records )
	{
                if( $possible_cs->applies_to_eprint( $eprint ) )
                {
			$cs = $possible_cs;
                        last;
                }
	}

	return $cs;
}

sub get_file_path
{
	my ($self, $fieldname) = @_;

        foreach (@{$self->valid_file_extensions()})
        {
		my $file_path = $self->get_path() . '/' . $fieldname . '.' . $_;
                return $file_path if -e $file_path;
        }

	return undef;
}

sub get_file_url
{
	my ($self, $fieldname) = @_;

	foreach (@{$self->valid_file_extensions()})
	{
		my $filename = $fieldname . '.' . $_;
		my $file_path = $self->get_path() . '/' . $filename;
		return
			$self->{session}->config( 'coversheet', 'url' ) . '/' . $self->get_id . '/' . $filename
		if
			-e $file_path;
	}

	return undef;
}

sub get_pages
{
	my( $self ) = @_;

	my $frontfile_path = $self->get_file_path( 'frontfile' );
	my $frontfile_type = $self->get_page_type( 'frontfile' );
	my $backfile_path = $self->get_file_path( 'backfile' );
	my $backfile_type = $self->get_page_type( 'backfile' );

	return undef unless( defined  $frontfile_path || $backfile_path );

	return { 
		frontfile => {
			path => $frontfile_path,
			type => $frontfile_type
		},
		backfile => {
			path => $backfile_path,
			type => $backfile_type,
		}
	};

}


sub get_page_type
{
	my ($self, $fieldname) = @_;

	my $file_path = $self->get_file_path($fieldname);
	if ($file_path)
	{
		$file_path =~ m/[^\.]*$/;
		return $&;
	}

	return 'none';
}

sub render_coversheet_file
{
        my( $session, $field, $value, $alllangs, $nolink, $coversheet ) = @_;

        my $f = $session->make_doc_fragment;

	my $label = $session->html_phrase('Coversheet/Type:' . $coversheet->get_page_type($field->get_name));

	my $url = $coversheet->get_file_url($field->get_name);
	if ($url)
	{
		my $link = $session->render_link($url);
		$link->appendChild($label);
		$f->appendChild($link);
	}
	else
	{
		$f->appendChild($label);
	}

        return $f;
}

#takes a user and a fieldname (frontfile, backfile) and returns true if this user can approve the new file.
sub can_approve
{
	my ($self, $user, $fieldname) = @_;

	return ($user->get_id != $self->get_value( $fieldname . '_proposer_id') );
}


sub update_coversheet
{
	my ($self, $fieldname) = @_;

	my $new_file = $self->get_file_path('proposed_' . $fieldname);
	return unless $new_file; #don't remove the old one unless we have the new one 

	unlink $self->get_file_path($fieldname) if $self->get_file_path($fieldname);
	
	$new_file =~ m([^\.]*$); #grab extension
	my $new_file_path = $self->get_path() . '/' . $fieldname . '.' . $&;

	rename($self->get_file_path('proposed_' . $fieldname), $new_file_path);

	$self->set_value($fieldname . '_proposer_id', undef);
	$self->commit;
}

sub render_coversheet_file_input
{
        my( $field, $session, $value, $dataset, $staff, $hidden_field, $obj, $basename ) = @_;

        my $f = $session->make_doc_fragment;

	$f->appendChild($session->html_phrase('current_file'));
        $f->appendChild($field->render_value($session, $value, undef, undef, $obj));

	$f->appendChild($session->make_element('br'));
#       <input name="c3_first_file" type="file" id="c3_first_file" />

	$f->appendChild($session->html_phrase('upload_file'));
        my $input = $session->make_element('input', type => 'file', id => $field->get_name . '_input', name => $field->get_name . '_input' );
        $f->appendChild($input);

        return $f;
}

#return path to coversheet files, and create directories.
sub get_path
{
	my ($self) = @_;

	my $path = $self->{session}->config( 'coversheet', 'path' );
	mkdir $path unless -e $path; #not too fantastic

	$path .= '/' . $self->get_id;
	unless (-e $path)
	{
		mkdir $path unless -e $path;
	}

	return $path;
}

#return paths to live files
sub get_live_paths
{
	my ($self) = @_;

	my $repository = $self->{session}->get_repository;;
	my @paths;

	foreach my $lang (@{$repository->get_conf('languages')})
	{
		push @paths, $repository->config('archiveroot') . '/html/' . $lang . $repository->config( 'coversheet', 'path_suffix' ) . '/' . $self->get_id ;
	}

	return @paths;
}


#name is metafield name (e.g. frontfile, backfile)
sub erase_page
{
	my ($self, $fieldname) = @_;

	my @paths_to_check = ( $self->get_path, $self->get_live_paths );

	foreach my $path (@paths_to_check)
	{
		my $filename = $path . '/' . $fieldname . '.';
		foreach my $extension (@{$self->valid_file_extensions()})
		{
			my $full_filename = $filename . $extension;
			unlink $full_filename if -e $full_filename;
		}
	}
	$self->commit();
}

#for now check extensions...
sub valid_file
{
	my ($self, $file) = @_;

	$file =~ m/[^\.]*$/;
	my $extension = $&;

	foreach (@{$self->valid_file_extensions()})
	{
		return 1 if $_ eq lc($extension);
	}

	return 0;
}

#based on EPrints->in_edorial_scope_of
sub applies_to_eprint_DEPR
{
	my( $self, $eprint ) = @_;

	return 0 unless $self->is_set('apply_to');

	my $search = $self->{dataset}->get_field('apply_to')->make_searchexp($self->{session}, $self->get_value('apply_to')); #it's not a multiple field
	my $r = $search->get_conditions->item_matches( $eprint );
	return 1 if $r;
	return 0;
}

# Checks that this CS applies to $eprint (tests done in-memory). The original code (above) was testing via database lookup.
sub applies_to_eprint
{
	my( $self, $eprint ) = @_;
	
	return 0 unless $self->is_set('apply_to');

	my $fields = $self->{session}->config( 'license_application_fields' ) || return 0;
	my $applyto = $self->get_value( 'apply_to' );

	my @conds;
	foreach my $f (@$fields)
	{

		my $field = $eprint->dataset->field( $f );

#		0|1||eprint|-|
#		subjects:subjects:ALL:EQ:10171|type:type:ANY:EQ:article book_section
		if( $applyto =~ /\|$f:$f:(ANY|ALL):EQ:(.*)$/ )
		{
			my $op = $1;
			my $tail = $2;
			$tail =~ s/\|.*$//g;

			my @ok_values = split /\s/, $tail;
			my $real_val = $eprint->get_value( $f );
			my $rc = &_cmp_values( $self->{session}, $field, $real_val, \@ok_values, $op );		# return 1 if( type1 OR type2 ) ...AND...
			push @conds, $rc;
		}
	}

	return 0 unless(scalar(@conds));
	
	for(@conds)
	{
		return 0 unless($_);
	}

	return 1;
}

sub _cmp_values
{
	my( $session, $field, $real_val, $ok_val, $operator ) = @_;

	return 0 unless( defined $real_val );

	my $subj_ds = $session->get_repository->get_dataset( "subject"); 
	$real_val = [$real_val] unless( ref($real_val) eq 'ARRAY' );
	my $reqd_vals = ();

	foreach my $val (@$ok_val)
	{
		$reqd_vals->{$val}->{reqd} = 1;
		$reqd_vals->{$val}->{matched} = 0;

		if( $field->isa('EPrints::MetaField::Subject') )
		{
			# need to add the children of each ok_val entry to the list of "ok vals"
			my $new_ok_vals = ();
			my $subj = $subj_ds->dataobj($val);
			if (defined $subj)
			{
				my @children = $subj->get_children;
				if (@children)
				{
					foreach my $child (@children)
					{
						push @$new_ok_vals, $child->get_id;
					}
					$reqd_vals->{$val}->{alt} = $new_ok_vals;
				}
			}
		}
	}

	if( $operator eq 'ANY' )
	{
		foreach my $rv ( @$real_val )
		{
			foreach my $ov ( keys %$reqd_vals )  
			{ 
				return 1 if( "$rv" eq "$ov" ); 
				#check alternative values
				foreach my $av ( @{$reqd_vals->{$ov}->{alt}} )
				{	
					return 1 if ($rv == $av);
				}
			}
		}
		return 0;
	}
	elsif( $operator eq 'ALL' )
	{
		return 0 if scalar @$real_val < scalar @$ok_val;
		REAL_VALUE: foreach my $rv ( @$real_val )
		{
			OK_VALUE: foreach my $ov ( keys %$reqd_vals )  
			{ 
				next OK_VALUE if $reqd_vals->{$ov}->{matched};
				if ($rv == $ov)
				{
					$reqd_vals->{$ov}->{matched} = 1; 
					next REAL_VALUE;
				}
				else
				{
					#check alternative values
					foreach my $av ( @{$reqd_vals->{$ov}->{alt}} )
					{	
						if ($rv == $av)
						{
							$reqd_vals->{$ov}->{matched} = 1;
							next REAL_VALUE;
						}
					}
				}
			}
		}
		foreach my $ov ( keys %$reqd_vals )
		{
			return 0 if 0 == $reqd_vals->{$ov}->{matched};
		}
		return 1;
	}
	return 0;
}

sub get_coversheet_doc
{
	my( $self, $doc ) = @_;

	my $coverdoc;
	if (defined $doc)
	{
		# get related documents
		my $related_docs_list = $doc->search_related( "isCoversheetVersionOf" );
		if ($related_docs_list->count)
		{
			# there should be only one (in true highlander fashion)
			# but get the latest just in case there has been
			# some issue with the indexer for example.
			my $ordered_docs = $related_docs_list->reorder( "-docid" );
			$coverdoc = $ordered_docs->item( 0 );
		}
	}
	return $coverdoc;
}

sub needs_regeneration
{
	my( $self, $doc, $coverdoc ) = @_;

	my $regenerate = 1;
	my $coverfile;

	# get the latest coverdoc if the one supplied is undefined.
	# n.b. this will be the case when this is invoked from the 
	# event so a previous event may have already created a new 
	# coverdoc.
	if (! defined $coverdoc) 
	{
		$coverdoc = $self->get_coversheet_doc($doc);
	}
	# compare timestamps
		
	$coverfile = $coverdoc->local_path.'/'.$coverdoc->get_main if defined $coverdoc;
		
	if( defined $coverdoc && defined $coverfile && -e $coverfile )
	{
		# Get the local mtime (stat), convert to GMT (gmtime), convert to epoch seconds (timelocal)
		use Time::Local;
		my $covermod = timelocal( gmtime( ( stat( $coverfile ) )[9] ) );

		# Get the the eprint lastmod date (GMT) 
		my $eprint = $doc->get_eprint;
		my $eprintmoddate = $eprint->get_value( 'lastmod' );
		$eprintmoddate =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/;
		my $eprintmod = timelocal($6,$5,$4,$3,( $2 - 1 ),$1);

		 # Get the the coversheet lastmod date (GMT)
		my $coversheetmoddate = $self->get_value( 'lastmod' );
		$coversheetmoddate =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/;
		my $coversheetmod = timelocal($6,$5,$4,$3,( $2 - 1 ),$1);

		# EPrints Services/tmb 2011-08-26 if we generate the coverpage we modify the eprint lastmod (doc->commit = eprint->commit)
		# so the eprintmod could be the same as covermod and it is still valid to use the existing coversheet
		# otherwise we re-generate on every request
		$regenerate = 0 if( ($eprintmod <= $covermod) && ($coversheetmod < $covermod) );
	}
	return $regenerate;
}


}

