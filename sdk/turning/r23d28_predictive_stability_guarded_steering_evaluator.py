"""R23D28 configuration wrapper around the inherited finite Rapier evaluator."""

from __future__ import annotations

import os

os.environ["SPORESPORE_QSDK_R23_PREDICTIVE_VARIANT"] = "r23d28"

from r23d27_stability_guarded_steering_evaluator import main


if __name__ == "__main__":
    raise SystemExit(main())
