#!/usr/bin/env perl
use strict;
use warnings;
use Plack::Request;
use Plack::Builder;
use DBI;
use Template;
#use DateTime::Format::SQLite;
use Encode qw(decode_utf8 encode_utf8);

my $dbh = DBI->connect("dbi:SQLite:dbname=db.sqlite", "", "", {
    sqlite_unicode => 1,
    RaiseError => 1,
    AutoCommit => 1
});

my $template = Template->new({
    ENCODING => 'utf8',
});

my $app = sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    my $address = $req->param('address');
    
    my $vars = {
        address => $address,
    };
    
    if ($address) {
        my $sql = sub {
            my ($what) = @_;
            $what ||= 'm.created, m.int_id, l.str';
            qq{
                SELECT $what
                FROM message m
                JOIN log l ON m.int_id = l.int_id
                WHERE l.address like ?
                ORDER BY m.int_id, l.created
                LIMIT 101
            };
        };
        
        my $count_sth = $dbh->prepare($sql->('COUNT(*)'));
        $count_sth->execute("%$address%");
        ($vars->{total_count}) = $count_sth->fetchrow_array();

        my $sth = $dbh->prepare($sql->());
        $sth->execute("%$address%");
        
        my @results;
        while (my $row = $sth->fetchrow_hashref) {
            # $row->{created} = DateTime::Format::SQLite->parse_datetime($row->{created})
            #     ->strftime('%Y-%m-%d %H:%M:%S');
            push @results, $row;
        }
        
        if (@results > 100) {
            pop @results;
            $vars->{limit_exceeded} = 'Показаны первые 100 результатов';
        }
        
        $vars->{results} = \@results;
    }
    
    my $output;
    $template->process('templates/search.html.tt', $vars, \$output, { binmode => ':encoding(UTF-8)' })
        or die $template->error;
    
    return [
        200,
        ['Content-Type' => 'text/html; charset=utf-8'],
        [encode_utf8($output)]
    ];
};

builder {
    enable 'Plack::Middleware::Lint';
    enable 'Plack::Middleware::Head';
    $app;
};
