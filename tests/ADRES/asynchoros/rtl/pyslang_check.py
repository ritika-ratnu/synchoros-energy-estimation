import sys
import pyslang

FILES = [
    "pkg.sv",
    "config_mem.sv",
    "reg_file.sv",
    "output_register.sv",
    "simple_alu.sv",
    "tile.sv",
    "controller.sv",
    "ADRES.sv",
]

sm = pyslang.SourceManager()
comp = pyslang.ast.Compilation()
for filename in FILES:
    comp.addSyntaxTree(pyslang.syntax.SyntaxTree.fromFile(filename, sm))
comp.getRoot()
diagnostics = comp.getAllDiagnostics()
if diagnostics:
    print(pyslang.DiagnosticEngine.reportAll(sm, diagnostics))
errors = sum(1 for diag in diagnostics if diag.isError())
print(f"diagnostics={len(diagnostics)} errors={errors}")
sys.exit(1 if errors else 0)
