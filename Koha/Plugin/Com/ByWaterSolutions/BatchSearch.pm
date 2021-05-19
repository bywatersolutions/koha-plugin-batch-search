package Koha::Plugin::Com::ByWaterSolutions::BatchSearch;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Auth;
use C4::Search;
use MARC::Record;
use List::MoreUtils qw/uniq/;
use C4::Koha;
use Koha::DateUtils;

## Here we set our plugin version
our $VERSION = "{VERSION}";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name   => 'Batch Search',
    author => 'Nick Clemens',
    description => 'This plugin searches your system for a list of terms',
    date_authored   => '2016-02-25',
    date_updated    => '2016-02-25',
    minimum_version => '3.18',
    maximum_version => undef,
    version         => $VERSION,
};

## This is the minimum code required for a plugin's 'new' method
##iMore can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}


## The existance of a 'report' subroutine means the plugin is capable
## of running a report. This example report can output a list of patrons
## either as HTML or as a CSV file. Technically, you could put all your code
## in the report method, but that would be a really poor way to write code
## for all but the simplest reports
sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('output') ) {
        $self->report_step1();
    }
    else {
       $self->report_step2();
    }
}


## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
    my ( $self, $args ) = @_;

    my $table = $self->get_qualified_table_name('mytable');

    return C4::Context->dbh->do( "
        CREATE TABLE  $table (
            `borrowernumber` INT( 11 ) NOT NULL
        ) ENGINE = INNODB;
    " );
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
    my ( $self, $args ) = @_;

    my $table = $self->get_qualified_table_name('mytable');

    return C4::Context->dbh->do("DROP TABLE $table");
}

## These are helper functions that are specific to this plugin
## You can manage the control flow of your plugin any
## way you wish, but I find this is a good approach
sub report_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'report-step1.tt' });

    print $cgi->header();
    print $template->output();
}

sub report_step2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $dbh = C4::Context->dbh;

    my $output = $cgi->param('output');
    my $search_terms = $cgi->param('search_terms');
    my $test_isbns = $cgi->param('test_isbns');

    push my @term_list, uniq( split(/\s\n/,$search_terms) );

    my @results;
    my @ignore;

    foreach my $term ( @term_list ){
        if( length($term) < 10 ) {
            push @ignore, $term;
            next;
        }
        my $query = $test_isbns && GetVariationsOfISBNs($term) ? join " OR ", map { "isbn:".$_ } GetVariationsOfISBNs($term) : "isbn:".$term;
        my $searcher = Koha::SearchEngine::Search->new({index => $Koha::SearchEngine::BIBLIOS_INDEX});
        my ($err,$res,$used) = $searcher->simple_search_compat( $query, 0, undef );
        my @biblionumbers;
        my ( $biblionumber_tag, $biblionumber_subfield ) = C4::Biblio::GetMarcFromKohaField( "biblio.biblionumber", "" );
        if ( $err ) {
            my $err = { term => $term, title => "Error when searching: ".$err };
            push @results, $err;
            next;
        }
        if ( @$res ){
            foreach my $result ( @$res ){
                $result = MARC::Record::new_from_xml($result) unless ( C4::Context->preference('SearchEngine') eq 'Elasticsearch' );
                my $id = ( $biblionumber_tag > 10 ) ?
                $result->field($biblionumber_tag)->subfield($biblionumber_subfield) :
                   $result->field($biblionumber_tag)->data();
                my $biblio =  Koha::Biblios->find( $id );
                if ( $biblio ) {
                    my $items = $biblio->items;
                    $biblio = $biblio->unblessed;
                    $biblio->{term} = $term;
                    $biblio->{item_count} = $items->count;
                    $biblio->{first_item} = $items->next;
                }
                push @results, $biblio;
            }
        } else {
            my $no_found = { term => $term, title => "No results found for this term" };
            push @results, $no_found;
        }
    }
    my $filename;
    if ( $output eq "csv" ) {
        my $filedate = output_pref({dt=>dt_from_string(),dateonly=>1,dateformat=>'sql'});
        print $cgi->header( -attachment => 'batch_search_report_'.$filedate.'.csv' );
        $filename = 'report-step2-csv.tt';
    }
    else {
        print $cgi->header();
        $filename = 'report-step2-html.tt';
    }

    my $template = $self->get_template({ file => $filename });

    $template->param(
        results_loop => \@results,
        ignore_loop  => \@ignore,
    );

    print $template->output();
}

1;
