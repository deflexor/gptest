#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use DBI;
use HTML::Entities;

my $cgi = CGI->new;
print $cgi->header(-charset => 'UTF-8');

# Параметры подключения к БД
my $db_host = "localhost";
my $db_name = "mydatabase";
my $db_user = "user";
my $db_pass = "password";

# Подключение к БД
my $dbh = DBI->connect(
    "dbi:Pg:dbname=$db_name;host=$db_host",
    $db_user,
    $db_pass,
    { RaiseError => 1, AutoCommit => 1 }
) or die $DBI::errstr;

# Получение и экранирование параметра
my $address = $cgi->param('address') || '';
$address =~ s/'/''/g;  # Простое экранирование для примера

# Формирование HTML
print <<"HTML";
<!DOCTYPE html>
<html>
<head>
    <title>Результаты поиска</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .result-item { margin: 5px 0; padding: 5px; border-bottom: 1px solid #ddd; }
        .limit-msg { color: #ff0000; margin-top: 10px; }
    </style>
</head>
<body>
    <h1>Результаты поиска для: ".encode_entities($address)."</h1>
    <a href="search.html">Новый поиск</a>
HTML

if ($address) {
    # Основной запрос с лимитом
    my $query = qq{
        (SELECT l.created, l.str, l.int_id 
         FROM log l 
         WHERE l.address = ?)
        
        UNION ALL
        
        (SELECT m.created, m.str, m.int_id 
         FROM message m
         JOIN log l ON m.int_id = l.int_id 
         WHERE l.address = ?)
        
        ORDER BY int_id, created
        LIMIT 100
    };

    my $sth = $dbh->prepare($query);
    $sth->execute($address, $address);
    
    # Получение результатов
    my $count = 0;
    while (my $row = $sth->fetchrow_hashref) {
        $count++;
        my $created = encode_entities($row->{created});
        my $str = encode_entities($row->{str});
        print qq(<div class="result-item"><strong>$created</strong> $str</div>\n);
    }
    
    # Проверка превышения лимита
    my $total = $dbh->selectrow_array(qq{
        SELECT COUNT(*) FROM ($query OFFSET 100) AS sub
    }, undef, $address, $address);
    
    if ($total > 0) {
        print qq(<div class="limit-msg">Показано 100 результатов. Найдено дополнительных записей: $total</div>);
    }
    
    $sth->finish;
}

print "</body></html>";
$dbh->disconnect;
