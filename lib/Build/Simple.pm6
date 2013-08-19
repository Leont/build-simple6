class Build::Simple::Node { ... }

use fatal;

class Build::Simple {

	has %!nodes = {};
	
	method add_file(Str $name, :@dependencies, *%args) {
		die "Already exists" if %!nodes{$name} :exists;
		@dependencies.=map(-> $dep { %!nodes{$dep} });
		my $node = Build::Simple::Node.new(|%args, :$name, :@dependencies, :phony(0));
		%!nodes{$name} = $node;
		return;
	}

	method add_phony(Str $name, :@dependencies, *%args) {
		die "Already exists" if %!nodes{$name} :exists;
		@dependencies.=map(-> $dep { %!nodes{$dep} });
		my $node = Build::Simple::Node.new(|%args, :$name, :@dependencies, :phony(1));
		%!nodes{$name} = $node;
		return;
	}

	my method node_sorter($node, &callback, $seen is rw, %loop is copy) {
		die "Looping" if %loop{$node} :exists;
		return if $seen{$node}++;
		%loop{$node} = 1;
		self.node_sorter($_, &callback, $seen, %loop) for $node.dependencies;
		callback($node);
		return
	}

	method _sort_nodes($name) {
		my @ret;
		self.node_sorter(%!nodes{$name}, -> $node { push @ret, $node.name }, {}, {});
		return @ret;
	}

	method run($name, *%args) {
		self.node_sorter(%!nodes{$name}, -> $node { $node.run(|%args) }, {}, {});
		return;
	}
}

class Build::Simple::Node {
	has $.name;
	has $.phony;
	has $.skip_mkdir = ?$!phony;
	has @.dependencies;
	has &.action = sub {};

	method run (*%options) {
		if (!$.phony and $.name.IO.e) {
			my @files = sort grep { !.defined || !.phony() }, self.dependencies();
			my $age = $.name.IO.modified;
			return unless .d or .modified > $age for any(@files.map(*.name.IO));
		}
		my $parent = $.name.path.parent;
		mkdir($parent) if not $parent.IO.e;
		$.action.(:$.name, :$.dependencies, |%options);
	}
}
