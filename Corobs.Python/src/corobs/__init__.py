"""COROBS: Correlithm Object technology (Lawrence, *Correlithm Object Technology*, 2004) as a pure,
deterministic Python library. A port of the C# reference; same seed, same bits."""

from .bench import ReachResult, RecallResult, cascade_yield, holdout_recall, reach
from .converters import CardinalConverter, ContinuousConverter, Converter, OrdinalConverter, PlanarConverter
from .geometry import Correlithm, NCube
from .mining import Cue, Hit, Pattern, PatternMiner, PlyPoint, Rule, RuleMiner
from .seeding import SeededPrng
from .strings import StringCo

__version__ = "0.1.0"

__all__ = [
    "NCube", "Correlithm", "SeededPrng", "StringCo",
    "Converter", "CardinalConverter", "OrdinalConverter", "ContinuousConverter", "PlanarConverter",
    "PlyPoint", "Pattern", "PatternMiner", "Rule", "RuleMiner", "Hit", "Cue",
    "RecallResult", "ReachResult", "holdout_recall", "reach", "cascade_yield",
]
