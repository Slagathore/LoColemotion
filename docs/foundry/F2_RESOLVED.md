# F2 - RESOLVED (physics authority + shared-face seam)

Status: DECIDED + IMPLEMENTED + TESTED. Re-applied after a repo revert wiped the (uncommitted)
first pass; now committed. Settled directly against the live code, not the earlier review run (whose
judge/QA stages collapsed on session-limit banners).

## Authority table (one runtime source per quantity)
Two runtime lanes only: authored descriptor (Lane B) else analytic-from-skeleton. mesh-integrated
is an EXPORT-TIME descriptor generator, never a runtime source.

| Quantity | Canonical source | Resolved | Seam? |
|---|---|---|---|
| mass | descriptor.mass else density*volume | _fold, once | none |
| volume | descriptor.total_volume else _shape_volume | _fold, once | none |
| center_of_mass | descriptor.center_of_mass else centroid*scale | _fold, once | none |
| surface_area | descriptor.surface_metabolic else _shape_surface | _fold, once | WAS the B-IF seam - fixed |
| inertia | analytic (descriptor tensor deferred -> F1) | probe-time | none today |

ResolvedPart is the sole runtime carrier; the ONLY post-_fold mutation is the surface-area haircut.

## Haircut rule (the fix)
adjust_internal_faces removes a buried-face estimate. `shared` is a skeleton-sourced ABSOLUTE area
(a placement fact). Per-part authority branch (_apply_internal_face_haircut):
- PRIMITIVE (has_descriptor == false): surface_area = maxf(surface_area - shared, EPS) - LITERAL,
  unchanged from pre-F2, byte-identical -> L4. Do not touch this branch.
- DESCRIPTOR (has_descriptor == true): remove a dimensionless COVERAGE FRACTION of the canonical
  descriptor SA: f = clampf(shared / _shape_surface(dims), 0, 1); surface_area *= (1 - f). f is a
  skeleton/skeleton ratio (scale-invariant, leaks no magnitude), so the amount removed is
  descriptor-sourced. Descriptor owns "how much surface", placement owns "what fraction is buried".

Why not a global fractional rewrite (the earlier design's mistake): a part is trimmed once per child across
loop iterations, so *= (1-f) of the CURRENT value diverges from -shared after the first trim, breaking
primitive byte-identity. The per-part branch keeps the primitive op identical.

## Test evidence - tests/test_internal_face_authority.gd (6/6)
- primitive total_sa == 2.96 (literal -shared on both parts)
- descriptor trim == 0.9674 (fractional), and != 0.9928 (old absolute)
- trimmed SA exactly LINEAR in surface_metabolic (seam closed: magnitude descriptor-sourced)
- child trimmed SA(s=2) == 4 x SA(s=1) (coverage fraction scale-invariant)
Regression: golden 38/38, descriptor 13/13, tier-D 5/5 - primitive path byte-identical (L4).

## Code touched (CharacteristicsEvaluator.gd)
- ResolvedPart: + var has_descriptor: bool = false
- _fold descriptor branch: sets p.has_descriptor = true; B-IF bite note updated to RESOLVED
- adjust_internal_faces: per-part branch via new _apply_internal_face_haircut

## Note on baseline
Committed baseline golden count is 38 (commit 77c1f7b, F4+F5). A prior working tree showed 49; the
extra ~11 checks plus the B3 ResolvedPart.joint wiring were uncommitted and lost in the same revert.
That is independent of F2 (no F2 edit touches joint) but should be re-landed separately if wanted.

## Open / deferred
- Inertia authority: descriptor.inertia_tensor deferred; analytic _subtree_inertia is sole source
  today. That is F1 (mesh integration) territory - parked, not bankable per the F1 audit.
