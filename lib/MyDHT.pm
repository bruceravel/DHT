package MyDHT;

=pod

=head1 NAME

MyDHT - Interact with a Raspberry Pi DHT sensor

=head1 VERSION

This documentation refers to version 1.

=head1 SYNOPSIS

Initialize a new database and take a measurement:

   use strict;
   use MyDHT;
   my $dht = MyDHT->new();
   $dht->initialize_database;
   $dht->measure;

Take a new measurement:

   use strict;
   use MyDHT;
   my $dht = MyDHT->new();
   $dht->measure;

Generate plots and a web page:

   use strict;
   use MyDHT;
   my $dht = MyDHT->new();
   $dht->plot("day");
   $dht->plot("week");
   $dht->page;

=head1 DESCRIPTION

This manages the interaction via ssh with a DHT sensor on a Raspberry
Pi which sits in the grow space in my garage.  It fetches the data via
an ssh call, inserts the data into an SQLite database, and generates
plots and a web page based on the accumulated data.

Plots are made with gnuplot abd L<Graphics::GnuplotIF>.  The gnuplot
scritps and the web page are made using L<Text::Template>.  Database
management is via L<DBI>, of course.

Everythings is placed in C<$HOME/.mydht> and is organized for easy
synchonization with AWS via C<awscli>.

=cut

use strict;
use autodie qw(open close);

use Moose;

use DBI;
use DateTime;
use File::Slurp;
use File::Spec;
use Graphics::GnuplotIF;
use JSON::Tiny qw(decode_json);
use List::MoreUtils qw(all);
use List::Util qw(max min);
use Text::Template;

our $VERSION = '1.0.0';

has 'folder'    => (is => 'ro', isa => 'Str', default => '/home/bruce/.mydht');
has 'dbfile'    => (is => 'ro', isa => 'Str', default => 'dht.db');
has 'datetime'  => (is => 'ro', isa => 'DateTime', default => sub {DateTime->now(time_zone=>'America/New_York')});
has 'logfile'   => (is => 'ro', isa => 'Str', default => '/home/bruce/.mydht/old.log');
has 'data'      => (is => 'ro', isa => 'Str', default => 'dht.scratch');
has 'table'     => (is => 'ro', isa => 'Str', default => 'TempHum');

has 't1'        => (is => 'rw', isa => 'Num', default => -99);
has 'hum'       => (is => 'rw', isa => 'Num', default => -99);
has 't2'        => (is => 'rw', isa => 'Num', default => -99);

has 'now'       => (is => 'rw', isa => 'Str', default => q{});
has 'then'      => (is => 'rw', isa => 'Str', default => q{});
has 'ymin'      => (is => 'rw', isa => 'Num', default => 0);
has 'ymax'      => (is => 'rw', isa => 'Num', default => 0);
has 'y2min'     => (is => 'rw', isa => 'Num', default => 0);
has 'y2max'     => (is => 'rw', isa => 'Num', default => 0);
has 'span'      => (is => 'rw', isa => 'Str', default => q{});
has 'file'      => (is => 'rw', isa => 'Str', default => q{});

has 'measurement_period' => (is => 'rw', isa => 'Int', default => 2);
has 'webpage_period' => (is => 'rw', isa => 'Int', default => 10);


=pod

=head1 ATTRIBUTES

=over 4

=item C<folder>  (F<$HOME/.mydht>)

Location of files.

=item C<dbfile>  (F<dht.db>)

Name of database file.

=item C<datetime>

The L<DateTime> object with C<now()> for the beginning of the instance
of the script.

=item C<logfile> (F<old.log>)

Data used to initialize the first database.

=item C<data> (F<dht.scratch>)

A scratch file used to make the plots.

=item C<table> (C<TempHum>)

The name of the table in the database.

=item C<t1>

The temperature reading on the DHT sensor.

=item C<hum>

The humidity reading on the DHT sensor.

=item C<t2>

The temperature reading on the analog sensor.

=item C<now>

The end point of the plot as an ISO8601 date/time string.

=item C<then>

The beginning point of the plot as an ISO8601 date/time string.

=item C<ymin>, C<ymax>

The range of the temperature axis in the plots.

=item C<y2min>, C<y2max>

The range of the relative humidity axis in the plots.

=item C<span>

A text string indicating the length of the plot, used in the title of the plot.

=item C<file>

The name of the output PNG file.

=back

=cut

sub database {
  my ($self) = @_;
  return File::Spec->catfile($self->folder, $self->dbfile);
};
sub datafile {
  my ($self) = @_;
  return File::Spec->catfile($self->folder, $self->data);
};

sub dbconnect {
  my ($self) = @_;
  my $dbh = DBI->connect(
			 "dbi:SQLite:dbname=".$self->database,
			 "",
			 "",
			 { RaiseError => 1 },
			) or die $DBI::errstr;
  return $dbh;
};

=pod

=head1 METHODS

=over 4

=item initialize_database()

Start a new database, inserting the values from F<old.log> as the
first values.

  $self->initialize_database;

=cut

sub initialize_database {
  my ($self) = @_;
  unlink $self->database;
  my $dbh = $self->dbconnect;

  $dbh->do("DROP TABLE IF EXISTS ".$self->table);
  $dbh->do("CREATE TABLE ".$self->table."(DateTime TEXT PRIMARY KEY, T1 REAL, Hum REAL, T2 REAL)");

  my $text = read_file($self->logfile);
  $self->parse($text);

  my $statement = sprintf("INSERT INTO %s VALUES('%s', %.1f, %.1f, %.1f)",
			  $self->table,
			  substr($text, 0, 19),
			  $self->t1,
			  $self->hum,
			  $self->t2);
  $dbh->do($statement);
  $dbh->disconnect();
  return $self;
};

=item measure()

Make a measurement and insert the results into the database.

  $self->measure;

=cut

sub measure {
  my ($self) = @_;
  my $dbh = $self->dbconnect;

  my $text = $self->probe;
  $self->parse($text);

  my $statement = sprintf("INSERT INTO %s VALUES('%s', %.1f, %.1f, %.1f)",
			  $self->table,
			  $self->datetime->iso8601(),
			  $self->t1,
			  $self->hum,
			  $self->t2);
  $dbh->do($statement);
  $dbh->disconnect();
  return $self;
};

=item probe()

Grab the temperature and humidity data from the Raspberry Pi via ssh.

  my $text = $self->probe;

=cut

sub probe {
  my ($self) = @_;
  my $text = `/usr/bin/ssh -i /home/bruce/.ssh/id_rsa_dht pi\@192.168.1.9 'cd /home/pi/play/temp && sudo python growspace_th.py'`;
  return $text;
};

=item parse()

Parse the text returned from the ssh call and load the C<t1>, C<hum>,
and C<t2> attributes.

=cut

sub parse {
  my ($self, $text) = @_;
  $self->t1(-99);
  $self->hum(-99);
  $self->t2(-99);
  if ($text =~ m{T:(\d+\.\d+)F}) {
    $self->t1($1);
  }
  if ($text =~ m{H:(\d+\.\d+)}) {
    $self->hum($1);
  }
  if ($text =~ m{T2:(\d+\.\d+)}) {
    $self->t2($1);
  }
  return $self;
};

=item fetch_array()

Get a named array from the SQLite database with all data since
C<$beginning>, where C<$beginning> is an ISO8601 datetime string.

  my $array_reference = fetch($which, $beginning);

=cut


sub fetch_array {
  my ($self, $which, $beginning) = @_;
  my $dbh  = $self->dbconnect;
  my $aref = $dbh->selectcol_arrayref("SELECT $which FROM TempHum WHERE DateTime>'$beginning'");
  $dbh->disconnect();
  return $aref;
};

=item plot()

Generate a PNG plot of the DHT data for the last day, week, or month.
The PNG file will be written to C<$self-E<gt>folder>.

  $self->plot($timespan);

=cut

sub plot {
  my ($self, $which) = @_;

  print "Making $which plot\n";
  my %period = (day=>1, week=>7, month=>30);
  $self->now($self->datetime->clone->add(minutes=>10)->iso8601);
  $self->then($self->datetime->clone->subtract(days=>$period{$which})->iso8601);

  my @time = @{ $self->fetch_array("DateTime", $self->then) };
  my @t1   = @{ $self->fetch_array("T1",       $self->then) };
  my @hum  = @{ $self->fetch_array("Hum",      $self->then) };
  my @t2   = @{ $self->fetch_array("T2",       $self->then) };

  ## this bit could be easier with PDL...
  my @drop;
  foreach my $i (0 .. $#time) {
    push(@drop, $i) if (($t1[$i]<-1) or ($hum[$i]<-1) or ($t2[$i]<-1));
  };
  foreach my $i (reverse @drop) {
    splice(@time, $i, 1);
    splice(@t1,   $i, 1);
    splice(@hum,  $i, 1);
    splice(@t2,   $i, 1);
  };
  open(my $DAT, '>', $self->datafile);
  foreach my $i (0 .. $#time) {
    printf $DAT "%s  %.1f  %.1f  %.1f\n", $time[$i], $t1[$i], $hum[$i], $t2[$i];
  };
  close $DAT;

  $self->ymin(min(@t1, @t2) - 5);
  $self->ymax(max(@t1, @t2) + 5);
  $self->y2min(min(@hum) - 5);
  $self->y2max(max(@hum) + 5);
  my %span = (day => '24 hours', week => '7 days', month => '30 days');
  $self->span($span{$which});
  $self->file($which . '.png');

  my $template = Text::Template->new(TYPE => 'file', SOURCE => File::Spec->catfile($self->folder, "plot.tmpl"))
    or die "Couldn't construct template: $Text::Template::ERROR";
  my $string = $template->fill_in(HASH => {S=>\$self});
  #print $string;
  my $plot = Graphics::GnuplotIF->new();
  $plot->gnuplot_cmd($string);
  ##$plot->gnuplot_pause;
  unlink $plot->{__error_log};
  undef $plot;
};

=item page()

Generate an HTML plot of the DHT data.  The HTML file will be written
to C<$self-E<gt>folder>.

  $self->page;

=cut

sub page {
  my ($self, $text) = @_;
  print "Making HTML page\n";
  (my $json_text = read_file(File::Spec->catfile($self->folder, "plants.json"))) =~ s{$/}{ }g;
  my $json = decode_json($json_text);

  $text ||= $self->probe;
  $self->parse($text);
  my ($t1, $h, $t2) = ($self->t1, $self->hum, $self->t2);
  my ($p1, $p2) = ($self->measurement_period, $self->webpage_period);

  my $time = $self->datetime->iso8601();

  my $template = Text::Template->new(TYPE => 'file', SOURCE => File::Spec->catfile($self->folder, "page.tmpl"))
    or die "Couldn't construct template: $Text::Template::ERROR";
  my $string = $template->fill_in(HASH => {t1 => \$t1, h => \$h,
					   t2 => \$t2, time => \$time,
					   json => \$json,
					   measurement_period => \$p1,
					   webpage_period => \$p2,
					  });

  open(my $PAGE, '>', File::Spec->catfile($self->folder, 'web', 'DHT.html'));
  print $PAGE $string;
  close $PAGE;
  return $self;
};

=pod

=back

=head1 DEPENDENCIES

=over 4

=item L<Moose>

=item L<DBI>

=item L<DateTime>

=item L<File::Slurp>

=item L<Graphics::GnuplotIF>

=item L<Text::Template>

=item L<List::Util>

=item L<List::MoreUtils>

=item L<File::Spec>

=back

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Well, still figuring that out ...

=back

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

L<http://bruceravel.github.io/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

1;
