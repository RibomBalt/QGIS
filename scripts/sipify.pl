#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;

use constant PRIVATE => 0;
use constant PROTECTED => 1;
use constant PUBLIC => 2;

# TODO add contexts for
# "multiline function signatures"
# docustrings for QgsFeature::QgsAttributes

sub processDoxygenLine
{
    my $line = $_[0];
    # remove \a formatting
    $line =~ s/\\a //g;
    # replace :: with . (changes c++ style namespace/class directives to Python style)
    $line =~ s/::/./g;
    # replace nullptr with None (nullptr means nothing to Python devs)
    $line =~ s/\bnullptr\b/None/g;
	# replace \returns with :return:
	$line =~ s/\\return(s)?/:return:/g;

    if ( $line =~ m/[\\@](ingroup|class)/ ) {
        return ""
    }
    if ( $line =~ m/\\since .*?([\d\.]+)/i ) {
        return ".. versionadded:: $1\n";
    }
    if ( $line =~ m/[\\@]note (.*)/ ) {
        return ".. note::\n\n   $1\n";
    }
    if ( $line =~ m/[\\@]brief (.*)/ ) {
        return " $1\n";
    }
    return $line;
}


my $headerfile = $ARGV[0];

open(my $header, "<", $headerfile) || die "Couldn't open '".$headerfile."' for reading because: ".$!;

# contexts
my $SIP_RUN = 0;
my $HEADER_CODE = 0;
my $ACCESS = PUBLIC;
my $MULTILINE_DEFINITION = 0;

my $comment = '';
my $nesting_index = 0;
my $private_section_line = '';
my $line;
my $classname = '';
my $return_type = '';
my %qflag_hash;

print  "/************************************************************************\n";
print  " * This file has been generated automatically from                      *\n";
print  " *                                                                      *\n";
printf " * %-*s *\n", 68, $headerfile;
print  " *                                                                      *\n";
print  " * Do not edit manually ! Edit header and run scripts/sipify.pl again   *\n";
print  " ************************************************************************/\n";


while(!eof $header){
    $line = readline $header;
    #print $line;

    if ($line =~ m/^\s*SIP_FEATURE\( (\w+) \)(.*)$/){
        print "%Feature $1$2\n";
        next;
    }
    if ($line =~ m/^\s*SIP_IF_FEATURE\( (\!?\w+) \)(.*)$/){
        print "%If ($1)$2\n";
        next;
    }
    if ($line =~ m/^\s*SIP_CONVERT_TO_SUBCLASS_CODE(.*)$/){
        print "%ConvertToSubClassCode$1\n";
        next;
    }

    if ($line =~ m/^\s*SIP_END(.*)$/){
        print "%End$1\n";
        next;
    }

    # Skip preprocessor stuff
    if ($line =~ m/^\s*#/){
        if ( $line =~ m/^\s*#ifdef SIP_RUN/){
            $SIP_RUN = 1;
            if ($ACCESS == PRIVATE){
                print $private_section_line
            }
            next;
        }
        if ( $SIP_RUN == 1 ){
            if ( $line =~ m/^\s*#endif/ ){
                if ( $nesting_index == 0 ){
                    $SIP_RUN = 0;
                    next;
                }
                else {
                    $nesting_index--;
                }
            }
            if ( $line =~ m/^\s*#if(def)?\s+/ ){
                $nesting_index++;
            }

            # if there is an else at this level, code will be ignored i.e. not SIP_RUN
            if ( $line =~ m/^\s*#else/ && $nesting_index == 0){
                while(!eof $header){
                    $line = readline $header;
                    if ( $line =~ m/^\s*#if(def)?\s+/ ){
                        $nesting_index++;
                    }
                    elsif ( $line =~ m/^\s*#endif/ ){
                        if ( $nesting_index == 0 ){
                            $SIP_RUN = 0;
                            last;
                        }
                        else {
                            $nesting_index--;
                        }
                    }
                }
                next;
            }
        }
        elsif ( $line =~ m/^\s*#ifndef SIP_RUN/){
            # code is ignored here
            while(!eof $header){
                $line = readline $header;
                if ( $line =~ m/^\s*#if(def)?\s+/ ){
                    $nesting_index++;
                }
                elsif ( $line =~ m/^\s*#else/ && $nesting_index == 0 ){
                    # code here will be printed out
                    if ($ACCESS == PRIVATE){
                        print $private_section_line;
                    }
                    $SIP_RUN = 1;
                    last;
                }
                elsif ( $line =~ m/^\s*#endif/ ){
                    if ( $nesting_index == 0 ){
                        $SIP_RUN = 0;
                        last;
                    }
                    else {
                        $nesting_index--;
                    }
                }
            }
            next;
        }
        else {
            next;
        }
    }

    # TYPE HEADER CODE
    if ( $HEADER_CODE && $SIP_RUN == 0 ){
        $HEADER_CODE = 0;
        print "%End\n";
    }

    # Skip forward declarations
    if ($line =~ m/^\s*class \w+;$/){
        next;
    }
    # Skip Q_OBJECT, Q_PROPERTY, Q_ENUM, Q_GADGET
    if ($line =~ m/^\s*Q_(OBJECT|ENUMS|PROPERTY|GADGET|DECLARE_METATYPE).*?$/){
        next;
    }

    # SIP_SKIP
    if ( $line =~ m/SIP_SKIP/ ){
      next;
    }

    # Private members (exclude SIP_RUN)
    if ( $line =~ m/^\s*private( slots)?:/ ){
        $ACCESS = PRIVATE;
        $private_section_line = $line;
        next;
    }
    elsif ( $line =~ m/^\s*(public)( slots)?:.*$/ ){
        $ACCESS = PUBLIC;
    }
    elsif ( $line =~ m/^\};.*$/ ) {
        $ACCESS = PUBLIC;
    }
    elsif ( $line =~ m/^\s*(protected)( slots)?:.*$/ ){
        $ACCESS = PROTECTED;
    }
    elsif ( $ACCESS == PRIVATE && $SIP_RUN == 0 ) {
      next;
    }
    # Skip assignment operator
    if ( $line =~ m/operator=\s*\(/ ){
        print "// $line";
        next;
    }

    # Detect comment block
    if ($line =~ m/^\s*\/\*/){
        do {no warnings 'uninitialized';
            $comment = processDoxygenLine( $line =~ s/^\s*\/\*(\*)?(.*)$/$2/r );
        };
        $comment =~ s/^\s*$//;
        while(!eof $header){
            $line = readline $header;
            $comment .= processDoxygenLine( $line =~ s/\s*\*?(.*?)(\/)?$/$1/r );
            if ( $line =~ m/\*\/$/ ){
                last;
            }
        }
        $comment =~ s/(\n)+$//;
        #print $comment;
        next;
    }

    # save comments and do not print them, except in SIP_RUN
    if ( $SIP_RUN == 0 ){
        if ( $line =~ m/^\s*\/\// ){
            $line =~ s/^\s*\/\/\!*\s*(.*)\n?$/$1/;
            $comment = processDoxygenLine( $line );
            next;
        }
    }

    if ( $line =~ m/^(\s*struct)\s+(\w+)$/ ) {
      $ACCESS = PUBLIC;
    }

    # class declaration started
    if ( $line =~ m/^(\s*class)\s*([A-Z]+_EXPORT)?\s+(\w+)(\s*\:.*)?(\s*SIP_ABSTRACT)?$/ ){
        do {no warnings 'uninitialized';
            $classname = $3;
            $line =~ m/\b[A-Z]+_EXPORT\b/ or die "Class$classname in $headerfile should be exported with appropriate [LIB]_EXPORT macro. If this should not be available in python, wrap it in a `#ifndef SIP_RUN` block.";
        };
        $line = "$1 $3";
        # Inheritance
        if ($4){
            my $m = $4;
            $m =~ s/public //g;
            $m =~ s/,?\s*private \w+(::\w+)?//;
            $m =~ s/(\s*:)?\s*$//;
            $line .= $m;
        }
        if ($5) {
            $line .= ' /Abstract/';
        }

        $line .= "\n{\n";
        if ( $comment !~ m/^\s*$/ ){
            $line .= "%Docstring\n$comment\n%End\n";
        }
        $line .= "\n%TypeHeaderCode\n#include \"" . basename($headerfile) . "\"\n";

        print $line;

        my $skip;
        # Skip opening curly bracket, we already added that above
        $skip = readline $header;
        $skip =~ m/^\s*{\s$/ || die "Unexpected content on line $line";

        $comment = '';
        $HEADER_CODE = 1;
        $ACCESS = PRIVATE;
        next;
    }

    # Enum declaration
    if ( $line =~ m/^\s*enum\s+\w+.*?$/ ){
        print $line;
        $line = readline $header;
        $line =~ m/^\s*\{\s*$/ || die 'Unexpected content: enum should be followed by {';
        print $line;
        while(!eof $header){
            $line = readline $header;
            if ($line =~ m/\};/){
                last;
            }
            $line =~ s/(\s*\w+)(\s*=\s*[\w\s\d<]+.*?)?(,?).*$/$1$3/;
            print $line;
        }
        print $line;
        # enums don't have Docstring apparently
        next;
    }

    # skip non-method member declaration in non-public sections
    if ( $SIP_RUN != 1 && $ACCESS != PUBLIC && $line =~ m/^\s*(?:mutable\s)?[\w<>]+(::\w+)? \*?\w+( = \w+(\([^()]+\))?)?;/){
        next;
    }

    # catch Q_DECLARE_FLAGS
    if ( $line =~ m/^(\s*)Q_DECLARE_FLAGS\(\s*(.*?)\s*,\s*(.*?)\s*\)\s*$/ ){
        $line = "$1typedef QFlags<$classname::$3> $2;\n";
        $qflag_hash{"$classname::$2"} = "$classname::$3";
    }
    # catch Q_DECLARE_OPERATORS_FOR_FLAGS
    if ( $line =~ m/^(\s*)Q_DECLARE_OPERATORS_FOR_FLAGS\(\s*(.*?)\s*\)\s*$/ ){
        my $flag = $qflag_hash{$2};
        $line = "$1QFlags<$flag> operator|($flag f1, QFlags<$flag> f2);\n";
    }

    do {no warnings 'uninitialized';
        # remove keywords
        $line =~ s/\s*\boverride\b//;
        $line =~ s/^(\s*)?(const )?(virtual |static )?inline /$1$2$3/;
        $line =~ s/\bnullptr\b/0/g;
        $line =~ s/\s*=\s*default\b//g;

        # remove constructor definition
        if ( $line =~  m/^(\s*)?(explicit )?(\w+)\([\w\=\(\)\s\,\&\*\<\>]*\)(?!;)$/ ){
            my $newline = $line =~ s/\n/;\n/r;
            my $nesting_index = 0;
            while(!eof $header){
                $line = readline $header;
                if ( $nesting_index == 0 ){
                    if ( $line =~ m/^\s*(:|,)/ ){
                        next;
                    }
                    $line =~ m/^\s*\{/ or die 'Constructor definition misses {';
                    if ( $line =~ m/^\s*\{.*?\}/ ){
                        last;
                    }
                    $nesting_index = 1;
                    next;
                }
                else {
                    $nesting_index += $line =~ tr/\{//;
                    $nesting_index -= $line =~ tr/\}//;
                    if ($nesting_index eq 0){
                        last;
                    }
                }
            }
            $line = $newline;
        }

        # remove function bodies
        if ( $line =~  m/^(\s*)?(const )?(virtual |static )?(([\w:]+(<.*?>)?\s+(\*|&)?)?(\w+|operator.{1,2})\(.*?(\(.*\))*.*\)( (?:const|SIP_[A-Z_]*?))*)\s*(\{.*\})?(?!;)(\s*\/\/.*)?$/ ){
            my $newline = "$1$2$3$4;\n";
            if ($line !~ m/\{.*?\}$/){
                $line = readline $header;
                if ( $line =~ m/^\s*\{\s*$/ ){
                    while(!eof $header){
                        $line = readline $header;
                        if ( $line =~ m/\}\s*$/ ){
                            last;
                        }
                    }
                }
            }
            $line = $newline;
        }

        if ( $line =~  m/^\s*(?:const |virtual |static |inline )*(?!explicit)([\w:]+(?:<.*?>)?)\s+(?:\*|&)?(?:\w+|operator.{1,2})\(.*$/ ){
            if ($1 !~ m/(void|SIP_PYOBJECT|operator|return|QFlag)/ ){
                $return_type = $1;
                # replace :: with . (changes c++ style namespace/class directives to Python style)
                $return_type =~ s/::/./g;

                # replace with builtin Python types
                $return_type =~ s/\bdouble\b/float/;
                $return_type =~ s/\bQString\b/str/;
                $return_type =~ s/\bQStringList\b/list of str/;
                if ( $return_type =~ m/^(?:QList|QVector)<\s*(.*?)[\s*\*]*>$/ ){
                    $return_type = "list of $1";
                }
                if ( $return_type =~ m/^QSet<\s*(.*?)[\s*\*]*>$/ ){
                    $return_type = "set of $1";
                }
            }
        }
    };

    # deleted functions
    if ( $line =~  m/^(\s*)?(const )?(virtual |static )?((\w+(<.*?>)?\s+(\*|&)?)?(\w+|operator.{1,2})\(.*?(\(.*\))*.*\)( const)?)\s*= delete;(\s*\/\/.*)?$/ ){
      $comment = '';
      next;
    }

    $line =~ s/\bSIP_FACTORY\b/\/Factory\//;
    $line =~ s/\bSIP_OUT\b/\/Out\//g;
    $line =~ s/\bSIP_INOUT\b/\/In,Out\//g;
    $line =~ s/\bSIP_TRANSFER\b/\/Transfer\//g;
    $line =~ s/\bSIP_KEEPREFERENCE\b/\/KeepReference\//;
    $line =~ s/\bSIP_TRANSFERTHIS\b/\/TransferThis\//;
    $line =~ s/\bSIP_TRANSFERBACK\b/\/TransferBack\//;
    $line =~ s/\bSIP_RELEASEGIL\b/\/ReleaseGIL\//;

    $line =~ s/SIP_PYNAME\(\s*(\w+)\s*\)/\/PyName=$1\//;
    $line =~ s/(\w+)(\<(?>[^<>]|(?2))*\>)?\s+SIP_PYTYPE\(\s*\'?([^()']+)(\(\s*(?:[^()]++|(?2))*\s*\))?\'?\s*\)/$3/g;
    $line =~ s/=\s+[^=]*?\s+SIP_PYDEFAULTVALUE\(\s*\'?([^()']+)(\(\s*(?:[^()]++|(?2))*\s*\))?\'?\s*\)/= $1/g;

    # fix astyle placing space after % character
    $line =~ s/\s*% (MappedType|TypeHeaderCode|ConvertFromTypeCode|ConvertToTypeCode|MethodCode|End)/%$1/;
    $line =~ s/\/\s+GetWrapper\s+\//\/GetWrapper\//;

    print $line;

    # multiline definition (parenthesis left open)
    if ( $MULTILINE_DEFINITION == 1 ){
      if ( $line =~ m/^[^()]*([^()]*\([^()]*\)[^()]*)*\)[^()]*$/){
          $MULTILINE_DEFINITION = 0;
      }
      else
      {
        next;
      }
    }
    elsif ( $line =~ m/^[^()]+\([^()]*([^()]*\([^()]*\)[^()]*)*[^)]*$/ ){
      $MULTILINE_DEFINITION = 1;
      next;
    }

    # write comment
    if ( $line =~ m/^\s*$/ || $line =~ m/\/\// || $line =~ m/\s*typedef / || $line =~ m/\s*struct / ){
        $comment = '';
    }
    elsif ( $comment !~ m/^\s*$/ || $return_type ne ''){
        print "%Docstring\n";
        if ( $comment !~ m/^\s*$/ ){
            print "$comment\n";
        }
        if ($return_type ne '' ){
           print " :rtype: $return_type\n";
        }
        print "%End\n";
        $comment = '';
        $return_type = '';
    }
}
print  "/************************************************************************\n";
print  " * This file has been generated automatically from                      *\n";
print  " *                                                                      *\n";
printf " * %-*s *\n", 68, $headerfile;
print  " *                                                                      *\n";
print  " * Do not edit manually ! Edit header and run scripts/sipify.pl again   *\n";
print  " ************************************************************************/\n";
