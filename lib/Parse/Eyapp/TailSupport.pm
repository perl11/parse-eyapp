package Parse::Eyapp::TailSupport;
use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Scalar::Util qw{blessed};
use Carp;

# attribute to count the lines
my $tokenline = 1;

sub tokenline {
  my $self = shift;

  $tokenline += shift if @_;

  $tokenline
}

# Generic error handler
# Convention adopted: if the attribute of a token is an object
# assume it has 'line' and 'str' methods. Otherwise, if it
# is an array, follows the convention [ str, line, ...]
# otherwise is just an string representing the value of the token
my $_Error = sub {
  my $parser = shift;

  my $yydata = $parser->YYData;

    exists $yydata->{ERRMSG}
  and do {
      warn $yydata->{ERRMSG};
      delete $yydata->{ERRMSG};
      return;
  };

  my ($attr)=$parser->YYCurval;

  my $stoken = '';

  if (blessed($attr) && $attr->can('str')) {
     $stoken = " near '".$attr->str."'"
  }
  elsif (ref($attr) eq 'ARRAY') {
    $stoken = " near '".$attr->[0]."'";
  }
  else {
    if ($attr) {
      $stoken = " near '$attr'";
    }
    else {
      $stoken = " near end of input";
    }
  }

  my @expected = map { "'$_'" } $parser->YYExpect();
  my $expected = '';
    $expected = "Expected one of these terminals: @expected"
  if @expected;

  my $tline = '';
  if (blessed($attr) && $attr->can('line')) {
    $tline = " (line number ".$attr->line.")." 
  }
  elsif (ref($attr) eq 'ARRAY') {
    $tline = " (line number ".$attr->[1].").";
  }

  local $" = ', ';
  warn << "ERRMSG";

Syntax error$stoken$tline. 
$expected
ERRMSG
};

sub error {
  my $self = shift;

  $_Error = shift if @_;

  $_Error;
}

# attribute with the lexical analyzer
# has this value by default
my $_Lexer = sub {
  croak "Error: lexical analizer not defined";
};

sub lexer {
  my $self = shift;

  $_Lexer = shift if @_;

  $_Lexer;
}

# attribute with the input
# is a reference to the actual input
my $input;

sub slurp_file {
  my $fn = shift;
  my $f;

  my $mode = undef;
  if ($fn && -r $fn) {
    open $f, $fn  or die "Can't find file '$fn'!\n";
  }
  else {
    $f = \*STDIN;
    my $msg = shift;
    $mode = shift;
    print($msg) if $msg;
  }

  local $/ = $mode;
  $$input = <$f>;
}

sub input {
  my $self = shift;

  $$input = shift if @_;

  $input;
}

sub Run {
  my ($self) = shift;
  my $yydebug = shift;
  
  return $self->YYParse( 
    yylex => $self->lexer(), 
    yyerror => $self->error,
    yydebug => $yydebug, # 0xF
  );
}

sub main {
  my $package = shift;
  my $prompt = shift;

  my $debug = 0;
  my $file = '';
  my $showtree = 0;
  my $help;
  my $result = GetOptions (
    "debug!" => \$debug,  
    "file=s" => \$file,
    "tree!"  => \$showtree,
    "help"   => \$help,
  );

  pod2usage() if $help;

  $debug = 0x1F if $debug;
  $file = shift if !$file && @ARGV; 

  slurp_file( $file, $prompt);

  my $parser = $package->new();
  my $tree = $parser->Run( $debug );

  print $tree->str()."\n" if $showtree && $tree;
}

1;

