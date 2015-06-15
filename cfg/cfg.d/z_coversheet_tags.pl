
# Example definition of tags that can be used in the coversheets
# when using potential utf-8 strings, use the encode() method on the string:
$c->{coversheet}->{tags} = {

		'title' 	=>  sub { my ($eprint) = @_; return  EPrints::Utils::tree_to_utf8($eprint->render_value('title')) ; },

		'type' 		=>  sub { my ($eprint) = @_; return EPrints::Utils::tree_to_utf8($eprint->render_value('type')); },

		'url' 		=>  sub { my ($eprint) = @_; return $eprint->get_url; },

		'date'		=> sub {
			my( $eprint ) = @_;
			if( $eprint->is_set( "date" ) )
			{
				my $date = $eprint->get_value( "date" );
				$date =~ /^([0-9]{4})/;
				return $1 if defined $1;
			}
			return '';
		},


		'citation'      =>  sub { 
			my ($eprint) = @_; 
			my $cit_str = EPrints::Utils::tree_to_utf8($eprint->render_citation,undef,undef,undef,1 );
			return $cit_str; 
		},

		'creators'      =>  sub { 
			my ($eprint) = @_; 
			my $field = $eprint->dataset->field("creators_name");
			if ($eprint->is_set( "creators_name" ) ) 
			{
				return  EPrints::Utils::tree_to_utf8($field->render_value($eprint->repository, $eprint->get_value("creators_name"), 0, 1) ); 
			}
                        elsif ($eprint->is_set( "editors_name" ) )
                        {
                                 $field = $eprint->dataset->field("editors_name");
                                 return "Edited by: " . EPrints::Utils::tree_to_utf8($field->render_value($eprint->repository,$eprint->get_value("editors_name"), 0, 1) );
                        }
			else
			{
				return '';
			}
		},

		'doi_url'	=>  sub {
			my ($eprint) = @_; 
			if ($eprint->is_set( "id_number" ) )
			{
				my $value = $eprint->get_value( "id_number" );

				$value =~ s|^http://dx\.doi\.org||;
				if( $value !~ /^(doi:)?10\.\d\d\d\d\// )
				{
					return $value;
				}
				else
				{
					$value =~ s/^doi://;
					return "http://dx.doi.org/$value";
				}
			}
			else
			{
				return '';
			}
		},
};

1;
