#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use Time::Piece;

# Connect to the database
my $dbh = DBI->connect(
    "dbi:SQLite:dbname=db.sqlite", "", "",
    { RaiseError => 1, AutoCommit => 1 }
) or die $DBI::errstr;

# Prepare SQL statements
my $message_sth = $dbh->prepare(
    "INSERT INTO message (created, id, int_id, str, status) VALUES (?, ?, ?, ?, ?)"
);

my $log_sth = $dbh->prepare(
    "INSERT INTO log (created, int_id, str, address) VALUES (?, ?, ?, ?)"
);

sub parse_email {
    my ($str) = @_;
    return "" unless $str;
    if ($str =~ /[<]?([^<>]+)[>]?/) {
        return $1;
    }
    return "";
}

sub parse_log_line {
    my ($line) = @_;
    
    # Initialize hash to store parsed data
    my %log_entry = (
        date => '',
        time => '',
        message_id => '',
        flag => '',
        email => '',
        additional_info => ''
    );
    
    # Return empty hash if line is empty
    return \%log_entry unless $line;
    
    # Split line by spaces for initial parsing
    my @parts = split ' ', $line, 6;
    
    # Parse basic fields
    $log_entry{date} = $parts[0] if defined $parts[0];
    $log_entry{time} = $parts[1] if defined $parts[1];
    $log_entry{message_id} = $parts[2] if defined $parts[2];
    
    # Check if we have flag and email fields
    if (defined $parts[3] && $parts[3] =~ /^(?:<=|=>|->|\*\*|==)$/) {
        $log_entry{flag} = $parts[3];
        my $email_in_4 = defined($parts[4]) && $parts[4]=~/@/;
        $log_entry{email} = $email_in_4 ? parse_email($parts[4]) : parse_email($parts[5]);
        (undef, $log_entry{additional_info}) = $email_in_4 ? ('', $parts[5]) : split ' ', $parts[5], 2;
    } else {
        # If no flag, combine remaining parts as additional info
        $log_entry{additional_info} = join(" ", grep defined, @parts[3..$#parts]);
    }
    
    return \%log_entry;
}


# Process maillog file
while (my $line = <>) {
    chomp $line;
    
    # Parse timestamp
    # my $year = '1900';
    # my ($month, $day, $time, $rest) = $line =~ /^(\w+)\s+(\d+)\s+(\d+:\d+:\d+)\s+(.*)$/;
    # print "!!! $month, $day, $time\n";
    # next unless $month && $day && $time && $rest;
    
    # # Create timestamp
    # # my $dt = $parser->parse_datetime("$month $day $time");
    # my $dt = Time::Piece->strptime("$month $day $time $year", "%b %d %H:%M:%S %Y");
    # # $dt->set_year((localtime)[5] + 1900); # Current year
    # my $timestamp = $dt->strftime('%Y-%m-%d %H:%M:%S');

    my $line_h = parse_log_line($line);
    use Data::Dumper;
    warn $line . "\n";
    warn Dumper($line_h);
    last;
    my ($month, $day, $time, $rest) = @$line_h{'date', 'date', 'time', 'message_id'};
    my $timestamp = $line_h->{'date'} . ' ' . $line_h->{'time'};
    # Extract internal ID
    my ($int_id) = $rest =~ /\[([A-F0-9]+)\]/;
    next unless $int_id;
    
    if ($rest =~ /<=/) {
        # Message arrival - parse for message table
        my ($id) = $rest =~ /id=([^\s]+)/;
        next unless $id;
        
        $message_sth->execute(
            $timestamp,
            $id,
            $int_id,
            $rest,
            1  # status default true
        );
    } else {
        # Other log entries - parse for log table
        my ($address) = $rest =~ /to=<([^>]+)>/;
        
        $log_sth->execute(
            $timestamp,
            $int_id,
            $rest,
            $address
        );
    }
}

# Clean up
$message_sth->finish;
$log_sth->finish;
$dbh->disconnect;
