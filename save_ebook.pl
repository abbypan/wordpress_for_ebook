#!/usr/bin/perl
use strict;
use warnings;
#use utf8;

use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Encode;
use Encode::Locale;
use Getopt::Long;
use POSIX qw/strftime/;
use XMLRPC::Lite;

$| = 1;
binmode( STDIN,  ":encoding(console_in)" );
binmode( STDOUT, ":encoding(console_out)" );
binmode( STDERR, ":encoding(console_out)" );

my %opt;
GetOptions(
    \%opt,
    'site|s=s', 'usr|u=s', 'passwd|p=s', 
    'writer|w=s', 'book|b=s', 'date|d=s', 
    'file|f=s', 'remote_dir|r=s', 'ebook_web_path|e=s', 
    'tag|t=s', 'category|c=s', 'msg|m=s', 
);

$opt{writer} ||= 'unknown';
$opt{book} ||= 'unknown';
$opt{msg} ||= '';
$opt{date} = strftime( "%Y%m", localtime ) unless(defined $opt{date} and $opt{date}=~/^\d{4,6}$/);
exit unless(-f $opt{file});
#print Dumper(\%opt);

system(qq[ansible $opt{site} -m shell -a 'mkdir -p $opt{remote_dir}/$opt{ebook_web_path}/$opt{date}/']);
($opt{ftype}) = $opt{file}=~/([^.]+)$/;
$opt{ftype} = lc($opt{ftype});
my $id    = md5_hex("$opt{date}.$opt{writer}.$opt{book}");
my $dst_f = "$opt{remote_dir}/$opt{ebook_web_path}/$opt{date}/$id.$opt{ftype}";
print $dst_f,"\n";
system(qq[ansible $opt{site} -m copy -a 'src=$opt{file} dest=$dst_f']);

my %index = (
    'title'       => "$opt{writer} 《$opt{book}》",
    'description' => qq[<p> $opt{writer}《$opt{book}》： <a download="$opt{writer}-$opt{book}.$opt{ftype}" href="/$opt{ebook_web_path}/$opt{date}/$id.$opt{ftype}">$opt{ftype}</a></p>
    <p>$opt{msg}</p>],
    'mt_keywords' => [ $opt{writer} ],
    'categories'  => [],
);

my $tag_list = $opt{tag} ? [ split /,/, $opt{tag} ] : [];
push @{ $index{mt_keywords} }, @{ $tag_list };
$index{mt_keywords} = join( ", ", @{ $index{mt_keywords} } );

push @{ $index{categories} }, $opt{category};

my $wp = XMLRPC::Lite->proxy("https://$opt{site}/xmlrpc.php");
my $pid = $wp->call( 'metaWeblog.newPost', 1, $opt{usr}, $opt{passwd}, \%index, 1 )->result;
my $post_url = "https://$opt{site}/?p=$pid";
print $post_url,"\n";
