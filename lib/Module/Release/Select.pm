package Module::Release::Select;

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
          (?&SELECTORS) (?{ $_ = $^R->[1] })

          (?(DEFINE)
              (?<SELECTORS>
                  (?{ [$^R, []] })
                  (?&SELECTOR) # [[$^R, []], $selector]
                  (?{ [$^R->[0][0], [$^R->[1]]] })
                  (?:
                      \s*,\s*
                      (?&SELECTOR)
                      (?{
                          push @{$^R->[0][1]}, $^R->[1];
                          $^R->[0];
                      })
                  )*
                  \s*
              ) # SELECTORS

              (?<SELECTOR>
                  (?{ [$^R, []] })
                  (?&SIMPLE_SELECTOR) # [[$^R, []], $simple_selector]
                  (?{ [$^R->[0][0], [$^R->[1]]] })
                  (?:
                      (\s*>\s*|\s*\+\s*|\s*~\s*|\s+)
                      (?{
                          my $comb = $^N;
                          $comb =~ s/^\s+//; $comb =~ s/\s+$//;
                          $comb = " " if $comb eq '';
                          push @{$^R->[1]}, {combinator=>$comb};
                          $^R;
                      })

                      (?&SIMPLE_SELECTOR)
                      (?{
                          push @{$^R->[0][1]}, $^R->[1];
                          $^R->[0];
                      })
                  )*
              ) # SELECTOR

              (?<SIMPLE_SELECTOR>
                  (?:
                      (?:
                          # type selector + optional filters
                          ((?&TYPE_NAME))
                          (?{ [$^R, {type=>$^N}] })
                          (?:
                              (?&FILTER) # [[$^R, $simple_selector], $filter]
                              (?{
                                  push @{ $^R->[0][1]{filters} }, $^R->[1];
                                  $^R->[0];
                              })
                              (?:
                                  \s*
                                  (?&FILTER)
                                  (?{
                                      push @{ $^R->[0][1]{filters} }, $^R->[1];
                                      $^R->[0];
                                  })
                              )*
                          )?
                      )
                  |
                      (?:
                          # optional type selector + one or more filters
                          ((?&TYPE_NAME))?
                          (?{
                              # XXX sometimes $^N is ' '?
                              my $t = $^N // '*';
                              $t = '*' if $t eq ' ';
                              [$^R, {type=>$t}] })
                          (?&FILTER) # [[$^R, $simple_selector], $filter]
                          (?{
                              push @{ $^R->[0][1]{filters} }, $^R->[1];
                              $^R->[0];
                          })
                          (?:
                              \s*
                              (?&FILTER)
                              (?{
                                  push @{ $^R->[0][1]{filters} }, $^R->[1];
                                  $^R->[0];
                              })
                          )*
                      )
                  )
              ) # SIMPLE_SELECTOR

              (?<TYPE_NAME>
                  [A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z0-9_]+)*|\*
              )

              (?<FILTER>
                  (?{ [$^R, {}] })
                  (
                      (?&ATTR_SELECTOR) # [[$^R0, {}], [$attr, $op, $val]]
                      (?{
                          $^R->[0][1]{type}  = 'attr_selector';
                          $^R->[0][1]{attr}  = $^R->[1][0];
                          $^R->[0][1]{op}    = $^R->[1][1] if defined $^R->[1][1];
                          $^R->[0][1]{value} = $^R->[1][2] if @{ $^R->[1] } > 2;
                          $^R->[0];
                      })
                  |
                      \.((?&TYPE_NAME))
                      (?{
                          $^R->[1]{type}  = 'class_selector';
                          $^R->[1]{class} = $^N;
                          $^R;
                      })
                  |
                      \#(\w+)
                      (?{
                          $^R->[1]{type} = 'id_selector';
                          $^R->[1]{id}   = $^N;
                          $^R;
                      })
                  |
                      (?&PSEUDOCLASS) # [[$^R, {}], [$pseudoclass, \@args]]
                      (?{
                          $^R->[0][1]{type}         = 'pseudoclass';
                          $^R->[0][1]{pseudoclass}  = $^R->[1][0];
                          $^R->[0][1]{args}         = $^R->[1][1] if @{ $^R->[1] } > 1;
                          $^R->[0];
                      })
                  )
              ) # FILTER

              (?<ATTR_SELECTOR>
                  \[\s*
                  (?{ [$^R, []] }) # [$^R, [$subjects, $op, $literal]]
                  (?&ATTR_SUBJECTS) # [[$^R, [{name=>$name, args=>$args}, ...]]
                  (?{
                      #use Data::Dmp; say "D:setting subjects: ", dmp $^R->[1];
                      push @{ $^R->[0][1] }, $^R->[1];
                      $^R->[0];
                  })

                  (?:
                      (
                          \s*(?:=~|!~)\s* |
                          \s*(?:!=|<>|>=?|<=?|==?)\s* |
                          \s++(?:eq|ne|lt|gt|le|ge)\s++ |
                          \s+(?:isnt|is|has|hasnt|in|notin)\s+
                      )
                      (?{
                          my $op = $^N;
                          $op =~ s/^\s+//; $op =~ s/\s+$//;
                          $^R->[1][1] = $op;
                          $^R;
                      })

                      (?:
                          (?&LITERAL) # [[$^R0, [$attr, $op]], $literal]
                          (?{
                              push @{ $^R->[0][1] }, $^R->[1];
                              $^R->[0];
                          })
                      |
                          (\w[^\s\]]*) # allow unquoted string
                          (?{
                              $^R->[1][2] = $^N;
                              $^R;
                          })
                      )
                  )?
                  \s*\]
              ) # ATTR_SELECTOR

              (?<ATTR_NAME>
                  [A-Za-z_][A-Za-z0-9_]*
              )

              (?<ATTR_SUBJECT>
                  (?{ [$^R, []] }) # [$^R, [name, \@args]]
                  ((?&ATTR_NAME))
                  (?{
                      #say "D:pushing attribute subject: $^N";
                      push @{ $^R->[1] }, $^N;
                      $^R;
                  })
                  (?:
                      # attribute arguments
                      \s*\(\s* (*PRUNE)
                      (?{
                          $^R->[1][1] = [];
                          $^R;
                      })
                      (?:
                          (?&LITERAL)
                          (?{
                              #use Data::Dmp; say "D:pushing argument: ", dmp $^R->[1];
                              push @{ $^R->[0][1][1] }, $^R->[1];
                              $^R->[0];
                          })
                          (?:
                              \s*,\s*
                              (?&LITERAL)
                              (?{
                                  #use Data::Dmp; say "D:pushing argument: ", dmp $^R->[1];
                                  push @{ $^R->[0][1][1] }, $^R->[1];
                                  $^R->[0];
                              })
                          )*
                      )?
                      \s*\)\s*
                  )?
              ) # ATTR_SUBJECT

              (?<ATTR_SUBJECTS>
                  (?{ $_i1 = 0; [$^R, []] })
                  (?&ATTR_SUBJECT) # [[$^R, [$name, \@args]]
                  (?{
                      $_i1++;
                      unless ($_i1 > 1) { # to prevent backtracking from executing tihs code block twice
                          #say "D:pushing subject(1)";
                          push @{ $^R->[0][1] }, {
                              name => $^R->[1][0],
                              (args => $^R->[1][1]) x !!defined($^R->[1][1]),
                          };
                      }
                      $^R->[0];
                  })
                  (?:
                      \s*\.\s*
                      (?{ $_i1 = 0; $^R })
                      (?&ATTR_SUBJECT) # [[$^R, $name, \@args]]
                      (?{
                          $_i1++;
                          unless ($_i1 > 1) { # to prevent backtracking from executing this code block twice
                              #say "D:pushing subject(2)";
                              push @{ $^R->[0][1] }, {
                                  name => $^R->[1][0],
                                  (args => $^R->[1][1]) x !!defined($^R->[1][1]),
                              };
                          }
                          $^R->[0];
                      })
                  )*
              ) # ATTR_SUBJECTS

              (?<LITERAL>
                  (?&LITERAL_ARRAY)
              |
                  (?&LITERAL_NUMBER)
              |
                  (?&LITERAL_STRING_DQUOTE)
              |
                  (?&LITERAL_STRING_SQUOTE)
              |
                  (?&LITERAL_REGEX)
              |
                  true (?{ [$^R, 1] })
              |
                  false (?{ [$^R, 0] })
              |
                  null (?{ [$^R, undef] })
              ) # LITERAL

              (?<LITERAL_ARRAY>
                  \[\s*
                  (?{ [$^R, []] })
                  (?:
                      (?&LITERAL) # [[$^R, []], $val]
                      (?{ [$^R->[0][0], [$^R->[1]]] })
                      \s*
                      (?:
                          (?:
                              ,\s* (?&LITERAL)
                              (?{ push @{$^R->[0][1]}, $^R->[1]; $^R->[0] })
                          )*
                      |
                          (?: [^,\]]|\z ) (?{ _fail "Expected ',' or '\x5d'" })
                      )
                  )?
                  \s*
                  (?:
                      \]
                  |
                      (?:.|\z) (?{ _fail "Expected closing of array" })
                  )
              ) # LITERAL_ARRAY

              (?<LITERAL_NUMBER>
                  (
                      -?
                      (?: 0 | [1-9]\d* )
                      (?: \. \d+ )?
                      (?: [eE] [-+]? \d+ )?
                  )
                  (?{ [$^R, 0+$^N] })
              )

              (?<LITERAL_STRING_DQUOTE>
                  (
                      "
                      (?:
                          [^\\"]+
                      |
                          \\ [0-7]{1,3}
                      |
                          \\ x [0-9A-Fa-f]{1,2}
                      |
                          \\ ["\\'tnrfbae]
                      )*
                      "
                  )
                  (?{ [$^R, eval $^N] })
              )

              (?<LITERAL_STRING_SQUOTE>
                  (
                      '
                      (?:
                          [^\\']+
                      |
                          \\ .
                      )*
                      '
                  )
                  (?{ [$^R, eval $^N] })
              )

              (?<LITERAL_REGEX>
                  (
                      (?:
                          (?:
                              /
                              (?:
                                  [^/\\]+
                              |
                                  \\ .
                              )*
                              /
                          ) |
                          (?:
                              qr\(
                              (?:
                                  [^\)\\]+
                              |
                                  \\ .
                              )*
                              \)
                          )
                      )
                      [ims]*
                  )
                  (?{ my $code = substr($^N, 0, 2) eq "qr" ? $^N : "qr$^N"; my $re = eval $code; die if $@; [$^R, $re] })
              )

              (?<PSEUDOCLASS_NAME>
                  [A-Za-z_][A-Za-z0-9_]*(?:-[A-Za-z0-9_]+)*
              )

              (?<PSEUDOCLASS>
                  :
                  (?:
                      (?:
                          (has|not)
                          (?{ [$^R, [$^N]] })
                          \(\s*
                          (?:
                              (?&LITERAL)
                              (?{
                                  push @{ $^R->[0][1][1] }, $^R->[1];
                                  $^R->[0];
                              })
                          |
                              ((?&SELECTORS))
                              (?{
                                  push @{ $^R->[0][1][1] }, $^N;
                                  $^R->[0];
                              })
                          )
                          \s*\)
                      )
                  |
                      (?:
                          ((?&PSEUDOCLASS_NAME))
                          (?{ [$^R, [$^N]] })
                          (?:
                              \(\s*
                              (?&LITERAL)
                              (?{
                                  push @{ $^R->[0][1][1] }, $^R->[1];
                                  $^R->[0];
                              })
                              (?:
                                  \s*,\s*
                                  (?&LITERAL)
                                  (?{
                                      push @{ $^R->[0][1][1] }, $^R->[1];
                                      $^R->[0];
                                  })
                              )*
                              \s*\)
                          )?
                      )
                  )
              ) # PSEUDOCLASS
          ) # DEFINE
  }x;


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

A I<release specification> is a chain of one or more simple release
specifications separated by comma (C<,>) or pipe (C<|>). For example, C<< 0.001,
0.003 .. 0.007, >= 0.010 >> (versions 0.001, 0.003 to 0.007, and 0.010 or
higher).

A I<simple release specification> is a chain of expressions separated by
ampersand (C<&>). For example, C<< >= 0.003 & <= 0.010 >>.

An I<expression> is left operand followed by binary operator followed by right
operand. Operand is optional if it is "version". For example, C<< date <=
{yesterday} >>, C<< >= v0.001 >>.

List of I<binary operator>s:

 | operator | name                     | operand type (left)             |       | precedence |
 |----------+--------------------------+---------------------------------+------------|
 | ..       | range                    | releases                        | lowest     |
 | -        | releases before          | releases (left), uint (right)   | low        |
 | +        | releases before          | releases (left), uint (right)   | low        |
 | =        | equal-to                 | version, string, or date (left) | medium     |
 | !=       | not-equal-to             | version, string, or date      | medium     |
 | >        | greater-than             | version, string, or date      | medium     |
 | >=       | greater-than-or-equal-to | version, string, or date      | medium     |
 | <        | less-than                | version, string, or date      | medium     |
 | <=       | less-than-or-equal-to    | version, string, or date      | medium     |
 | =~       | regex matching           |
An operand is either a release specification inside parentheses (C<( ... )>), or
a literal.

A literal is either a version literal, a date literal,

A I<version literal> is either: 1) a dot-separated series of numbers optionally
prefixed by "v" and optionally followed by "_" and numbers (e.g. 1, v2, 1.2, or
1.2.3_001); 2) "latest"; 3) "oldest".


=head1 FUNCTIONS

=head2 select_release


=head2 select_releases


=head1 SEE ALSO

=cut
