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

package Foswiki::Plugins::RefNotesPlugin::Core;

=begin TML

---+ package Foswiki::Plugins::RefNotesPlugin::Core

core class for this plugin

an singleton instance is allocated on demand

=cut

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins::JQueryPlugin ();
use Foswiki::Plugins::RefNotesPlugin::Ref ();
use Foswiki::Plugins::RefNotesPlugin::Group ();
use Error qw(:try);
#use Data::Dump qw(dump);

use constant TRACE => 0; # toggle me

# package variables. see hasFeature()
our $ROMAN_ENABLED;
our $BIBTEX_ENABLED;

=begin TML

---++ ClassMethod new() -> $core

constructor for a Core object

=cut

sub new {
  my $class = shift;
  my $session = shift;


  my $this = bless({
    groups => {},
    session => $session,
    @_
  }, $class);


  return $this;
}

=begin TML

---++ ObjectMethod finish()

called when this object is destroyed

=cut

sub finish {
  my $this = shift;

  $_->finish() foreach values %{$this->{groups}};
  $this->{importer}->finish() if $this->{importer};

  undef $this->{groups};
  undef $this->{session};
  undef $this->{labelDefinition};
  undef $this->{importer};
}

=begin TML

---++ ObjectMethod hasFeature($type) 

returns true if the given feature is available. Kown types are:

   * bibtex
   * roman

=cut

sub hasFeature {
  my ($this, $type) = @_;

  # test Roman
  if ($type eq 'roman') {
    unless (defined $ROMAN_ENABLED) {
      eval 'use Roman()';
      $ROMAN_ENABLED = $@ ? 0:1;
    }
    return $ROMAN_ENABLED;
  } 

  # test BibTex::Parser
  if ($type eq 'bibtex') {
    unless (defined $BIBTEX_ENABLED) {
      eval 'use BibTeX::Parser(); use Sereal::Decoder(); use Sereal::Encoder ();';
      $BIBTEX_ENABLED = $@ ? 0:1;
    }
    return $BIBTEX_ENABLED;
  }
}

=begin TML

---++ ObjectMethod parseLabelDefinition($string)

parses a label definition and returns a hash of the form

<verbatim>
{
  leftBracket => "(",
  "type" => "1",
  rightBracket => ")",
}
</verbatim>

=cut

sub parseLabelDefinition {
  my ($this, $string) = @_;

  $string //= Foswiki::Func::getPreferencesValue("REFNOTESPLUGIN_LABELFORMAT") // "(1)";

  my %def = (
    leftBracket => "(",
    type => "1",
    rightBracket => ")",
  );

  $string =~ s/^\s+//;
  $string =~ s/\s+//;

  if ($string =~ /^(.)?(1|a|A|x|X|i|I|k|K)(.)?$/) {
    $def{leftBracket} = $1 // "";
    $def{type} = $2;
    $def{rightBracket} = $3 // "";
  }

  #print STDERR "labelDef=".dump(\%def)."\n";


  return \%def;
}

=begin TML

---++ ObjectMethod getLabelDefinition() -> $labelDef

returns the global label definition

=cut

sub getLabelDefinition {
  my $this = shift;

  return $this->{labelDefinition} // $this->parseLabelDefinition();
}

=begin TML

---++ ObjectMethod reset($groupName)

reset the refernce named group

=cut

sub reset {
  my ($this, $groupName) = @_;

  if (defined $groupName) {
    my $group = $this->{groups}{$groupName};
    $group->reset() if defined $group;
  } else {
    foreach my $group (values %{$this->{groups}}) {
      $group->reset();
    }
  }
}

=begin TML

---++ ObjectMethod REF($params, $topic, $web) -> $string

implements the %REF macro

=cut

sub REF {
  my ($this, $params, $topic, $web) = @_;

  _writeDebug("called REF()");
  my $ref;
  my $error;

  try {
    $ref = $this->getRef($params);
    throw Error::Simple("unknown reference") unless defined $ref;
  } catch Error with {
    $error = shift;
  };
  return _inlineError($error) if defined $error;

  Foswiki::Plugins::JQueryPlugin::createPlugin("RefNotes");
  return $ref->render($params);
}

=begin TML

---++ ObjectMethod REFIMPORT($params, $topic, $web) -> $string

implements the %REFIMPORT makro 

=cut

sub REFIMPORT {
  my ($this, $params, $topic, $web) = @_;

  _writeDebug("called REFIMPORT()");
  ($web, $topic) = Foswiki::Func::normalizeWebTopicName($params->{web} // $web, $params->{topic} // $topic);
  my $attachment = $params->{attachment} // $params->{_DEFAULT};

  my $labels = $params->{labels}; 
  my $groupName = $params->{group} // 'default';
  my $group = $this->getGroup($groupName);

  my $error;
  try {
    foreach my $ref (@{$this->importer->getRefsFromBibtex($web, $topic, $attachment)}) {
      $ref->{label} //= $labels;
      $group->addRef($ref);
    }
  } catch Error with {
    $error = shift;
  };

  return _inlineError($error) if $error;

  return "";
}

=begin TML

---++ ObjectMethod importer() -> $importer

returns a reference to an Importer singleton object

=cut

sub importer {
  my $this = shift;

  throw Error::Simple("bibtex feature not available")
    unless $this->hasFeature("bibtex");

  unless ($this->{importer}) {
    require Foswiki::Plugins::RefNotesPlugin::Importer;
    _writeDebug("creating importer");
    throw Error::Simple($@) if $@;

    $this->{importer} = Foswiki::Plugins::RefNotesPlugin::Importer->new($this);
  }

  return $this->{importer};
}

=begin TML

---++ ObjectMethod REFERENCES($params, $topic, $web) -> $string

implements the %REFERENCES macro

=cut

sub REFERENCES {
  my ($this, $params, $topic, $web) = @_;

  _writeDebug("called REFERENCES()");

  my $result = "";
  my $groupName = $params->{group};

  if (defined $groupName) {
    my $group = $this->{groups}{$groupName};
    return _inlineError("unknown group") unless defined $group;

    $result = $group->render($params);

  } else {
    my @result = ();
    foreach my $group (sort {$a->{name} cmp $b->{name}} values %{$this->{groups}}) {
      my $groupResult = $group->render($params);
      push @result, $groupResult if $groupResult;
    }
    return "" unless @result;

    $result = join("", @result);
  }

  my $numGroups = scalar(keys %{$this->{groups}});
  $result =~ s/\$numGroups\b/$numGroups/g;

  return Foswiki::Func::decodeFormatTokens($result);
}

=begin TML

---++ ObjectMethod getRef($params)

returns a ref object. either creates one or returns an already stored one

params:

   * group
   * name
   * _DEFAULT (text)

=cut

sub getRef {
  my ($this, $params) = @_;

  my $ref;

  my $groupName = $params->{group} // 'default';
  my $id = $params->{id};
  my $hidden = Foswiki::Func::isTrue($params->{hidden}, 0) ? 1:0;
  my $overwrite = Foswiki::Func::isTrue($params->{overwrite}, 0) ? 1:0;
  my $text = $params->{text} // $params->{_DEFAULT};

  #print STDERR "called getRef(group=$groupName, id=".($id//'undef').", text=".($text//'undef').", hidden=$hidden)\n";

  my $group = $this->getGroup($groupName);

  #print STDERR "group=$group, groupName=$group->{id}, id=$id\n";

  if (defined $text) {
    throw Error::Simple("id already exists")
      if defined $id && $group->getRef($id) && !$overwrite;
    
    $ref = Foswiki::Plugins::RefNotesPlugin::Ref->new(
      id => $id,
      text => $text,
      hidden => $hidden,
      label => $params->{label},
    );

    $group->addRef($ref);


  } else {
    $ref = $group->getRef($id) if defined $id;
    $group->activateRef($ref) if $ref;
  }

  return $ref;
}

=begin TML

---++ ObjectMethod getGroup($name) -> $group

returns or creates the named group

=cut

sub getGroup {
  my ($this, $name) = @_;

  my $group = $this->{groups}{$name};

  unless (defined $group) {
    $this->{groups}{$name} = $group = Foswiki::Plugins::RefNotesPlugin::Group->new($this,
      name => $name,
    );
  }

  return $group;
}

# statics
sub _writeDebug {
  return unless TRACE;
  print STDERR "RefNotesPlugin::Core - $_[0]\n";
}

sub _inlineError {
  my $msg = shift;

  $msg =~ s/ at .*$//g;
  return "<span class='foswikiAlert'>ERROR: $msg</span>";
}

1;
