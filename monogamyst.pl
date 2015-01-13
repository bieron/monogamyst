#!/usr/bin/perl
use strict; use warnings;

#a running Firefox instance with MozRepl addon required
use lib '/home/jb5195/perl/lib/perl5';
use WWW::Mechanize::Firefox;
use Mojo::UserAgent;
use Mojo::DOM;
use Data::Dump 'pp';
use Encode 'decode';
use Carp;

my$archive_file = $0;
#simple way for keeping the archive in the same directory as this executable
$archive_file =~ s|[^/]+$|cicho_sha|;

if (@ARGV < 1) {
    printf STDERR 'usage: %s user_id', $0;
    exit 1;
}

my$ua = Mojo::UserAgent->new();
my $id = $ARGV[0];
my$res = $ua->get('http://forum.polygamia.pl/profile/?area=showposts;u='.$id)->res;


if ( int($res->{code}/100) != 2 ) {
    carp pp $res->{content};
    carp 'code: ' . $res->{code};
    exit 1;
}

my$last_comment;
if (open my$f, '<', $archive_file) {
    local$/ = undef;
    $last_comment = <$f>;
    close $f;
    #so that different encodings won't break comparison with currently fetched by $ua
    #also, reading charset from response Content-Type didn't help much, as it seems Mojo keeps all its strings in UTF-8
    $last_comment = decode('UTF-8', $last_comment);
} else {
    croak $! if system('touch', $archive_file);
}
$last_comment //= '';

#TODO for longer comments should follow a link to the full comment instead of viewing the snapshot provided
#my$comment = $res->dom->find('li.comment p')->[0]->text;
my$comment = $res->dom->find('.list_posts')->[0]->all_text;
#$comment =~ s|<div class="quoteheader".+?<div class="botslice_quote"></div></div>||g;
$comment = Encode::decode('UTF-8', Encode::encode('UTF-8', $comment));
#$comment = Mojo::DOM->new($comment)->all_text;

if ($last_comment ne $comment) {
    local$\ = undef;#default, but still
    open my$f, '>', $archive_file or croak $!;
    print $f $comment;
    close $f;

    #system(sprintf q/echo '%s' |festival --tts/, $comment); #just no
    my$mech = WWW::Mechanize::Firefox->new();
    $mech->allow(images => 0);#speed it up
    $mech->get('http://www.ivona.com/pl');
    $comment =~ s/["'()\n]//g;#escape
#    print $comment . "\n";
#Ivona can only read up to 250 chars in one go.
#TODO Iteratively supply her with (sensibly) divided parts to read the whole thing
    $comment = substr $comment, 0, 250;

    my$js = <<"SCRIPT";
document.getElementById('VoiceTesterForm_text').value = "$comment";
document.getElementById('voiceTesterLogicpbut').click();
SCRIPT
    $mech->events(['load']);
#    $mech->autoclose_tab( 0 );
    $mech->eval_in_page($js);
    sleep 30;#dumb way of keeping tab open until Ivona finishes talking; seems like more than enough
}
