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

package Foswiki::Plugins::RefNotesPlugin::Group;

use strict;
use warnings;

use Foswiki::Func ();

=begin TML

---+ package Foswiki::Plugins::RefNotesPlugin::Group

=cut

=begin TML

---++ ClassMethod new($core) -> $group

constructor for a Core object

=cut

sub new {
  my $class = shift;
  my $core = shift;

  my $this = bless({
    core => $core,
    refs => {},
    index => 1,
    name => "default",
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

  $this->reset();
  undef $this->{core};
}

=begin TML

---++ ObjectMethod render($params) -> $string

formats a reference group

=cut

sub render {
  my ($this, $params) = @_;

  my $format = $params->{format} // '<tr id="$id"><th>$label</th><td> $text </td></tr>';
  my $showHidden = Foswiki::Func::isTrue($params->{showhidden}, 0);

  my @result = ();
  my $num = 1;
  foreach my $ref (sort {$a->{index} <=> $b->{index} or $a->{text} cmp $b->{text}} values %{$this->{refs}}) {
    next if $ref->{hidden} && !$showHidden;

    my $index = $ref->{index} || $num++;
    my $line = $format;
    my $id = $ref->getAnchor($index);
    my $label = $ref->getLabel($index);

    $line =~ s/\$index\b/$index/g;
    $line =~ s/\$label\b/$label/g;
    $line =~ s/\$id\b/$id/g;
    $line =~ s/\$text\b/$ref->{text}/g;

    push @result, $line;
  }
  return "" unless @result;

  my $groupName = $this->{name};
  my $header = $params->{header} // ($format eq "" ? "" : "<table class='foswikiLayoutTable refNotes \$group'>");
  my $footer = $params->{footer} // ($format eq "" ? "" : "</table>");
  my $separator = $params->{separator} // "";

  my $result = $header . join($separator, @result) . ($footer);

  my $groupTitle = $params->{$groupName . "_title"} // ($groupName eq "default" ? "References" : ucfirst($groupName));
  #print STDERR "groupTitle=$groupTitle, groupName='$groupName'\n";
  $result =~ s/\$count\b/$this->{index}/g;
  $result =~ s/\$group\b/$groupName/g;
  $result =~ s/\$title\b/$groupTitle/g;

  return $result;
}

=begin TML

---++ ObjectMethod addRef($ref) -> $this

adds a ref object to this group

=cut

sub addRef {
  my ($this, $ref) = @_;

  my $index = $ref->{hidden} ? 0 : $this->{index}++;
  $ref->{id} //= "refLink$index";
  $ref->{index} = $index;
  $ref->{group} = $this;

  $this->{refs}{$ref->{id}} = $ref;

  return $this;
}

=begin TML

---++ ObjectMethod getRef($name) -> $ref

returns a ref object if found in this group

=cut

sub getRef {
  my ($this, $name) = @_;

  return $this->{refs}{$name};
}

=begin TML

---++ ObjectMethod getName()

returns the group's name

=cut

sub getName {
  return $_[0]->{name};
}

=begin TML

---++ ObjectMethod getCore()

returns a reference to the Core object

=cut

sub getCore {
  return $_[0]->{core};
}

=begin TML

---++ ObjectMethod activateRef($ref)

activates a hidden group and adds them to the index

=cut

sub activateRef {
  my ($this, $ref) = @_;

  if ($ref->{hidden}) {
    my $index = $this->{index}++;
    $ref->{hidden} = 0;
    $ref->{index} = $index;
    $ref->{id} //= "refLink$index";
  }

  return $ref;
}

=begin TML

---++ ObjectMethod reset()

finishes all refs stored in this group and resets the index

=cut

sub reset {
  my $this = shift;

  $_->finish() foreach values %{$this->{refs}};
  $this->{refs} = {};
  $this->{index} = 1;

  return $this;
}

1;
