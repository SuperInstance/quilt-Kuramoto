"""tower — compile a physical-quantity cell spec into exact, float-free C.

The generator refuses to emit code when the chosen basis does not represent the
range exactly. It does not approximate and then apologise in a comment.
"""

from .emit import emit_c
from .load import load_spec, loads_spec
from .spec import CellSpec, SpecError, parse_basis, parse_equation
from .verify import VerifyResult, find_compiler, verify

__version__ = "0.1.0"
__all__ = ["emit_c", "load_spec", "loads_spec", "CellSpec", "SpecError",
           "parse_basis", "parse_equation", "verify", "VerifyResult",
           "find_compiler"]
