use v6;
use fatal;
use Test;
use Build::Simple;
use Shell::Command;

my &next_is = -> { fail };

sub spew (:$name, *%other) {
	next_is($name);
	spurt($name, $name) or die "$!";
}

sub poke {
	next_is('poke');
}

sub noop(:$name, *%other) {
	next_is($name);
}

my $graph = Build::Simple.new;
my $dirname = '_testing';
END { rm_rf($dirname) if $dirname.IO.e }

my $source1_filename = '_testing/source1';
$graph.add_file($source1_filename, :action( -> :$name, *%other { poke(), spew(:$name) }));

my $source2_filename = '_testing/source2';
$graph.add_file($source2_filename, :action(&spew), :dependencies([$source1_filename]));

$graph.add_phony('build',   :action(&noop), :dependencies([ $source1_filename, $source2_filename ]));
$graph.add_phony('test',    :action(&noop), :dependencies([ 'build' ]));
$graph.add_phony('install', :action(&noop), :dependencies([ 'build' ]));

$graph.add_phony('loop1', :dependencies(['loop2']));
$graph.add_phony('loop2', :dependencies(['loop1']));



my @sorted = $graph._sort_nodes('build');

is_deeply(@sorted, [ $source1_filename, $source2_filename, 'build' ], 'topological sort is ok');

my @runs     = qw/build test install/;
my %expected = (
	build => [
		[qw{poke _testing/source1 _testing/source2 build}],
		[qw/build/],

		sub { rm_rf($dirname) },
		[qw{poke _testing/source1 _testing/source2 build}],
		[qw/build/],

		sub { rm_f($source2_filename) or warn "Couldn't remove $source2_filename: $!" },
		[qw{_testing/source2 build}],
		[qw/build/],

		sub { rm_f($source1_filename); sleep(1) },
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
	rm_rf($dirname);
	my $count = 1;
	for (@expected) -> $expected {
		if ($expected ~~ Callable) {
			$expected();
		}
		else {
			my @got;
			temp &next_is = -> $name { push @got, $name };
			$graph.run($run, :verbosity);
			is_deeply(@got, $expected, "@got is {$expected.perl} in run $run-$count");
			$count++;
		}
	}
}

