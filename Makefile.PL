#!/bin/perl
#                              -*- Mode: Perl -*- 
# Makefile.PL -- 
# ITIID           : $ITI$ $Header $__Header$
# Author          : Ulrich Pfeifer
# Created On      : Thu Apr 11 11:11:45 1996
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Thu Feb  6 18:03:51 1997
# Language        : Perl
# Update Count    : 5
# Status          : Unknown, Use with caution!
# 
# (C) Copyright 1996, Universität Dortmund, all rights reserved.
# 
# $Locker:  $
# $Log: Makefile.PL,v $
# Revision 1.2  1997/02/06 17:07:20  pfeifer
# Will install in INSTALLBIN instead of INSTALLSCRIPT since the configuration
# will be architecture dependant in general.
#
# Revision 1.1  1997/02/06 16:48:32  pfeifer
# switched to CVS
#
# 

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	   => 'Pconvert',
    'VERSION_FROM' => 'pconvert.PL', # finds $VERSION
    'dist'         => { SUFFIX => "gz", COMPRESS => "gzip -f"},
    'EXE_FILES'    => [ 'pconvert' ],
    'INSTALLSCRIPT' => '$(INSTALLBIN)',
    'MAN3PODS'     => { '' => 1},
    'SKIP'         => [qw(linkext)],
    'clean'        => {FILES => 'pconvert'},
);

sub MY::postamble {
    my $self = shift;
    
#    $self->manifypods() . "\n" .
    "linkext:\n\t".$self->{NOECHO}.'$(NOOP)'."\n";
}
