#!/bin/perl
#                              -*- Mode: Perl -*- 
# Makefile.PL -- 
# ITIID           : $ITI$ $Header $__Header$
# Author          : Ulrich Pfeifer
# Created On      : Thu Apr 11 11:11:45 1996
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Thu Apr 11 11:11:54 1996
# Language        : Perl
# Update Count    : 1
# Status          : Unknown, Use with caution!
# 
# (C) Copyright 1996, Universität Dortmund, all rights reserved.
# 
# $Locker$
# $Log$
# 

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	   => 'Pconvert',
    'VERSION_FROM' => 'pconvert.PL', # finds $VERSION
    'dist'         => { SUFFIX => "gz", COMPRESS => "gzip -f"},
    'EXE_FILES'    => [ 'pconvert' ],
    'MAN3PODS'     => { '' => 1},
    'SKIP'         => [qw(linkext)],
    'clean'        => {FILES => 'pconvert'},
);

sub MY::postamble {
    my $self = shift;
    
#    $self->manifypods() . "\n" .
    "linkext:\n\t".$self->{NOECHO}.'$(NOOP)'."\n";
}
