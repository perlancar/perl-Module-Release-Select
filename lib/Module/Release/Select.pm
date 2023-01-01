package Module::Release::Select;

use 5.010001;
use strict;
use warnings;

use Exporter 'import';

# AUTHORITY
# DATE
# DIST
# VERSION

our @EXPORT_OK = qw($RE select_release select_releases);

our $RE =
    qr{
          #(?&EXPR) (?{ $_ = $^R->[1] })
          (?&SIMPLE_EXPR) (?{ $_ = $^R->[1] })

          (?(DEFINE)
              (?<EXPR>
                  (?{ [$^R, []] })
                  (?&AND_EXPR)
                  (?{ [$^R->[0][0], [$^R->[1]]] })
                  (?:
                      die 1;
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
                          (?{ $^R->[1]{val} = $^N; $^R })
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
                          \" ([^"]+|\\\\|\\")* \"
                          (?{ $^R->[1]{val} = $^N; $^R }) # TODO: parse string literal
                      )
                  )
              ) # SIMPLE_EXPR

              (?<OP>
                  =|!=|<|>|<=|>=|=~|!~
              )

              (?<VER_VALUE>
                  v?
                  [0-9]+(?:\.[0-9]+)*
              |
                  [0-9]+(?:\.[0-9]+)+(?:_[0-9]+)
              ) # VER_VALUE

          ) # DEFINE
  }x;

sub parse_release {
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

The notation:

 # exact version number
 0.002
 =0.002     # ditto

 # version number range with >, >=, <, <=, !=, and .., & to join
 # condition with "and" logic, | to join with "or" logic.
 >0.002
 >=0.002
 >=0.002 & <=0.015
 <0.002 | >0.015
 0.001 .. 0.015        # practically all releases
 0.001, 0.002, 0.003

 # "latest" and "oldest" can replace version number
 latest
 =latest
 <latest           # all releases except the latest
 != latest         # ditto
 >oldest           # all releases except the oldest
 oldest .. latest  # practically all releases
 latest .. oldest  # note: won't select any because LATEST > OLDEST

 # +n and -m to refer to n releases after and n releases before
 latest-1       # the release before the latest
 0.002 + 1      # the release after 0.002
 > (oldest+1)   # all releases except the oldest and one after that (OLDEST+1)

 # select by date, any date supported by DateTime::Format::Natural is supported
 date < yesterday        # all releases released 2 days ago
 date > {2 months ago}   # all releases after 2 months ago

 # select by author
 author=PERLANCAR             # all releases released by PERLANCAR
 author != "PERLANCAR"        # all releases not released by PERLANCAR
 author=PERLANCAR & > 0.005   # all releases after 0.005 that are released by PERLANCAR

 # "latest" & "oldest" can take argument
 latest(author=PERLANCAR)      # the latest release by PERLANCAR
 latest(author=PERLANCAR) + 1  # the release after the latest release by PERLANCAR
 oldest(date > {2022-10-01})   # the oldest release after 2022-10-01

 # not yet supported, but can be supported in the future
 # abstract =~ /foo/              # all releases with abstract matching a regex
 # distribution ne "App-orgadb"   # all releases with distribution not equal to "App-orgadb"
 # first is true                  # all releases with "first" key being true

Using the module:

 use Module::Release::Select qw(select_release select_releases);

 # the array below is releases of App-orgadb. it must be an array of hashrefs
 # which must be sorted newest-first and each hashref contains at least this
 # key: 'version'; additional keys are needed when specifying using notation
 # that searches associated keys, e.g. searching by date will require the 'date'
 # key, searching by author will require the 'author' key).
 #
 # the simpler form of releases is accepted: array of version numbers. Using
 # this releases data, you can only specify version number or LATEST/OLDEST).

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
    {
      abstract     => "An opinionated Org addressbook toolset",
      author       => "PERLANCAR",
      date         => "2022-10-17T13:17:44",
      distribution => "App-orgadb",
      first        => "",
      maturity     => "released",
      release      => "App-orgadb-0.014",
      status       => "cpan",
      version      => 0.014,
    },
    {
      abstract     => "An opinionated Org addressbook toolset",
      author       => "PERLANCAR",
      date         => "2022-10-16T12:59:21",
      distribution => "App-orgadb",
      first        => "",
      maturity     => "released",
      release      => "App-orgadb-0.013",
      status       => "backpan",
      version      => 0.013,
    },
    {
      abstract     => "An opinionated Org addressbook toolset",
      author       => "PERLANCAR",
      date         => "2022-10-15T03:44:35",
      distribution => "App-orgadb",
      first        => "",
      maturity     => "released",
      release      => "App-orgadb-0.012",
      status       => "backpan",
      version      => 0.012,
    },
    {
      abstract     => "An opinionated Org addressbook toolset",
      author       => "PERLANCAR",
      date         => "2022-10-15T02:36:14",
      distribution => "App-orgadb",
      first        => "",
      maturity     => "released",
      release      => "App-orgadb-0.011",
      status       => "backpan",
      version      => 0.011,
    },
    {
      abstract     => "An opinionated Org addressbook toolset",
      author       => "PERLANCAR",
      date         => "2022-10-08T17:29:39",
      distribution => "App-orgadb",
      first        => "",
      maturity     => "released",
      release      => "App-orgadb-0.010",
      status       => "backpan",
      version      => "0.010",
    },
    {
      abstract     => "An opinionated Org addressbook toolset",
      author       => "PERLANCAR",
      date         => "2022-10-08T16:29:18",
      distribution => "App-orgadb",
      first        => "",
      maturity     => "released",
      release      => "App-orgadb-0.009",
      status       => "backpan",
      version      => 0.009,
    },
    {
      abstract     => "An opinionated Org addressbook toolset",
      author       => "PERLANCAR",
      date         => "2022-09-26T08:50:37",
      distribution => "App-orgadb",
      first        => "",
      maturity     => "released",
      release      => "App-orgadb-0.008",
      status       => "backpan",
      version      => 0.008,
    },
    {
      abstract     => "An opinionated Org addressbook toolset",
      author       => "PERLANCAR",
      date         => "2022-09-26T08:50:26",
      distribution => "App-orgadb",
      first        => "",
      maturity     => "released",
      release      => "App-orgadb-0.007",
      status       => "backpan",
      version      => 0.007,
    },
    {
      abstract     => "An opinionated Org addressbook toolset",
      author       => "PERLANCAR",
      date         => "2022-09-09T12:09:27",
      distribution => "App-orgadb",
      first        => "",
      maturity     => "released",
      release      => "App-orgadb-0.006",
      status       => "backpan",
      version      => 0.006,
    },
    {
      abstract     => "An opinionated Org addressbook toolset",
      author       => "PERLANCAR",
      date         => "2022-08-13T00:05:38",
      distribution => "App-orgadb",
      first        => "",
      maturity     => "released",
      release      => "App-orgadb-0.005",
      status       => "backpan",
      version      => 0.005,
    },
    {
      abstract     => "An opinionated Org addressbook tool",
      author       => "PERLANCAR",
      date         => "2022-07-04T12:06:34",
      distribution => "App-orgadb",
      first        => "",
      maturity     => "released",
      release      => "App-orgadb-0.004",
      status       => "backpan",
      version      => 0.004,
    },
    {
      abstract     => "An opinionated Org addressbook tool",
      author       => "PERLANCAR",
      date         => "2022-07-04T05:10:45",
      distribution => "App-orgadb",
      first        => "",
      maturity     => "released",
      release      => "App-orgadb-0.003",
      status       => "backpan",
      version      => 0.003,
    },
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


=head1 DESCRIPTION

This module defines a notation to select releases. Releases can be selected by
exact version numbers or by author and date.


=head1 NOTATION SYNTAX

Grammar:

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

 VER_OFFSET ::= FUNC ( "+" | "-") [1-9][0-9]*
              | FUNC

 VER_FUNC ::= "VER_FUNC_NAME" ( "(" EXPR? ")" )?
            | VER_TERM

 VER_FUNC_NAME ::= [A-Za-z_][A-Za-z0-9]*

 VER_TERM ::= VER_LITERAL
            | "(" EXPR ")"

 STR_VAL ::= STR_LITERAL

 STR_LITERAL ::= '"' ( [^"\] | "\\" | "\" '"' )* '"'

 DATE_VAL ::= DATE_LIERAL

 DATE_LITERAL ::= "{" [^{]+ "}"

 VER_LITERAL ::= ("v")? [0-9]+ ( "." [0-9]+ )*
                   | ("v")? [0-9]+ ( "." [0-9]+ )+ ( "_" [0-9]+ )?
                   | "latest"
                   | "oldest"


=head1 FUNCTIONS

=head2 select_release


=head2 select_releases


=head1 SEE ALSO

=cut
