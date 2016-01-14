unit class Build::Simple;
use fatal;
class Node { ... }
has Node:D %!nodes;
my subset Filename of Any:D where { $_ ~~ Str|IO::Path };

method add-file(Filename:D $name, :dependencies(@dependency-names), *%args) {
	die "Already exists" if %!nodes{$name} :exists;
	die "Missing dependencies" unless %!nodes{all(@dependency-names)} :exists;
	my Node:D @dependencies = @dependency-names.map: { %!nodes{$^dep} };
	%!nodes{$name} = Build::Simple::Node.new(|%args, :name(~$name), :@dependencies, :!phony);
	return;
}

method add-phony(Filename:D $name, :dependencies(@dependency-names), *%args) {
	die "Already exists" if %!nodes{$name} :exists;
	die "Missing dependencies" unless %!nodes{all(@dependency-names)} :exists;
	my Node:D @dependencies = @dependency-names.map: { %!nodes{$^dep} };
	%!nodes{$name} = Build::Simple::Node.new(|%args, :name(~$name), :@dependencies, :phony);
	return;
}

method !nodes-for(Str:D $name) {
	my %seen;
	sub node-sorter($node) {
		return if %seen{$node}++;
		node-sorter($_) for $node.dependencies;
		take $node;
		return
	}
	return gather { node-sorter(%!nodes{$name}) };
}

method _sort-nodes(Str:D $name) {
	self!nodes-for($name).map(*.name);
}

method run(Filename:D $name, *%args) {
	for self!nodes-for(~$name) -> $node {
		$node.run(%args)
	}
	return;
}

my class Node {
	has Str:D $.name is required;
	has Bool:D $.phony = False;
	has Bool:D $.skip-mkdir = ?$!phony;
	has Node:D @.dependencies;
	has Sub $.action = sub {};

	method run (%options) {
		if !$!phony and $!name.IO.e {
			my @files = @!dependencies.grep(!*.phony).map(*.name.IO);
			my $age = $!name.IO.modified;
			return unless @files.grep: { $^entry.modified > $age && !$^entry.d };
		}
		my $parent = $!name.IO.parent;
		mkdir($parent) if not $!skip-mkdir and not $parent.IO.e;
		$!action.(:$!name, :@!dependencies, |%options);
	}
}
