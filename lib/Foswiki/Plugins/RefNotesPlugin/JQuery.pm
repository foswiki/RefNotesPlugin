# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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

package Foswiki::Plugins::RefNotesPlugin::JQuery;

=begin TML

---+ package Foswiki::Plugins::RefNotesPlugin::JQuery

jQuery perl stub to load the user interface

=cut

use strict;
use warnings;

use Foswiki::Plugins ();
use Foswiki::Plugins::JQueryPlugin::Plugin ();
use Foswiki::Plugins::RefNotesPlugin ();

our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = bless(
    $class->SUPER::new(
      $session,
      name => 'RefNotes',
      version => $Foswiki::Plugins::RefNotesPlugin::VERSION,
      author => 'Michael Daum',
      homepage => 'https://foswiki.org/Extensions/RefNotesPlugin',
      puburl => '%PUBURLPATH%/%SYSTEMWEB%/RefNotesPlugin',
      documentation => '%SYSTEMWEB%.RefNotesPlugin',
      javascript => ['refnotes.js'],
      dependencies => ['ui'],
    ),
    $class
  );


  return $this;
}

1;

