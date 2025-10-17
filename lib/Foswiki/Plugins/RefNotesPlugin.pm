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

package Foswiki::Plugins::RefNotesPlugin;

=begin TML

---+ package Foswiki::Plugins::RefNotesPlugin

plugin class to hook into the foswiki core

=cut

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins::JQueryPlugin ();

our $VERSION = '0.51';
our $RELEASE = '%$RELEASE%';
our $SHORTDESCRIPTION = 'Footnotes for Foswiki';
our $LICENSECODE = '%$LICENSECODE%';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean

initialize the plugin, automatically called during the core initialization process

=cut

sub initPlugin {

  Foswiki::Func::registerTagHandler('REF', sub { return getCore(shift)->REF(@_); });
  Foswiki::Func::registerTagHandler('REFERENCES', sub { return getCore(shift)->REFERENCES(@_); });
  Foswiki::Plugins::JQueryPlugin::registerPlugin('RefNotes', 'Foswiki::Plugins::RefNotesPlugin::JQuery');

  return 1;
}

=begin TML

---++ finishPlugin

finish the plugin and the core if it has been used,
automatically called during the core initialization process

=cut

sub finishPlugin {
  $core->finish() if $core;
  undef $core;
}

=begin TML

---++ getCore() -> $core

returns a singleton core object for this plugin

=cut

sub getCore {
  my $session = shift || $Foswiki::Plugins::SESSION;

  unless (defined $core) {
    require Foswiki::Plugins::RefNotesPlugin::Core;
    $core = Foswiki::Plugins::RefNotesPlugin::Core->new($session);
  }
  return $core;
}

1;
