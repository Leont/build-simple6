class Build::Simple::Node { ... }

use fatal;

class Build::Simple {

	has %!nodes = {};
	
	method add_file(Str $name, :@dependencies, *%args) {
		die "Already exists" if %!nodes{$name} :exists;
		@dependencies.=map(-> $dep { %!nodes{$dep} });
		my $node = Build::Simple::Node.new(|%args, :$name, :@dependencies, :!phony);
		%!nodes{$name} = $node;
		return;
	}

	method add_phony(Str $name, :@dependencies, *%args) {
		die "Already exists" if %!nodes{$name} :exists;
		@dependencies.=map(-> $dep { %!nodes{$dep} });
		my $node = Build::Simple::Node.new(|%args, :$name, :@dependencies, :phony);
		%!nodes{$name} = $node;
		return;
	}

	my method node_sorter($node, %seen is rw, %loop is copy) {
		die "Looping" if %loop{$node} :exists;
		return if %seen{$node}++;
		%loop{$node} = 1;
		self.node_sorter($_, %seen, %loop) for $node.dependencies;
		take $node;
		return
	}

	my method nodes_for($name) {
		return gather { $.node_sorter(%!nodes{$name}, {}, {}) };
	}

	method _sort_nodes($name) {
		@.nodes_for($name) ==> map -> $node { $node.name };
	}

	method run($name, *%args) {
		for @.nodes_for($name) -> $node {
			$node.run(%args)
		}
		return;
	}
}

class Build::Simple::Node {
	has $.name;
	has $.phony;
	has $.skip_mkdir = ?$!phony;
	has @.dependencies;
	has &.action = sub {};

	method run (%options) {
		if (!$.phony and $.name.IO.e) {
			my @files = sort grep { !.defined || !.phony() }, @.dependencies;
			my $age = $.name.IO.modified;
			return unless .d or .modified > $age for any(@files.map(*.name.IO));
		}
		my $parent = $.name.path.parent;
		mkdir($parent) if not $.skip_mkdir and not $parent.IO.e;
		$.action.(:$.name, :@.dependencies, |%options);
	}
}
