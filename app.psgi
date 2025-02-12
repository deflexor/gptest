#!/usr/bin/env plackup
use v5.20;
use strict;
use warnings;
use Plack::Request;
use DBI;
use HTML::Escape;
use Template::Alloy;

my $tt = Template::Alloy->new;

my $app = sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    
    # Конфигурация БД
    my $dbh = DBI->connect(
        "dbi:SQLite:dbname=db.sqlite", "", "",
        { RaiseError => 1, AutoCommit => 1 }
    ) or die $DBI::errstr;

    # Параметры запроса
    my $address = $req->param('address') || '';
    my ($results, $limit_exceeded);
    
    if ($address) {
        # Поиск данных
        my $query = q{
            (SELECT created, str, int_id FROM log WHERE address = ?)
            UNION ALL
            (SELECT m.created, m.str, m.int_id FROM message m
             JOIN log l ON m.int_id = l.int_id WHERE l.address = ?)
            ORDER BY int_id, created
            LIMIT 101  # Проверка превышения лимита
        };
        
        my $sth = $dbh->prepare($query);
        $sth->execute($address, $address);
        
        # Обработка результатов
        $results = [];
        while (my $row = $sth->fetchrow_hashref) {
            last if @$results >= 100;
            push @$results, {
                created => escape_html($row->{created}),
                str     => escape_html($row->{str})
            };
        }
        
        # Проверка превышения лимита
        $limit_exceeded = $sth->fetch ? 1 : 0;
        $sth->finish;
    }
    
    $dbh->disconnect;
    
    # Генерация HTML
    $tt->process(
        'templates/search.html.ep',
        {
            address       => escape_html($address),
            results       => $results || [],
            limit_exceeded => $limit_exceeded
        },
        \my $output
    );
    
    return [
        200,
        ['Content-Type' => 'text/html; charset=UTF-8'],
        [$output]
    ];
};
