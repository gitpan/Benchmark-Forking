package Benchmark::Forking;

$VERSION = 0.99;

use Benchmark;
require Exporter;

use strict;
use vars qw( $Enabled $RunLoop );

sub import   { enable(); Exporter::export_to_level('Benchmark', 1, @_) }
sub unimport { disable() }

sub enable   { $Enabled = 1 }
sub disable  { $Enabled = 0 }
sub enabled  { ( $#_ > 0 ) ? $Enabled = $_[1] : $Enabled }

# The runloop sub uses a special open() call that causes our process to fork, 
# with a filehandle acting as an IO channel from the child back to the parent. 
# The child runs the timing loop and prints the values from the Benchmark
# result object to its STDOUT, then it exits, terminating the child process.
# The output from the child appears in the main process' FORK handle, which 
# is read, re-blessed to form a proper Benchmark result object, and returned.

sub runloop {
  $Enabled or return &$RunLoop;
  
  if ( not open( FORK, '-|' ) ) {
    print join "\n", @{ &$RunLoop }; 
    exit;
  } else {
    my @td = <FORK>;
    close( FORK ) or die $!;
    return bless \@td, 'Benchmark';
  }
}

# The BEGIN block captures a reference to the normal Benchmark runloop sub to 
# be called by the wrapper, then installs our sub in the original's place.

BEGIN {
  $Enabled = 1; 
  $RunLoop = \&Benchmark::runloop;
  no strict 'refs';
  local $^W; # avoid sub redefined warning
  *{'Benchmark::runloop'} = \&runloop;
}

1;

__END__

########################################################################

=head1 NAME

Benchmark::Forking - Run benchmarks in separate processes

=head1 SYNOPSIS

  use Benchmark::Forking qw( timethis timethese cmpthese );

  timethis ($count, "code");

  timethese($count, {
      'Name1' => sub { ...code1... },
      'Name2' => sub { ...code2... },
  });
  
  cmpthese($count, {
      'Name1' => sub { ...code1... },
      'Name2' => sub { ...code2... },
  });

  Benchmark::Forking->enabled(0);  # Stop using forking feature
  ...
  Benchmark::Forking->enabled(1);  # Begin using forking again

=head1 DESCRIPTION

The Benchmark::Forking module changes the behavior of the standard
Benchmark module, running each piece of code to be timed in a
separate forked process. Because each child exits after running
its timing loop, the computations it performs can't propogate back
to affect subsequent test cases.

This can make benchmark comparisons more accurate, because the
separate test cases are mostly isolated from side-effects caused
by the others. Benchmark scripts typically don't depend on those
side-effects, so in most cases you can simply use or require this
module at the top of your existing code without having to change
anything else. (A few key exceptions are noted in L</BUGS>.)

=head2 Implementation 

Benchmark::Forking replaces the private runloop() function in the
Benchmark module with a wrapper that forks before calling the
original function. Forking is accomplished by the special
C<open(F,"-|")> call described in L<perlfunc/open>, and the results
are passed back as text from the child to the parent through an
interprocess filehandle.

When comparing several test cases with the C<timethese> or C<cmpthese>
functions, the main process will fork off a child and wait for it
to complete its timing of all of the repetitions of one piece of
code, then fork off a new child to handle the next case and wait
again.

=head2 Exports

This module re-exports the same functions provided by Benchmark: 
countit, timeit, timethis, timethese, and cmpthese.

For a description of these functions, see L<Benchmark>.

=head2 Methods

The benchmark forking functionality is automatically enabled once
you load this module, but you can also disable and re-enable it at
run-time using the following class methods.

=over 10

=item enabled

If called without arguments, reports the current status:

    my $boolean = Benchmark::Forking->enabled;

If passed an additional argument, enables or disable forking:

    Benchmark::Forking->enabled( 1 );
    $t = timeit(10, '$Global = 5 * $Global');
    Benchmark::Forking->enabled( 0 );

=item enable

Enables benchmark forking.

    Benchmark::Forking->enable();

=item disable

Disables benchmark forking.

    Benchmark::Forking->disable();

=back

=head1 BUGS

Because this depends on Perl's implementation of fork, it may not work
as expected on non-Unix platforms such as Microsoft Windows.

Some external resources may not work when opened in the parent process
and then accessed from multiple forked instances. If using this module
causes your file, network, or database code to fail with an unusual
error, this issue may be the culprit.

Some Benchmark scripts either accidentally or deliberately rely on the
side-effects that this module avoids. If using this module causes your
Perl code to behave differently than expected, you may be relying on
this behavior; you can either revise your code to remove the dependency
or continue to use the non-forking Benchmark.

If the standard Benchmark module were more fully object-oriented, this
functionality could be added via subclassing, rather than by fiddling
with Benchmark's internals, but the current implemenation doesn't seem
to allow for this.

=head1 SEE ALSO

For documentation of the timing functions, see L<Benchmark>.

For distribution, installation, support, copyright and license 
information, see L<Benchmark::Forking::ReadMe>.

=cut