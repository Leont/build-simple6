unit class Build::Simple;
use fatal;
class Node { ... }
has Node:D %!nodes;

method add-file(Str $name, :dependencies(@dependency-names), *%args) {
	die "Already exists" if %!nodes{$name} :exists;
	die "Missing dependencies" unless %!nodes{all(@dependency-names)} :exists;
	my Node:D @dependencies = @dependency-names.map: { %!nodes{$^dep} };
	%!nodes{$name} = Build::Simple::Node.new(|%args, :$name, :@dependencies, :!phony);
	return;
}

method add-phony(Str $name, :dependencies(@dependency-names), *%args) {
	die "Already exists" if %!nodes{$name} :exists;
	die "Missing dependencies" unless %!nodes{all(@dependency-names)} :exists;
	my Node:D @dependencies = @dependency-names.map: { %!nodes{$^dep} };
	%!nodes{$name} = Build::Simple::Node.new(|%args, :$name, :@dependencies, :phony);
	return;
}

method !nodes-for(Str $name) {
	my %seen;
	sub node-sorter($node, %loop is copy) {
		die "Looping" if %loop{$node} :exists;
		return if %seen{$node}++;
		%loop{$node} = 1;
		node-sorter($_, %loop) for $node.dependencies;
		take $node;
		return
	}
	return gather { node-sorter(%!nodes{$name}, {}) };
}

method _sort-nodes(Str $name) {
	self!nodes-for($name).map(*.name);
}

method run(Str $name, *%args) {
	for self!nodes-for($name) -> $node {
		$node.run(%args)
	}
	return;
}

my class Node {
	has Str:D $.name is required;
	has Bool:D $.phony = False;
	has Bool:D $.skip-mkdir = ?$!phony;
	has Node:D @.dependencies;
	has &.action = sub {};

	method run (%options) {
		if !$!phony and $!name.IO.e {
			my @files = @!dependencies.grep({ !.defined || !.phony() }).map(*.name.IO);
			my $age = $!name.IO.modified;
			return unless @files.grep({ $^entry.modified > $age && !$^entry.d });
		}
		my $parent = $!name.IO.parent;
		mkdir($parent) if not $!skip-mkdir and not $parent.IO.e;
		&!action.(:$!name, :@!dependencies, |%options);
	}
}
