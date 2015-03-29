# NAME

MyDHT - Interact with the Raspberry Pi DHT sensor in my grow room

# VERSION

This documentation refers to version 1.

# SYNOPSIS

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

# DESCRIPTION

This manages the interaction via ssh with a DHT sensor on a Raspberry
Pi which sits in the grow space in my garage.  It fetches the data via
an ssh call, inserts the data into an SQLite database, and generates
plots and a web page based on the accumulated data.

Plots are made with gnuplot abd [Graphics::GnuplotIF](https://metacpan.org/pod/Graphics::GnuplotIF).  The gnuplot
scritps and the web page are made using [Text::Template](https://metacpan.org/pod/Text::Template).  Database
management is via [DBI](https://metacpan.org/pod/DBI), of course.

Everythings is placed in `$HOME/.mydht` and is organized for easy
synchonization with AWS via `awscli`.

See `config/plants.json` for a list of the plants in my grow room.
"Herbs, not herb!"

# ATTRIBUTES

- `folder`  (`$HOME/.mydht`)

    Location of files.

- `dbfile`  (`dht.db`)

    Name of database file.

- `datetime`

    The [DateTime](https://metacpan.org/pod/DateTime) object with `now()` for the beginning of the instance
    of the script.

- `logfile` (`old.log`)

    Data used to initialize the first database.

- `data` (`dht.scratch`)

    A scratch file used to make the plots.

- `table` (`TempHum`)

    The name of the table in the database.

- `t1`

    The temperature reading on the DHT sensor.

- `hum`

    The humidity reading on the DHT sensor.

- `t2`

    The temperature reading on the analog sensor.

- `now`

    The end point of the plot as an ISO8601 date/time string.

- `then`

    The beginning point of the plot as an ISO8601 date/time string.

- `ymin`, `ymax`

    The range of the temperature axis in the plots.

- `y2min`, `y2max`

    The range of the relative humidity axis in the plots.

- `span`

    A text string indicating the length of the plot, used in the title of the plot.

- `file`

    The name of the output PNG file.

# METHODS

- initialize\_database()

    Start a new database, inserting the values from `old.log` as the
    first values.

        $self->initialize_database;

- measure()

    Make a measurement and insert the results into the database.

        $self->measure;

- probe()

    Grab the temperature and humidity data from the Raspberry Pi via ssh.

        my $text = $self->probe;

- parse()

    Parse the text returned from the ssh call and load the `t1`, `hum`,
    and `t2` attributes.

- fetch\_array()

    Get a named array from the SQLite database with all data since
    `$beginning`, where `$beginning` is an ISO8601 datetime string.

        my $array_reference = fetch($which, $beginning);

- plot()

    Generate a PNG plot of the DHT data for the last day, week, or month.
    The PNG file will be written to `$self->folder`.

        $self->plot($timespan);

- page()

    Generate an HTML plot of the DHT data.  The HTML file will be written
    to `$self->folder`.

        $self->page;

# DEPENDENCIES

- [Moose](https://metacpan.org/pod/Moose)
- [DBI](https://metacpan.org/pod/DBI)
- [DateTime](https://metacpan.org/pod/DateTime)
- [File::Slurp](https://metacpan.org/pod/File::Slurp)
- [Graphics::GnuplotIF](https://metacpan.org/pod/Graphics::GnuplotIF)
- [Text::Template](https://metacpan.org/pod/Text::Template)
- [List::Util](https://metacpan.org/pod/List::Util)
- [List::MoreUtils](https://metacpan.org/pod/List::MoreUtils)
- [File::Spec](https://metacpan.org/pod/File::Spec)

# BUGS AND LIMITATIONS

- Well, still figuring that out ...

# AUTHOR

Bruce Ravel ([http://bruceravel.github.io/home](http://bruceravel.github.io/home))

[http://bruceravel.github.io/demeter/](http://bruceravel.github.io/demeter/)

# LICENCE AND COPYRIGHT

Copyright (c) 2015 Bruce Ravel ([http://bruceravel.github.io/home](http://bruceravel.github.io/home)). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See [perlgpl](https://metacpan.org/pod/perlgpl).

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
