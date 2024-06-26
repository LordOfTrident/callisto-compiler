module callisto.compiler;

import std.file;
import std.path;
import std.stdio;
import std.format;
import std.algorithm;
import callisto.util;
import callisto.error;
import callisto.parser;
import callisto.language;

class CompilerBackend {
	string   output;
	ulong    org;
	bool     orgSet;
	Compiler compiler;
	bool     useDebug;

	abstract string[] GetVersions();
	abstract string[] FinalCommands();
	abstract void NewConst(string name, long value, ErrorInfo error);

	abstract void BeginMain();

	abstract void Init();
	abstract void End();
	abstract void CompileWord(WordNode node);
	abstract void CompileInteger(IntegerNode node);
	abstract void CompileFuncDef(FuncDefNode node);
	abstract void CompileIf(IfNode node);
	abstract void CompileWhile(WhileNode node);
	abstract void CompileLet(LetNode node);
	abstract void CompileArray(ArrayNode node);
	abstract void CompileString(StringNode node);
	abstract void CompileStruct(StructNode node);
	abstract void CompileReturn(WordNode node);
	abstract void CompileConst(ConstNode node);

	final void Error(Char, A...)(ErrorInfo error, in Char[] fmt, A args) {
		ErrorBegin(error);
		stderr.writeln(format(fmt, args));
		throw new CompilerError();
	}

	final void Warn(Char, A...)(ErrorInfo error, in Char[] fmt, A args) {
		WarningBegin(error);
		stderr.writeln(format(fmt, args));
	}
}

class CompilerError : Exception {
	this() {
		super("", "", 0);
	}
}

class Compiler {
	CompilerBackend backend;
	string[]        includeDirs;
	string[]        features;
	string[]        included;
	string          outFile;

	this() {
		
	}

	void CompileNode(Node inode) {
		switch (inode.type) {
			case NodeType.Word: {
				auto node = cast(WordNode) inode;

				switch (node.name) {
					case "return": {
						backend.CompileReturn(node);
						break;
					}
					default: {
						backend.CompileWord(node);
					}
				}
				break;
			}
			case NodeType.Integer: {
				backend.CompileInteger(cast(IntegerNode) inode);
				break;
			}
			case NodeType.FuncDef: {
				backend.CompileFuncDef(cast(FuncDefNode) inode);
				break;
			}
			case NodeType.Include: {
				auto node  = cast(IncludeNode) inode;
				auto path  = format("%s/%s", dirName(node.error.file), node.path);

				if (!exists(path)) {
					bool found;
					
					foreach (ref ipath ; includeDirs) {
						path = format("%s/%s", ipath, node.path);

						if (exists(path)) {
							found = true;
							break;
						}
					}

					if (!found) {
						backend.Error(node.error, "Can't find file '%s'", node.path);
					}
				}

				if (included.canFind(path)) {
					break;
				}

				included ~= path;

				auto nodes = ParseFile(path);

				foreach (inode2 ; nodes) {
					CompileNode(inode2);
				}
				break;
			}
			case NodeType.Asm: {
				auto node       = cast(AsmNode) inode;
				backend.output ~= node.code;
				break;
			}
			case NodeType.If: {
				backend.CompileIf(cast(IfNode) inode);
				break;
			}
			case NodeType.While: {
				auto node = cast(WhileNode) inode;

				NodeType[] allowedTypes = [
					NodeType.Word, NodeType.Integer
				];

				foreach (ref inode2 ; node.condition) {
					if (!allowedTypes.canFind(inode2.type)) {
						backend.Error(
							inode2.error, "While conditions can't contain %s",
							inode2.type
						);
					}
				}

				backend.CompileWhile(node);
				break;
			}
			case NodeType.Let: {
				backend.CompileLet(cast(LetNode) inode);
				break;
			}
			case NodeType.Implements: {
				auto node = cast(ImplementsNode) inode;

				if (features.canFind(node.feature)) {
					CompileNode(node.node);
				}
				break;
			}
			case NodeType.Feature: {
				auto node = cast(FeatureNode) inode;

				features ~= node.feature;
				break;
			}
			case NodeType.Requires: {
				auto node = cast(RequiresNode) inode;

				if (!features.canFind(node.feature)) {
					backend.Error(node.error, "Feature '%s' required", node.feature);
				}
				break;
			}
			case NodeType.Array: {
				backend.CompileArray(cast(ArrayNode) inode);
				break;
			}
			case NodeType.String: {
				backend.CompileString(cast(StringNode) inode);
				break;
			}
			case NodeType.Struct: {
				backend.CompileStruct(cast(StructNode) inode);
				break;
			}
			case NodeType.Const: {
				backend.CompileConst(cast(ConstNode) inode);
				break;
			}
			default: assert(0);
		}
	}

	void Compile(Node[] nodes) {
		assert(backend !is null);

		backend.compiler = this;
		backend.Init();

		Node[] header;
		Node[] main;

		foreach (ref node ; nodes) {
			switch (node.type) {
				case NodeType.FuncDef:
				case NodeType.Include:
				case NodeType.Let:
				case NodeType.Implements:
				case NodeType.Feature:
				case NodeType.Requires:
				case NodeType.Struct:
				case NodeType.Const: {
					header ~= node;
					break;
				}
				default: main ~= node;
			}
		}

		foreach (ref node ; header) {
			CompileNode(node);
		}

		backend.BeginMain();

		foreach (ref node ; main) {
			CompileNode(node);
		}

		backend.End();
	}
}
