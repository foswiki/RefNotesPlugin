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

use Foswiki::Func ();

use constant TRACE => 0; # toggle me

our $ROMAN_ENABLED;

BEGIN {
  eval 'use Roman()';
  $ROMAN_ENABLED = $@ ? 0 : 1;
}

sub new {
  my $class = shift;

  my @labelBrackets = ("(", ")");
  my $labelFormat = Foswiki::Func::getPreferencesValue("REFNOTESPLUGIN_LABELFORMAT") // "(1)";
  $labelFormat =~ s/^\s+//;
  $labelFormat =~ s/\s+//;

  if ($labelFormat =~ /^(.)?(1|a|A|x|X|i|I)(.)?$/) {
    $labelBrackets[0] = $1 // "";
    $labelFormat = $2;
    $labelBrackets[1] = $3 // "";
  }

  my $this = bless({
    groups => {
      default => {
        refs => {},
        index => 1,
        name => "default",
      }
    },
    labelFormat => $labelFormat,
    labelBrackets => \@labelBrackets,
    @_
  }, $class);


  return $this;
}

sub finish {
  my $this = shift;

  $this->clearRefs();

  undef $this->{groups};
  undef $this->{labelFormat};
  undef $this->{labelBrackets};
}

sub clearRefs {
  my ($this, $groupName) = @_;

  if (defined $groupName) {
    my $group = $this->{group}{$groupName};
    return unless defined $group;
    $group->{refs} = [];
    $group->{index} = 1;
  } else {
    foreach my $group (values %{$this->{groups}}) {
      $group->{refs} = [];
      $group->{index} = 1;
    }
  }
}

sub REF {
  my ($this, $session, $params, $topic, $web) = @_;

  _writeDebug("called REF()");
  my $result = '';

  my $ref = $this->getRef($params->{name}, $params->{_DEFAULT}, $params->{group});
  return _inlineError("unknown reference") unless defined $ref;

  return $this->formatRef($ref);
}

sub getRef {
  my ($this, $name, $text, $groupName) = @_;

  my $ref;

  $groupName //= 'default';
  my $group = $this->{groups}{$groupName};

  unless (defined $group) {
    $this->{groups}{$group} = $group = {
      refs => {},
      index => 1,
      name => $groupName,
    };
  }

  if (defined $text) {
    my $index = $group->{index}++;
    $name //= "refLink$index";

    $ref = {
      name => $name,
      index => $index,
      text => $text,
      groupName => $groupName,
    };

    $group->{refs}{$name} = $ref;

  } else {
    $ref = $group->{refs}{$name} if defined $name;
  }

  return $ref;
}

sub getLabel {
  my ($this, $ref) = @_;

  my $label;

  _writeDebug("called getLabel with format='$this->{labelFormat}'");

  # alphabet
  $label = chr((ord 'a') + ($ref->{index} - 1)) if $this->{labelFormat} eq 'a';
  $label = chr((ord 'A') + ($ref->{index} - 1)) if $this->{labelFormat} eq 'A';

  # roman
  if ($ROMAN_ENABLED) {
    $label = Roman::roman($ref->{index}) if $this->{labelFormat} eq 'i';
    $label = Roman::Roman($ref->{index}) if $this->{labelFormat} eq 'I';
  }

  # hexadecimal
  $label = sprintf("0x%x", $ref->{index}) if $this->{labelFormat} eq 'x';
  $label = sprintf("0X%X", $ref->{index}) if $this->{labelFormat} eq 'X';

  # arabic numerals
  $label = $ref->{index} unless defined $label;

  # add brackets
  $label = $this->{labelBrackets}[0] . $label . $this->{labelBrackets}[1];

  _writeDebug("getLabel() - $label");

  return $label;
}

sub formatRef {
  my ($this, $ref) = @_;

  my $label = $this->getLabel($ref);
  $label = $ref->{groupName} . " " . $label unless $ref->{groupName} eq 'default';

  my $anchor = $this->getAnchor($ref);

  return "<sup class='refLink foswikiSmall'><a href='#$anchor' class='foswikiNoDecoration'>$label</a></sup>";
}

sub getAnchor {
  my ($this, $ref) = @_;

  my $anchor = "refNote";
  $anchor .= "_$ref->{groupName}" if $ref->{groupName} ne 'default';
  $anchor .= "_$ref->{index}";

  return $anchor;
}

sub REFERENCES {
  my ($this, $session, $params, $topic, $web) = @_;

  _writeDebug("called REFERENCES()");

  my $result = "";
  my $groupName = $params->{group};

  if (defined $groupName) {
    my $group = $this->{groups}{$groupName};
    return "" unless defined $group;

    my $result = $this->formatGroup($group, $params);
    $this->clearRefs($groupName) if Foswiki::Func::isTrue($params->{clear}, 1);

  } else {
    my @result = ();
    foreach my $group (sort {$a->{name} cmp $b->{name}} values %{$this->{groups}}) {
      my $groupResult = $this->formatGroup($group, $params);
      push @result, $groupResult if $groupResult;
    }
    return "" unless @result;

    $result = join("", @result);
    $this->clearRefs() if Foswiki::Func::isTrue($params->{clear}, 1);
  }

  my $numGroups = scalar(keys %{$this->{groups}});
  $result =~ s/\$numGroups\b/$numGroups/g;

  return Foswiki::Func::decodeFormatTokens($result);
}

sub formatGroup {
  my ($this, $group, $params) = @_;

  return "" unless defined $group;

  my $format = $params->{format} // '<li id="$name"><b>$label</b> $text </li>';

  #print STDERR "called formatGroup($group->{name})\n";

  my @result = ();
  foreach my $ref (sort {$a->{index} <=> $b->{index}} values %{$group->{refs}}) {
    my $line = $format;
    my $label = $this->getLabel($ref);
    my $name = $this->getAnchor($ref);

    $line =~ s/\$index\b/$ref->{index}/g;
    $line =~ s/\$label\b/$label/g;
    $line =~ s/\$name\b/$name/g;
    $line =~ s/\$text\b/$ref->{text}/g;

    push @result, $line;
  }
  return "" unless @result;

  my $groupName = $group->{name};
  my $header = $params->{header} // ($format eq "" ? "" : "<ul class='refNotes foswikiNoBullets \$group'>");
  my $footer = $params->{footer} // ($format eq "" ? "" : "</ul>");
  my $separator = $params->{separator} // "";

  my $result = $header . join($separator, @result) . ($footer);

  my $groupTitle = $params->{$groupName . "_title"} // ($groupName eq "default" ? "References" : ucfirst($groupName));
  #print STDERR "groupTitle=$groupTitle, groupName='$groupName'\n";
  $result =~ s/\$count\b/$group->{index}/g;
  $result =~ s/\$group\b/$groupName/g;
  $result =~ s/\$title\b/$groupTitle/g;

  return $result;
}

sub _writeDebug {
  return unless TRACE;
  print STDERR "RefNotesPlugin::Core - $_[0]\n";
}

sub _inlineError {
  my $msg = shift;

  return "<span class='foswikiAlert'>ERROR: $msg</span>";
}

1;
