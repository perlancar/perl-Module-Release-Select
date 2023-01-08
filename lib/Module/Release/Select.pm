package Module::Release::Select;

use 5.010001;
use strict;
use warnings;

use Exporter 'import';

require String::Escape;

# AUTHORITY
# DATE
# DIST
# VERSION

our @EXPORT_OK = qw($RE select_release select_releases);

our $RE =
    qr{
          (?&EXPR) (?{ $_ = $^R->[1] })
          #(?&SIMPLE_EXPR) (?{ $_ = $^R->[1] })

          (?(DEFINE)
              (?<EXPR>
                  (?{ [$^R, []] })
                  (?&AND_EXPR)
                  (?{ [$^R->[0][0], [$^R->[1]]] })
                  (?:
                      \s*[,|]\s*
                      (?&AND_EXPR)
                      (?{
                          push @{$^R->[0][1]}, $^R->[1];
                          $^R->[0];
                      })
                  )*
                  \s*
              ) # EXPR

              (?<AND_EXPR>
                  (?{ [$^R, []] })
                  (?&SIMPLE_EXPR)
                  (?{ [$^R->[0][0], [$^R->[1]]] })
                  (?:
                      \s*[&]\s*
                      (?&SIMPLE_EXPR)
                      (?{
                          push @{$^R->[0][1]}, $^R->[1];
                          $^R->[0];
                      })
                  )*
                  \s*
              ) # AND_EXPR

              (?<SIMPLE_EXPR>
                  (?:
                      (?:
                          # ver_comp
                          (?: version \s*)?
                          ((?&OP))? \s*
                          (?{ [$^R, {type=>"version", op=> $^N // "=" }] })
                          ((?&VER_VALUE))
                          (?{ $^R->[0][1]{val} = $^R->[1]; $^R->[0] })
                      )
                  |
                      (?:
                          # date_comp
                          date \s*
                          ((?&OP)) \s*
                          (?{ [$^R, {type=>"date", op=> $^N }] })
                          # DATE_VALUE
                          \{ ([^\{]+) \}
                          (?{ $^R->[1]{val} = $^N; $^R })
                      )
                  |
                      (?:
                          # author_comp
                          author \s*
                          ((?&OP)) \s*
                          (?{ [$^R, {type=>"author", op=> $^N }] })
                          # STR_VALUE
                          (\" (?:[^"]+|\\\\|\\")* \")
                          (?{ $^R->[1]{val} = String::Escape::unqqbackslash($^N); $^R })
                      )
                  )
              ) # SIMPLE_EXPR

              (?<OP>
                  =|!=|<|>|<=|>=|=~|!~
              )

              (?<VER_VALUE>
                  ((?&VER_LITERAL)) \s*
                  (?{ [$^R, {literal=>$^N, offset=>0}] })
                  (?:
                      \s* ([+-]?[0-9]+) \s*
                      (?{ $^R->[1]{offset} = $^N; $^R })
                  )?
              )

              (?<VER_LITERAL>
                  (
                      v?
                      (
                          [0-9]+(?:\.[0-9]+)+(?:_[0-9]+)
                      |
                          [0-9]+(?:\.[0-9]+)*
                      )
                  )
              |   latest
              |   oldest
              ) # VER_LITERAL

          ) # DEFINE
  }x;

sub parse_releases_expr {
    state $re = qr{\A\s*$RE\s*\z};

    local $_ = shift;
    local $^R;
    eval { $_ =~ $re } and return $_;
    die $@ if $@;
    return undef; ## no critic: Subroutines::ProhibitExplicitReturnUndef
}

1;
# ABSTRACT: Notation to select release(s)

=head1 SYNOPSIS

 use Module::Release::Select qw(select_release select_releases);

 my @releases = (0.005, 0.004, 0.003, 0.002, 0.001);

 my $rel = select_release('0.002', \@releases);       # => 0.002
 my $rel = select_release('0.002 + 1', \@releases);   # => 0.003
 my $rel = select_release('> 0.002', \@releases);     # => 0.005
 my $rel = select_release('latest', \@releases);      # => 0.005
 my $rel = select_release('latest-1', \@releases);    # => 0.004

 my @rels = select_releases('> oldest', \@releases);  # => (0.005, 0.004, 0.003, 0.002)


=head1 DESCRIPTION

This module lets you select one or more releases via an expression. Some example
expressions:

 # exact version number ('=')
 0.002
 =0.002     # ditto

 # version number range with '>', '>=', '<', '<=', '!='. use '&' to join
 # multiple conditions with "and" logic, use '|' or ',' to join with "or" logic.
 >0.002
 >=0.002
 >=0.002 & <=0.015
 <0.002 | >0.015
 0.001, 0.002, 0.003

 # "latest" and "oldest" can replace version number
 latest
 =latest
 <latest           # all releases except the latest
 != latest         # ditto
 >oldest           # all releases except the oldest

 # +n and -m to refer to n releases after and n releases before
 latest-1       # the release before the latest
 0.002 + 1      # the release after 0.002
 > (oldest+1)   # all releases except the oldest and one after that (oldest+1)

 # select by date, any date supported by DateTime::Format::Natural is supported
 date < {yesterday}      # all releases released 2 days ago
 date > {2 months ago}   # all releases after 2 months ago

 # select by author
 author="PERLANCAR"             # all releases released by PERLANCAR
 author != "PERLANCAR"          # all releases not released by PERLANCAR
 author="PERLANCAR" & > 0.005   # all releases after 0.005 that are released by PERLANCAR

To actually select releases, you provide a list of releases in the form of
version numbers in descending order. If you want to select by date or author,
each release will need to be a hashref containing C<date> and C<author> keys.
Below is an example of a list of releases for L<App::orgadb> distribution. This
structure is returned by L<App::MetaCPANUtils>' C<list_metacpan_release>:

 my @releases = (
    {
      abstract     => "An opinionated Org addressbook toolset",
      author       => "PERLANCAR",
      date         => "2022-11-04T12:57:07",
      distribution => "App-orgadb",
      first        => "",
      maturity     => "released",
      release      => "App-orgadb-0.015",
      status       => "latest",
      version      => 0.015,
    },
    ...
    {
      abstract     => "An opinionated Org addressbook tool",
      author       => "PERLANCAR",
      date         => "2022-06-23T23:21:58",
      distribution => "App-orgadb",
      first        => "",
      maturity     => "released",
      release      => "App-orgadb-0.002",
      status       => "backpan",
      version      => 0.002,
    },
    {
      abstract     => "An opinionated Org addressbook tool",
      author       => "PERLANCAR",
      date         => "2022-06-13T00:15:18",
      distribution => "App-orgadb",
      first        => 1,
      maturity     => "released",
      release      => "App-orgadb-0.001",
      status       => "backpan",
      version      => 0.001,
    },
 );

Some examples on selecting release(s):

 # select a single release, if notation selects multiple releases, the latest
 # one will be picked. returns undef when no releases are selected.
 my $rel = select_release('0.002', \@releases);       # => 0.002
 my $rel = select_release('0.002 + 1', \@releases);   # => 0.003
 my $rel = select_release('> 0.002', \@releases);     # => 0.015

 # instead of returning the latest one when multiple releases are selected,
 # select the oldest instead.
 my $rel = select_release({oldest=>1}, '> 0.002', \@releases);     # => 0.003

 # return detailed record instead of just version
 my $rel = select_release({detail=>1}, '0.002', \@releases); # => {version=>0.002, date=>'2022-06-23T23:21:58', ...}

 # select releases, returns empty list when no releases are selected
 my $rel = select_releases('LATEST-2 .. LATEST', \@releases);   # => 0.015, 0.014, 0.013


=head2 Expression grammar

 EXPR ::= AND_EXPR ( ("," | "|") AND_EXPR )*

 AND_EXPR ::= SIMPLE_EXPR ( "&" SIMPLE_EXPR )*

 SIMPLE_EXPR ::= COMP

 COMP ::= VER_COMP
        | DATE_COMP
        | AUTHOR_COMP

 VER_COMP ::= "version" OP VER_VALUE
            | OP VER_VALUE
            | VER_VALUE              ; for when OP ='='

 DATE_COMP ::= "date" OP DATE_VAL

 AUTHOR_COMP ::= "author" OP STR_VAL

 OP ::= "=" | "!=" | ">" | ">=" | "<" | "<=" | "=~" | "!~"

 VER_VALUE ::= VER_LITERAL
             | VER_OFFSET

 VER_OFFSET ::= VER_LITERAL ("+" | "-") [0-9]+

 STR_VAL ::= STR_LITERAL

 STR_LITERAL ::= '"' ( [^"\] | "\\" | "\" '"' )* '"'

 DATE_VAL ::= DATE_LITERAL

 DATE_LITERAL ::= "{" [^{]+ "}"

 VER_LITERAL ::= ("v")? [0-9]+ ( "." [0-9]+ )*
               | ("v")? [0-9]+ ( "." [0-9]+ )+ ( "_" [0-9]+ )?
               | "latest"
               | "oldest"


=head1 FUNCTIONS

=head2 select_release


=head2 select_releases


=head1 TODO

These notations are not yet supported but might be supported in the future:

 # "latest" & "oldest" can take argument
 latest(author="PERLANCAR")       # the latest release by PERLANCAR
 latest(author="PERLANCAR") + 1   # the release after the latest release by PERLANCAR
 oldest(date > {2022-10-01})      # the oldest release after 2022-10-01

 # functions

 # abstract =~ /foo/              # all releases with abstract matching a regex

 # distribution ne "App-orgadb"   # all releases with distribution not equal to "App-orgadb"

 # first is true                  # all releases with "first" key being true


=head1 SEE ALSO

=cut
