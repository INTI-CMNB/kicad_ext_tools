#!/usr/bin/perl
##############################################################################
#
# Copyright (c) 2013 David M. Caruso <daviud en inti gov ar>
# Copyright (c) 2013 Instituto Nacional de Tecnología Industrial
#
##############################################################################
#
# Target:           Any
# Language:         Perl
# Interpreter used: v5.6.1/v5.8.4
# Text editor:      SETEdit 0.5.5
#
##############################################################################
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
# 02111-1307, USA
#
##############################################################################
#
# Description: BGA Schematic and Footprint Generator for Kicad
#
##############################################################################

#Usar una hash, para barrer los datos
#para el footprint barrer bolita por bolita.

use POSIX qw(strftime);
use Sort::Versions;
use List::Util qw(first);

use Getopt::Long;
use Locale::TextDomain('kicad_tools');
$version='1.0.1';

ParseCommandLine();
#use constant AGE => 2;
$fecha = strftime "%e/%m/%Y-%H:%M:%S", localtime;

%kicadel = ('Input/Output','B',
            'Power Input','W',
            'NC','N',
            'Input','I',
            'Output','O',
            'Input Clock','I C',
            'Input Clock Negated','I IC',
            'Input Negated','I I',
            'Output Negated','O I',
            'Input/Output Negated','B I',
            'Output Clock','O C',
            'Output Clock Negated','O IC',
            'Tri-state Negated','T I',
            'Tri-state','T',
            'Passive','P'
           );

$ind_field=0;
@exfield;
@namexfield;
$maxXball=0;
$maxYball=0;
@padlet=('A','B','C','D','E','F','G','H','J','K','L','M','N','P','R','T','U','V','W','Y');
$timestamp=sprintf "%8.8lX", time;

#-----------------------------------------------------------------------------
# Read File and order data
#-----------------------------------------------------------------------------
open(F,"$filein") || die "Can't open $filein";

while ($line=<F>)
  {
   if ($line=~/\"([^\"]*)\",\"([^\"]*)\",\"([^\"]*)\",\"([^\"]*)\",\"([^\"]*)\",([^\"]*),/)
     {
      $pin_ord=$1;
      $pin_name=$2;
      $pin_io=$3;
      $pin_sgrp=$4;
      $pin_grp=$5;
      unless ($6) {if ($ldie){print "** line = \"$line\"\n"; die "** Error: No define L die\n";}}
      $pin_ldie=$6;
      $pin_ldie=~s/,//g; #quita cualquier coma existente
      if ($pin_ord=~/(\d+)/)
        {
         if ($1>$maxXball){$maxXball=$1}; # Busca el máximo valor en X
        }
      if ($pin_ord=~/(\D+)/)
        {
         @letras=split("",$1);
         $let_ind = (first { $padlet[$_] eq $letras[0] } 0..$#padlet) + 1;
         if ($#letras>0){$let_ind=((first { $padlet[$_] eq $letras[1] } 0..$#padlet)+1)+($#padlet+1)*$let_ind;}
         if ($maxYball<$let_ind)
           {
            $maxYball=$let_ind;
           }
         if (length($1)>1) {$pin_ord='Z'."$pin_ord";}
        }
      push(@Ll,"$pin_ord;-;$pin_name;-;$pin_io;-;$pin_sgrp;-;$pin_grp;-;$pin_ldie"); # array a ordenar para el esquemático
          #print "$pin_ord;-;$pin_name;-;$pin_io;-;$pin_sgrp;-;$pin_grp;-;$pin_ldie\n"
     }
   else
     {
      if ($line=~/\"([^\"]*)\",\"([^\"]*)\",,,,,,/)
        {
         $exfield[$ind_field]=$2;
         $namexfield[$ind_field]=$1;
         print "Field: $1: $2\n";
         $ind_field++;
        }
      else
        {
         if (!$line=~/\bPin/)
         {print "** line = \"$line\"\n"; die "** Error de parseo en el CSV\n";}
        }
     }
  }
close $F;
$balls=$#Ll+1;
print "Reading: $balls balls\n";
print "there are: x=$maxXball y=$maxYball balls\n";
#Orden de los datos parseados
$pin_ord=0;
$pin_name=1;
$pin_io=2;
$pin_sgrp=3;
$pin_grp=4;
$pin_ldie=5;
#-----------------------------------------------------------------------------
# Footprint .mod
#-----------------------------------------------------------------------------
open(S,">$outdir\/$lib\.mod") || die "Can't create $outdir\/$lib\.mod";
print S "PCBNEW-LibModule-V1  $fecha\n".
        "Units mm\n".
        "\$INDEX\n$lib\n\$EndINDEX\n".
        "\$MODULE $lib\n";
# Config Constants:
#$sep = 300;        # Separation pin
$txtsig=0.1016;        # Text Size
#$rad=90;           # Radius for pad
#$clearence=50;     # Clearence for pad
#$widthmod;         # Width of module
#$heightmod;        # Height of module

$dpad = $dpad;
$bga_pitch = $bga_pitch;
$rsizex = ($maxXball*$bga_pitch)/2;     # Component width
$rsizey = ($maxYball*$bga_pitch)/2;

print S "Po 0 0 0 15 $timestamp $timestamp ~~\n".
        "Li $lib\n". # Nombre del módulo
        "Cd $nameexfield[1]\n". # Descripción del módulo
        "Sc $timestamp\n".
        "AR\n".
        "Op 0 0 0\n".
        "At SMD\n";


$yaux=-$rsizey;

# Ordeno por grupo de señal, luego por subgrupo, luego por nombre de señal
#@Ll = sort {$a cmp $b} @Ll;
@Ll = sort {versioncmp($a,$b)} @Ll;
#@Ll = sort {lc($a) cmp lc($b)} @Ll;
### VER QUE PUEDE TENER HUECOS EL BGA Y SI BARRO CONTINUO ME PUEDO SALTEAR UNO. CAPAZ QUE ES NECESARIO SEGUIRLO COMO ANTES

$ind=0;
for ($y_ind=0;$y_ind<$maxYball;$y_ind++)
   {
    $xaux=-$rsizex;
    if ($y_ind>$#padlet)
	  {
        $let_ind="$padlet[($y_ind/($#padlet+1))-1]"."$padlet[($y_ind%($#padlet+1))]";
      }
    else 
      {
        $let_ind="$padlet[$y_ind]";
      }
    for ($x_ind=1;$x_ind<=$maxXball;$x_ind++)
      {
       $ball_ind="$let_ind"."$x_ind";
       @colm=split(";-;",$Ll[$ind]);
       $colm[$pin_ord]=~s/Z//g; # Quita la Z agregada para el orden.
       if ($colm[$pin_ord] eq $ball_ind) # Existe la bolita?
         {
          print S "\$PAD\n".
                  "Sh \"$colm[$pin_ord]\" C $dpad $dpad 0 0 0\n".
                  "Dr 0 0 0\n".  # Drill
                  "At SMD N 00888000\n";
          if ($withnet && ($colm[$pin_io] ne 'NC'))
            {
             print S "Ne 0 \"$colm[$pin_name]\"\n";
            }
          print S "Po $xaux $yaux\n";
          if ($clearence)
            {
             print S "$clearencetxt\n";
            }
          if ($ldie)
            {
             print S "Le $colm[$pin_ldie]\n";
            }
          print S "\$EndPAD\n";
          $ind++;
         }
       $xaux=$xaux+$bga_pitch;
      }
    $yaux=$yaux+$bga_pitch;
   }

$lineEXl = -$rsizex-$bga_pitch;
$lineEXr = -$rsizex+$maxXball*$bga_pitch;
$lineEYu = -$rsizey-$bga_pitch;
$lineEYd = -$rsizey+$maxYball*$bga_pitch;

print S "DS $lineEXl $lineEYu $lineEXr $lineEYu 0.1016 21\n".
        "DS $lineEXr $lineEYu $lineEXr $lineEYd 0.1016 21\n".
        "DS $lineEXr $lineEYd $lineEXl $lineEYd 0.1016 21\n".
        "DS $lineEXl $lineEYd $lineEXl $lineEYu 0.1016 21\n";

$lineEYu -=0.7112;
$lineEYd +=0.7112;
print S "T0 0 $lineEYu 0.7112 0.4572 0 0.1016 N H 21 N\"$lib\"\n".
        "T1 0 $lineEYd 0.7112 0.4572 0 0.1016 N H 21 N\"REF**\"\n";

#External Mark
$lineEYd = $lineEYu - int($bga_pitch/2);
$lineEYu = $lineEYd - $bga_pitch;
$lineEXr = $lineEXl - int($bga_pitch/2);
$lineEXl = $lineEXr - $bga_pitch;

print S "DS $lineEXl $lineEYd $lineEXr $lineEYd 0.1016 21\n".
        "DS $lineEXr $lineEYd $lineEXr $lineEYu 0.1016 21\n".
        "DS $lineEXr $lineEYu $lineEXl $lineEYd 0.1016 21\n";
#model 3D
print S "\$SHAPE3D\n".
        "Na \"smd/generic_bga.wrl\"\n".
        "Sc 0.900000 0.900000 1.000000\n".
        "Of 0.000000 0.000000 0.000000\n".
        "Ro 0.000000 0.000000 0.000000\n".
        "\$EndSHAPE3D\n";

print S "\$EndMODULE  $lib\n".
        "\$EndLIBRARY";
 close S;

0;

sub to_dmils
{
 int($_[0]*393.700787);
}

sub to_mm
{
 int($_[0]/393.700787);
}

#-----------------------------------------------------------------------------
# ParseCommandLine:
#   Parser
#-----------------------------------------------------------------------------

sub ParseCommandLine
{
 GetOptions("verbose|v=i"   => \$verbosity,
            "version"       => \$showVersion,
            "input=s"       => \$filein,
            "dir=s"         => \$outdir,
            "dpad=f"        => \$dpad,
            "ldie"          => \$ldie,
            "pitch=f"       => \$bga_pitch,
            "clearence=f"   => \$clearence,
            "withnet"       => \$withnet,
            "lib=s"         => \$lib,
            "help|?"        => \$help) or ShowHelp();
 if ($showVersion)
   {
    print "bga_gen.pl (kicad_tools) $version\n".
          "Copyright (c) 2013 David M. Caruso/INTI\n".
          "License GPLv2: GNU GPL version 2 <http://gnu.org/licenses/gpl.html>\n".
          __("This is free software: you are free to change and redistribute it.\n".
             "There is NO WARRANTY, to the extent permitted by law.\n\n").
          __("Written by")." David M. Caruso.\n";
    exit(0);
   }
 print "BGA Schematic and Footprint Generator for Kicad v$version Copyright (c) 2013 David M. Caruso/INTI\n";
 ShowHelp() if $help;
 unless($filein)
   {
    print "You must specify an input file name.\n";
    ShowHelp();
   }
 unless($lib)
   {
    print "You must specify an library name.\n";
    ShowHelp();
   }
 unless($dpad)
   {
    print "You must specify a Diammeter for ball in mm.\n";
    ShowHelp();
   }
 unless($bga_pitch)
   {
    print "You must specify an pitch between balls in mm.\n";
    ShowHelp();
   }
 if ($clearence)
   {
    $clearence=int($clearence*393.700787);
    $clearencetxt = ".LocalClearance $clearence\n";
   }
 if ($outdir && !(-e "$outdir"))
   {
    system "mkdir $outdir";
   }
 unless ($outdir)
   {
    $outdir='.'; # Si no se especifica el directorio, asigna el actual
   }
 unless ($cwidth)
   {
    $cwidth = 900;
   }

}

sub ShowHelp
{
 print __"Usage: bga_gen.pl [options]\n";
 print __"\nAvailable options:\n";
 print __"--version            Outputs version information and exit.\n";
 print __"--input=name         Input File with ball description\n";
 print __"--dir=name           Output Directory for component, Default=Current\n";
 print __"--lib=name           Library Name\n";
 print __"--dpad=value         Diammeter for ball (mm)\n";
 print __"--ldie               Length of connection from die to pin, extracted from csv file (dmils)\n";
 print __"--pitch=value        Pitch between balls (mm)\n";
 print __"--clearence=value    Clearence for balls (mm)\n";
 print __"--withnet            Include Net names in mod file\n";
 print __"--help               Prints this text.\n\n";

 exit 1;
}
