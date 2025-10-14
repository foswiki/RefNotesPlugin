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

use strict;
use warnings;

=begin TML

---+ package Foswiki::Plugins::RefNotesPlugin::Core

core class for this plugin

an singleton instance is allocated on demand

=cut

use Foswiki::Func ();
use Foswiki::Plugins::RefNotesPlugin::Ref ();
use Foswiki::Plugins::RefNotesPlugin::Group ();
#use Data::Dump qw(dump);

=begin TML

---++ =ClassProperty= TRACE

boolean toggle to enable debugging of this class

=cut

use constant TRACE => 0; # toggle me

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

  undef $this->{groups};
  undef $this->{session};
  undef $this->{labelDefinition};
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

  if ($string =~ /^(.)?(1|a|A|x|X|i|I)(.)?$/) {
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
  my $ref = $this->getRef($params);
  return _inlineError("unknown reference") unless defined $ref;

  return $ref->render();
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
  my $doReset = Foswiki::Func::isTrue($params->{reset}, 1) ? 1:0;

  if (defined $groupName) {
    my $group = $this->{groups}{$groupName};
    return "" unless defined $group;

    my $result = $group->render($params);
    $group->reset() if $doReset;

  } else {
    my @result = ();
    foreach my $group (sort {$a->{name} cmp $b->{name}} values %{$this->{groups}}) {
      my $groupResult = $group->render($params);
      push @result, $groupResult if $groupResult;
      $group->reset() if $doReset;
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
  my $text = $params->{_DEFAULT};

  #print STDERR "called getRef(group=$groupName, id=".($id//'undef').", text=".($text//'undef').", hidden=$hidden)\n";

  my $group = $this->getGroup($groupName);

  #print STDERR "group=$group, groupName=$group->{id}, id=$id\n";

  if (defined $text) {
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

  return "<span class='foswikiAlert'>ERROR: $msg</span>";
}

1;
