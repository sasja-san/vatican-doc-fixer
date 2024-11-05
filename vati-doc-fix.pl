#!/usr/bin/perl

use warnings;
use strict;
use ojo;

my $page = g('file://./ede.html')->dom;

# Create anchors for all sup tags after notes
my $notes = $page->find('p[align=center] b')->grep(sub {$_->text =~ /^NOTES$/})->first->parent;
for my $r ($notes->following_nodes->@*) {
  # Prepend anchor to ref tag
  $r->find('sup')->map(sub { $_->attr(id => "Reference_" . $_->text) });
}

# Now create links to references
for my $l ($notes->preceding_nodes->@*) {
  $l->find('sup')->map(sub {
      # Remove any trailing spaces
      my $ref = $_->text;
      $ref =~ s/\s+$//;
      next unless ($ref =~ /^\d+$/);

      # Convert into a hyperlink
      $_->replace(Mojo::DOM->new_tag('a', href => "#Reference_$ref", $ref));
  })
}

say $page->to_string;
