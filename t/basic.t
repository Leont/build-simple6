use v6;
use fatal;
use Test;
use Build::Simple;
use Shell::Command;

my &next-is = -> { fail };

sub dump(:$name, *%other) {
	next-is($name);
	my $dirname = $name.IO.dirname;
	mkdir $dirname if not $dirname.IO.d;
	spurt $name, $name;
}

sub poke(*%) {
	next-is('poke');
}

sub noop(:$name, *%other) {
	next-is($name);
}

my $graph = Build::Simple.new;
my $dirname = '_testing';
END { rm_rf($dirname) if $dirname.IO.e }

my $source1_filename = '_testing/source1';
$graph.add-file($source1_filename, :action( -> :$name, *%other { poke(), dump(:$name) }));

my $source2_filename = '_testing/source2';
$graph.add-file($source2_filename, :action(&dump), :dependencies([$source1_filename]));

$graph.add-phony('build',   :action(&noop), :dependencies([ $source1_filename, $source2_filename ]));
$graph.add-phony('test',    :action(&noop), :dependencies([ 'build' ]));
$graph.add-phony('install', :action(&noop), :dependencies([ 'build' ]));

$graph.add-phony('loop1', :dependencies(['loop2']));
$graph.add-phony('loop2', :dependencies(['loop1']));

my @sorted = $graph._sort-nodes('build');

is-deeply(@sorted, [ $source1_filename, $source2_filename, 'build' ], 'topological sort is ok');

my @runs     = qw/build test install/;
my %expected = (
	build => [
		[qw{poke _testing/source1 _testing/source2 build}],
		[qw/build/],

		sub { rm_rf($dirname) },
		[qw{poke _testing/source1 _testing/source2 build}],
		[qw/build/],

		sub { unlink $source2_filename or warn "Couldn't remove $source2_filename: $!" },
		[qw{_testing/source2 build}],
		[qw/build/],

		sub { unlink $source1_filename; sleep(1) },
		[qw{poke _testing/source1 _testing/source2 build}],
		[qw/build/],
	],
	test    => [
		[qw{poke _testing/source1 _testing/source2 build test}],
		[qw/build test/],
	],
	install => [
		[qw{poke _testing/source1 _testing/source2 build install}],
		[qw/build install/],
	],
);

for (%expected.kv) -> $run, @expected {
	rm_rf($dirname) if $dirname.IO.e;
	mkdir $dirname;
	my $count = 1;
	for @expected -> $expected {
		if $expected ~~ Callable {
			$expected();
		}
		else {
			my @got;
			temp &next-is = -> $name { push @got, $name };
			$graph.run($run, :verbosity);
			is-deeply(@got, $expected, "@got is {$expected.perl} in run $run-$count");
			$count++;
		}
	}
}

