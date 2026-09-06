"""tminus-band — exact tolerance bands for predict-and-confirm coordination.

Fire on what is known, not on how many said it.
"""

from .band import (Banded, Contradiction, IBox, Tightened, basis_meets,
                   isqrt_ceil, isqrt_floor, max_basis)
from .event import BandedCountdown, FireReason, Report

__version__ = "0.1.0"
__all__ = ["Banded", "Contradiction", "IBox", "Tightened", "basis_meets",
           "isqrt_ceil", "isqrt_floor", "max_basis",
           "BandedCountdown", "FireReason", "Report"]
