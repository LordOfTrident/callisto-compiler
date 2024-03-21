module callisto.app;

import std.conv;
import std.file;
import std.stdio;
import std.string;
import callisto.compiler;
import callisto.language;
import callisto.backends.rm86;

const static string usage = "
Usage: %s FILE [FLAGS]

Flags:
	-o FILE    - Sets the output assembly file to FILE (out.asm by default)
	--org ADDR - Sets ORG value for compiler backend's assembly, ADDR is hex
	-i PATH    - Adds PATH to the list of include directories
";

int main(string[] args) {
	if (args.length == 0) {
		writeln("what");
		return 1;
	}
	if (args.length == 1) {
		writefln(usage.strip(), args[0]);
		return 0;
	}

	string   file;
	string   outFile = "out.asm";
	ulong    org;
	bool     orgSet;
	string[] includeDirs;

	for (size_t i = 1; i < args.length; ++ i) {
		if (args[i][0] == '-') {
			switch (args[i]) {
				case "-o": {
					++ i;

					if (i >= args.length) {
						stderr.writeln("-o requires FILE parameter");
						return 1;
					}
					if (outFile != "") {
						stderr.writeln("Output file set multiple times");
						return 1;
					}

					outFile = args[i];
					break;
				}
				case "--org": {
					++ i;

					if (i >= args.length) {
						stderr.writeln("--org requires ADDR parameter");
						return 1;
					}

					try {
						org = args[i].to!ulong(16);
					}
					catch (ConvException) {
						stderr.writeln("--org parameter must be hexadecimal");
						return 1;
					}
					orgSet = true;
					break;
				}
				case "-i": {
					++ i;

					if (i >= args.length) {
						stderr.writeln("-i requires PATH parameter");
						return 1;
					}

					includeDirs ~= args[i];
					break;
				}
				default: {
					stderr.writefln("Unknown flag '%s'", args[i]);
					return 1;
				}
			}
		}
		else {
			if (file != "") {
				stderr.writeln("Source file set multiple times");
				return 1;
			}

			file = args[i];
		}
	}

	if (file == "") {
		stderr.writeln("No source files");
		return 1;
	}

	auto nodes = ParseFile(file);

	auto compiler           = new Compiler();
	compiler.backend        = new BackendRM86();
	compiler.backend.org    = org;
	compiler.backend.orgSet = orgSet;
	compiler.includeDirs    = includeDirs;

	try {
		compiler.Compile(nodes);
	}
	catch (CompilerError) {
		return 1;
	}

	std.file.write(outFile, compiler.backend.output);

	return 0;
}
