class Build::Simple::Node { ... }

use fatal;

class Build::Simple {

	has %!nodes = {};
	
	method add_file(Str $name, *%args) {
		die "Already exists" if %!nodes{$name} :exists;
		my $node = Build::Simple::Node.new(|%args, :phony(0));
		%!nodes{$name} = $node;
		return;
	}

	method add_phony(Str $name, *%args) {
		die "Already exists" if %!nodes{$name} :exists;
		my $node = Build::Simple::Node.new(|%args, :phony(1));
		%!nodes{$name} = $node;
		return;
	}

	my method node_sorter($current, &callback, $seen is rw, %loop is copy) {
		die "Looping" if %loop{$current} :exists;
		return if $seen{$current}++;
		my $node = %!nodes{$current};
		%loop{$current} = 1;
		self.node_sorter($_, &callback, $seen, %loop) for $node.dependencies;
		callback($current, $node);
		return
	}

	method _sort_nodes($node) {
		my @ret;
		self.node_sorter($node, -> $name, $node { push @ret, $name }, {}, {});
		return @ret;
	}

	method _is_phony($name) {
		my $node = %!nodes{$name};
		return $node ?? $node.phony !! 0;
	}

	method run($name, *%args) {
		self.node_sorter($name, -> $name, $node { $node.run($name, self, |%args) }, {}, {});
		return;
	}
}

class Build::Simple::Node {
	has $.phony;
	has $.skip_mkdir = ?$!phony;
	has @.dependencies;
	has &.action = sub {};

	method run ($name, $graph, *%options) {
		if (!$.phony and $name.IO.e) {
			my @files = sort grep { !$graph._is_phony($_) }, self.dependencies();
			my $age = $name.IO.modified;
			return unless .IO.d or .IO.modified > $age for any(@files);
		}
		my $parent = $name.path.parent;
		mkdir($parent) if not $parent.IO.e;
		self.action.(:$name, :dependencies(self.dependencies), |%options);
	}
}
