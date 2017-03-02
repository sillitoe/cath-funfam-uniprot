#!/usr/bin/env perl

# core
use strict;
use warnings;
use FindBin;
use Sys::Hostname;
use Getopt::Long;
use Data::Dumper;
use Scalar::Util qw/ blessed /;
use Carp qw/ croak /;

# cpan
use Path::Class;
use Smart::Comments;
use Bio::SeqIO;

# local
use Cath::Schema::Biomap;

my $CATH_VERSION = 'v4_1_0';
my $OVERWRITE_EXISTING_FILES = 0;
my $ONLY_HEADERS = 0;
$| = 1;

GetOptions(
  'force' => \$OVERWRITE_EXISTING_FILES,
  'only-headers' => \$ONLY_HEADERS,
);

# complain if we haven't committed local changes before generating data
check_local_changes();

my $ROOT_DIR = dir( "$FindBin::Bin/../" );
my $DATA_DIR = $ROOT_DIR->subdir( 'data' );
my $DB = Cath::Schema::Biomap->connect_by_version( $CATH_VERSION );

INFO( "Retrieving basic data for all funfams ... " );
my @FUNFAM_ROWS = get_all_funfam_rows();

my @TASKS = (
  {
    description => "Create a list of the FunFam names in CATH $CATH_VERSION",
    file => "funfam_names.$CATH_VERSION.tsv",
    operation => sub {
      my $fh = shift;
      for my $ff ( @FUNFAM_ROWS ) { ### Searching  |===[%]    |
        $fh->printf( "%-30s\t%-8s\t%s\n", get_funfam_id( $ff ), $ff->{name} );
      }      
    },
    col_titles => [qw/ FUNFAM_ID NAME /],
  },
      
  {
    description => "Create a mapping between uniprot accessions in CATH $CATH_VERSION",
    file => "funfam_uniprot_mapping.$CATH_VERSION.tsv",
    operation => \&create_funfam_uniprot_mapping,
    col_titles => [qw/ FUNFAM_ID MEMBER_ID UNIPROT_ACC DESCRIPTION /],
  },
  
);

my $task_counter = 0;
TASK: 
for my $task ( @TASKS ) {

  $task_counter++;
  
  my $desc = $task->{description};
  my $file = $DATA_DIR->file( $task->{file} );
  my $op   = $task->{operation};
  
  INFO();
  INFO( sprintf "TASK %d: %s", $task_counter, $task->{description} );
  INFO( "DATA_FILE => ", $file->cleanup );
  
  if ( -e $file ) {
    if ( $OVERWRITE_EXISTING_FILES ) {
      INFO( "WARNING: Output file already exists (OVERWRITING)" );      
    }
    else {
      INFO( "WARNING: Output file already exists (SKIPPING TASK)" );
      next TASK;
    }
  }
  
  my $fh = $file->openw()
    or die "! Error: failed to open $file for writing: $!";
  
  INFO( "Writing headers..." );
  write_data_headers( $fh, $task );

  if ( $ONLY_HEADERS ) {
    INFO( "Only printing headers (SKIPPING TASK)" );
    next TASK;
  }

  INFO( "Writing data..." );
  $op->( $fh );
  $fh->close;
}

INFO( "DONE" );

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

sub check_local_changes {
  my $local_changes_since_last_commit = `git status --porcelain $0`;
  die "! Error: steadfastly refusing to generate data files until local changes have been committed to git:\n\n$local_changes_since_last_commit\n\n"
    if $local_changes_since_last_commit;  
}

sub get_last_commit_info {
  my $git_out = `git log -1`;
  $git_out =~ /commit\s+(\S+)/mg or die "failed to get git commit";
  my $git_commit = $1;
  $git_out =~ /Author:\s+(.*)\n/mg or die "failed to get git author";
  my $git_author = $1;
  $git_out =~ /Date:\s+(.*)\n/mg or die "failed to get git date";
  my $git_date = $1;

  return {
    commit => $git_commit,
    date => $git_date,
    author => $git_author,
  }
}

sub write_data_headers {
  my ($fh, $task) = @_;

  my $task_file = file( $task->{file} )->basename;
  my $task_description = $task->{description};
  my $task_col_titles = $task->{col_titles};
      
  my $generated_by = getpwuid($<);
  my $generated_hostname = hostname();
  my $generated_script = file( $0 )->basename;
  my $generated_date = "" . localtime();
  
  my $kv = sub {
    $fh->printf( "# %-15s %s\n", $_[0], $_[1] );
  };

  $kv->( 'FILE',        $task_file );
  $kv->( 'DESCRIPTION', $task_description );
  $kv->( 'CREATED_BY',  $generated_by );
  $kv->( 'GENERATED',   $generated_date );
  $kv->( 'HOSTNAME',    $generated_hostname );
  $kv->( 'GIT_LAST_COMMIT', $git_commit . " ($git_date)" );
  $kv->( 'FORMAT',      join( "\t", @$task_col_titles ) );
}

sub INFO {
  my $msg = "@_";
  chomp( $msg );
  print $msg, "\n";
}

