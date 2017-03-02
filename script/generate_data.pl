#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use Path::Class;
use Getopt::Long;
use Data::Dumper;
use Scalar::Util qw/ blessed /;
use Carp qw/ croak /;

use Smart::Comments;

use Bio::SeqIO;
use Cath::Schema::Biomap;

my $CATH_VERSION = '4.1';
my $OVERWRITE_EXISTING_FILES = 0;
$| = 1;

GetOptions(
  'f|force' => \$OVERWRITE_EXISTING_FILES,
);

my $ROOT_DIR = dir( "$FindBin::Bin/../" );
my $DATA_DIR = $ROOT_DIR->subdir( 'data' );
my $DB = Cath::Schema::Biomap->connect_by_version( $CATH_VERSION );

INFO( "Retrieving basic data for all funfams ... " );
my @FUNFAM_ROWS = get_all_funfam_rows();

my @TASKS = (
  {
    description => "Create a list of the actual FunFams in CATH $CATH_VERSION",
    file => $DATA_DIR->file( 'funfam_names.txt' ),
    operation => \&create_funfam_names,
  },
      
  {
    description => "Create a mapping between uniprot accessions",
    file => $DATA_DIR->file( 'funfam_uniprot_mapping.txt' ),
    operation => \&create_funfam_uniprot_mapping,
  },
  
);

TASK: 
for my $task ( @TASKS ) {
    my $desc = $task->{description};
    my $file = $task->{file};
    my $op   = $task->{operation};
    
    INFO_KV( "TASK", $task->{description} );
    INFO_KV( "FILE", $task->{file}->cleanup );
    
    if ( -e $task->{file} && ! $OVERWRITE_EXISTING_FILES ) {
      INFO( "Output file already exists (skipping task ...)" );
      next TASK;
    }
    
    my $fh = $file->openw();
    $op->( $fh );
    $fh->close;
}

INFO( "Done" );

exit;

####

sub get_all_funfam_rows {
  my $rs = $DB->resultset('Funfam')->remove_text_columns->search( undef, {
    order_by => [qw/ superfamily_id funfam_number /]
  });
  my @rows = map { { funfam_id => get_funfam_id( $_ ), $_->get_columns() } } 
    $rs->all;
  return @rows;
}

sub create_funfam_names {
  my $fh = shift;
  for my $ff ( @FUNFAM_ROWS ) { ### Searching  |===[%]    |
    $fh->printf( "%-30s\t%-8s\t%s\n", get_funfam_id( $ff ), $ff->{name} );
  }
}

sub create_funfam_uniprot_mapping {
  my $fh = shift;
  
  for my $ff ( @FUNFAM_ROWS ) { ### Searching |===[%]    |
    my $ff_id = get_funfam_id( $ff );
    my $rs = $DB->resultset( 'FunfamMember' )->search(
    {
      superfamily_id => $ff->{superfamily_id}, 
      funfam_number  => $ff->{funfam_number},
    }, 
    {
      select   => [qw/ member_id uniprot_entries.uniprot_acc uniprot_entries.description sequence_md5 /],
      as       => [qw/ member_id uniprot_acc description sequence_md5 /],
      join     => [qw/ uniprot_entries /],
      order_by => [qw/ me.sequence_md5 /],
    });
    
    while( my $ff_row = $rs->next ) { 
      $fh->printf( "%-20s\t%-40s\t%-10s\t%s\n", 
        $ff_id, 
        $ff_row->get_column('member_id'),
        $ff_row->get_column('uniprot_acc') || '-',
        $ff_row->get_column('description') || '-',
      );
    }
  }
}

sub get_funfam_id { 
  my $info = shift or die "usage: funfam_id( DBIC_ROW | HASHREF )";
  if ( $info && blessed( $info ) && $info->can('get_columns') ) {
    $info = { $info->get_columns() };
  }
  my $sfam_id = $info->{superfamily_id} or croak "expected 'superfamily_id': " . Dumper( $info ); 
  my $ff_num = $info->{funfam_number} or croak "expected 'funfam_number': " . Dumper( $info ); 
  return "$sfam_id/FF/$ff_num";
}

####

sub INFO {
  my $msg = "@_";
  chomp( $msg );
  print $msg, "\n";
}

sub INFO_KV {
  my ($k, $v) = @_;
  chomp( $v );
  printf "%-15s %s\n", $k . ':', $v;
}

