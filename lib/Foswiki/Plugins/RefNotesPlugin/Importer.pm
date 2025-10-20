# Plugin for Foswiki - The Free and Open Source Wiki, https://foswiki.org/
#
# RefNotesPlugin is Copyright (C) 2025 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::RefNotesPlugin::Importer;

=begin TML

---+ package Foswiki::Plugins::RefNotesPlugin::Importer

import references from bibtex

=cut

use strict;
use warnings;

use Foswiki::Func ();
use BibTeX::Parser;
use IO::File;
use LaTeX::ToUnicode ();
use Encode ();
use Error ();
use Sereal::Encoder ();
use Sereal::Decoder ();
use Digest::MD5 ();

=begin TML

---++ =ClassProperty= TRACE

boolean toggle to enable debugging of this class

=cut

use constant TRACE => 0; # toggle me

=begin TML

---++ ClassMethod new() -> $core

constructor for a ref object

=cut

sub new {
  my $class = shift;
  my $core = shift;

  my $this = bless({
    core => $core,
    @_
  }, $class);

  return $this;
}

=begin TML

---++ ObjectMethod finish() 

called when destructing the session

=cut

sub finish {
  my $this = shift;

  undef $this->{core};
}

=begin TML

---++ ObjectMethod getCore()

returns a reference to the Core object

=cut

sub getCore {
  return $_[0]->{core};
}

=begin TML

---++ ObjectMethod parser(fileName) -> $parser

returns a bibtex parser for the given file 

=cut

sub parser {
  my ($this, $file) = @_;

  throw Error::Simple("bibtex file not found") unless -e $file;

  my $fh = IO::File->new($file);
  my $parser = BibTeX::Parser->new($fh);

  return $parser;
}

=begin TML

---++ ObjectMethod getRefsFromBibtex($web, $topic, $attachments) -> $refs

returns a list of Ref objects imported from a bibtex file. this
either reads the bibtex file itself or the cached version of it.

=cut

sub getRefsFromBibtex {
  my ($this, $web, $topic, $attachment) = @_;

  _writeDebug("called getRefsFromBibtex($web, $topic, $attachment");


  throw Error::Simple("bibtex topic $web.$topic not found")
    unless Foswiki::Func::topicExists($web, $topic);

  throw Error::Simple("bibtex attachment not found")
    unless Foswiki::Func::attachmentExists($web, $topic, $attachment);

  my $wikiName = Foswiki::Func::getWikiName();
  throw Error::Simple("access denied")
    unless Foswiki::Func::checkAccessPermission("VIEW", $wikiName, undef, $topic, $web);

  my $request = Foswiki::Func::getRequestObject();
  my $refresh = $request->param("refresh") // "";
  $refresh = ($refresh =~ /^(on|bibtex)/) ? 1 :0;

  my $bibFile = $Foswiki::cfg{PubDir} . "/" . $web . "/" . $topic . "/" . $attachment;
  my $bibModified = _getModificationTime($bibFile);
  _writeDebug("bibFile=$bibFile");

  my $cacheFile = $this->getFileForBibtex($web, $topic, $attachment);
  my $cacheModified = _getModificationTime($cacheFile);
  _writeDebug("cacheFile=$cacheFile");

  my $refs;
  if ($refresh || $bibModified > $cacheModified) {
    $refs = $this->importBibtex($web, $topic, $attachment);
    _writeDebug("storing to $cacheFile");
    Sereal::Encoder->encode_to_file($cacheFile, $refs);
  } else {
    _writeDebug("reading from $cacheFile");
    $refs = Sereal::Decoder->decode_from_file($cacheFile);
  }

  return $refs;
}

=begin TML

---++ ObjectMethod getFileForBibtex($web, $topic, $attachment) -> $filename

returns the filename of a bibtex file

=cut

sub getFileForBibtex {
  my ($this, $web, $topic, $attachment) = @_;

  $web =~ s/\//./g;
  my $file = Digest::MD5::md5_hex($web.'::'.$topic.'::'.$attachment) . '.sereal';
  return Foswiki::Func::getWorkArea("RefNotesPlugin"). "/$file";
}

=begin TML

---++ ObjectMethod importBibtex($web, $topic, $attachment) -> $refs

reads the bibtex file in the give attachment

=cut

sub importBibtex {
  my ($this, $web, $topic, $attachment) = @_;

  my $file = $Foswiki::cfg{PubDir} . "/" . $web . "/" . $topic . "/" . $attachment;

  _writeDebug("called importBibtex($file)");

  my @result = ();

  my $parser = $this->parser($file);

  my %params = ();
  while (my $entry = $parser->next) {
    if ($entry->parse_ok) {

      my $key = $entry->key() // 'undef';
      my $type = $entry->type();
      _writeDebug("reading key $key, type=$type");

      $params{id} = $key;
      $params{hidden} = "on";
      $params{text} = "";
      
      # author 
      my @list = ();
      #_writeDebug("reading author");
      my @authors = $entry->author;
      foreach my $person (@authors) {
        push @list, _cleanString($person->to_string);
      }
      if (@list) {
        my $res = join(" and ", @list);
        $res .= "." unless $res =~ /\.$/;
        $res .= " ";
        $params{text} .= $res;
      }

      # editor
      @list = ();
      my @editors = $entry->editor;
      my $editors = "";
      foreach my $person (@editors) {
        push @list, _cleanString($person->to_string);
      }
      if (@list) {
        $editors = join(" and ", @list);
        $editors .= " editors. ";
        $params{text} .= $editors unless ($entry->field("booktitle") || $entry->field("series") || $entry->field("journal"));
      }

      # title
      #_writeDebug("reading title");
      my $title = _cleanField($entry, "title");
      my $url = $entry->field("url");
      if ($url) {
        # TODO: support more formats of referencing an attachment url
        $url = $Foswiki::cfg{PubUrlPath} . "/$web/$topic/$url" unless $url =~ /^https?:/;
        $params{text} .= "<a href='$url'><em>$title</em></a>. ";
      } else {
        $params{text} .= "<em>" . $title . "</em>. ";
      }

      # types
      $params{text} .= "PhD thesis, " if $type eq "PHDTHESIS";

      # common fields
      foreach my $key (qw(school series booktitle journal publisher optpublisher institution address month volume type number pages year)) {
        my $val = _cleanField($entry, $key);
        next unless $val;

        if ($key =~ /^(booktitle|series|journal)$/) {
          $params{text} .= "In " if $val !~ /^(Series|In) /;
          $params{text} .= "$val. ";
          if ($editors) {
            $params{text} .= $editors;
            $editors = "";
          }
          next;
        }

        $params{text} .= "pages " if $key eq 'pages';
        $params{text} .= "volume " if $key eq 'volume';

        $params{text} .= "$val. ";
      }

    } else {
      warn "Error parsing file: " . $entry->error;
    }

    push @result, Foswiki::Plugins::RefNotesPlugin::Ref->new(%params);

  }

  return \@result;
}

# statics
sub _writeDebug {
  return unless TRACE;
  print STDERR "RefNotesPlugin::Import - $_[0]\n";
}

sub _cleanField {
  my ($entry, $name) = @_;

  my $string = $entry->field($name);
  return _cleanString($string);
}

sub _cleanString {
  my $string = shift;

  return "" unless defined $string;

  return LaTeX::ToUnicode::convert($string, html => 1);
  #return Encode::encode_utf8($string);
}

sub _getModificationTime {
  my $path = shift;

  return 0 unless $path;

  my @stat = stat($path);

  return $stat[9] || $stat[10] || 0;
}

1;
