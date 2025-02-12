#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use Time::Piece;
use Data::UUID;

# Connect to the database
my $dbh = DBI->connect(
    "dbi:SQLite:dbname=db.sqlite", "", "",
    { RaiseError => 1, AutoCommit => 0 }
) or die $DBI::errstr;

my $BATCH_SIZE = 1000;

# clear old data
$dbh->do("DELETE FROM message");
$dbh->do("DELETE FROM log");

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
        id => '',
        flag => '',
        email => '',
        additional_info => ''
    );
    
    # пустая строка - пустой хэш в ответе
    return \%log_entry unless $line;
    
    # разделители - пробелы
    my @parts = split ' ', $line, 6;
    
    # Parse basic fields
    $log_entry{date} = $parts[0] if defined $parts[0];
    $log_entry{time} = $parts[1] if defined $parts[1];
    $log_entry{id} = $parts[2] if defined $parts[2];
    
    # естть ли флаг и адрес
    if (defined $parts[3] && $parts[3] =~ /^(?:<=|=>|->|\*\*|==)$/) {
        $log_entry{flag} = $parts[3];
        my $email_in_4 = defined($parts[4]) && $parts[4]=~/@/;
        $log_entry{email} = $email_in_4 ? parse_email($parts[4]) : parse_email($parts[5]);
        (undef, $log_entry{additional_info}) = $email_in_4 ? ('', $parts[5]) : split ' ', $parts[5], 2;
    } else {
        # нет флага - только общая информация
        $log_entry{additional_info} = join(" ", grep defined, @parts[3..$#parts]);
    }
    
    return \%log_entry;
}

my $c = 1;
# Process maillog file
while (my $line = <>) {
    chomp $line;
    
    # # Create timestamp
    # # my $dt = $parser->parse_datetime("$month $day $time");
    # my $dt = Time::Piece->strptime("$month $day $time $year", "%b %d %H:%M:%S %Y");
    # # $dt->set_year((localtime)[5] + 1900); # Current year
    # my $timestamp = $dt->strftime('%Y-%m-%d %H:%M:%S');

    my $line_h = parse_log_line($line);
    my ($date, $time, $id, $flag, $email) = @$line_h{'date', 'time', 'id', 'flag', '$email'};
    my $int_id = Data::UUID->new->create_hex;
    my $timestamp = "$date $time";
    if ($flag eq '<=') {
        $message_sth->execute(
            $timestamp,
            $id,
            $int_id,
            $line_h->{'additional_info'},
            1  # status default true
        );
    } else {
        #  остальные строки
        $log_sth->execute(
            $timestamp,
            $int_id,
            $line_h->{'additional_info'},
            $email
        );
    }
    if($c % $BATCH_SIZE == 0) {
        $dbh->commit;
        $dbh->begin_work;
    }
}

$dbh->commit;
# Clean up
$message_sth->finish;
$log_sth->finish;
$dbh->disconnect;
