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

package Foswiki::Plugins::RefNotesPlugin::Ref;

use strict;
use warnings;

=begin TML

---+ package Foswiki::Plugins::RefNotesPlugin::Group

=cut


=begin TML

---++ =ClassProperty= ROMAN_ENABLED

boolean true if the Roman package is installed

=cut

our $ROMAN_ENABLED;

BEGIN {
  eval 'use Roman()';
  $ROMAN_ENABLED = $@ ? 0 : 1;
}

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

  my $this = bless({
    id => "refLink",
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

  undef $this->{group};
}

=begin TML

---++ ObjectMethod render()

formats a given ref

=cut

sub render {
  my ($this, $params) = @_;

  return "" if $this->{hidden};

  my $label = $this->getLabel();
  my $groupName = $this->getGroupName();
  $label =  "$groupName " . $label unless $groupName eq 'default';

  my $showTooltip = Foswiki::Func::isTrue($params->{tooltip}, 1);
  my $class = "refLink foswikiSmall";
  $class .= " refLinkWithTooltip" if $showTooltip;

  my $anchor = $this->getAnchor();

  return "<sup class='$class'><a href='#$anchor' class='foswikiNoDecoration'>$label</a></sup>";
}

=begin TML

---++ ObjectMethod getLabel($index) -> $string

generates a link label for the given ref

=cut

sub getLabel {
  my ($this, $index) = @_;

  my $label;
  my $def = $this->getLabelDefinition();
  $index ||= $this->{index};

  # alphabet
  if ($def->{type} eq 'a' || $def->{type} eq 'A') {
    $label = "";
    my $start = ord($def->{type});
    my $div;
    my $rem = $index - 1;
    do {
      $div = int($rem / 26);
      $rem = $rem % 26;
      $label .= chr($start + $rem);
      $div--;
      $rem = $div * 26;
    } while ($div >= 0);
    $label = reverse $label;
  } 

  # roman
  if ($ROMAN_ENABLED) {
    $label = Roman::roman($index) if $def->{type} eq 'i';
    $label = Roman::Roman($index) if $def->{type} eq 'I';
  }

  # hexadecimal
  $label = sprintf("0x%x", $index) if $def->{type} eq 'x';
  $label = sprintf("0X%X", $index) if $def->{type} eq 'X';

  # arabic numerals fallback
  $label //= $index;

  # add brackets
  $label = $def->{leftBracket} . $label . $def->{rightBracket};

  _writeDebug("getLabel() - $label");

  return $label;
}

=begin TML

---++ ObjectMethod getLabelDefinition()

gets the local or global label definition

=cut

sub getLabelDefinition {
  my $this = shift;

  return $this->{labelDefinition} // $this->getCore->parseLabelDefinition($this->{label})
    if defined $this->{label};

  return $this->getCore->getLabelDefinition();
}

=begin TML

---++ ObjectMethod getAnchor($index) -> $string

returns the anchor name for a ref

=cut

sub getAnchor {
  my ($this, $index) = @_;

  $index ||= $this->{index};

  my $anchor = "refNote";
  my $groupName = $this->getGroupName();
  $anchor .= "_$groupName" if $groupName ne 'default';
  $anchor .= "_$index";

  return $anchor;
}

=begin TML

---++ ObjectMethod getGroup() -> $group

returns a reference to the group this ref is part of

=cut

sub getGroup {
  return $_[0]->{group};
}

=begin TML

---++ ObjectMethod getGroupName() -> $string

returns the name of the group this ref is part of 

=cut

sub getGroupName {
  return $_[0]->getGroup->getName();
}

=begin TML

---++ ObjectMethod getCore() -> $core

returns a reference to the Core object

=cut

sub getCore {
  return $_[0]->getGroup->getCore();
}

# statics
sub _writeDebug {
  return unless TRACE;
  print STDERR "RefNotesPlugin::Ref - $_[0]\n";
}

1;
