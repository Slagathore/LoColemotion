"""Historical declarations and current L15 sources cannot stand in for each other."""

import copy
import json
from pathlib import Path
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_authority_materializer as materializer
import qsdk_r10f_l15_source_binding as binding
import qsdk_r10f_zero_world_implementation as implementation
import qsdk_r10f_l14_runtime_binding as runtime
import qsdk_r10f_dependency_closure as dependency


class L15SourceBinding(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = binding.git("rev-parse", "HEAD").decode().strip()
        cls.root = json.loads((ROOT / binding.frozen.DESIGN).read_bytes())
        cls.receipt = binding.bind_root_sources(cls.source, cls.root)
        cls.cases = []
        for pair in cls.receipt["source_pairs"]:
            old = pair["preserved_observed_source"]
            current = pair["exact_successor_source"]
            historical_raw = binding.git(
                "cat-file", "blob", old["source_commit"] + ":" + old["path"]
            )
            current_raw = (ROOT / current["path"]).read_bytes()
            cls.cases.append(
                [
                    pair["historical_root_authority"],
                    old,
                    historical_raw,
                    old["git_blob"],
                    current,
                    current_raw,
                    cls.source,
                    current["git_blob_oid"],
                ]
            )

    def test_actual_source_receipt_preserves_old_and_new_identities_separately(self):
        receipt = self.receipt
        self.assertIs(receipt["ok"], True)
        self.assertEqual(2, receipt["source_pair_count"])
        self.assertEqual(self.source, receipt["source_commit"])
        for case in self.cases:
            binding.validate_source_pair(*case)
            self.assertIn(case[0], self.root["bound_authorities"])
            self.assertNotEqual(case[0]["git_blob_oid"], case[4]["git_blob_oid"])
        for key in (
            "historical_root_authorities_rewritten",
            "legacy_l13_adapter_permission_widened",
            "whole_recursive_source_manifest_qualified",
            "whole_route_qualified",
            "official_qualification_consumed",
            "source_or_evidence_files_written",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(receipt[key], False)
        for key in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "scene_tree_insertion_count",
            "native_physics_read_count",
            "solver_step_count",
        ):
            self.assertIs(type(receipt[key]), int)
            self.assertEqual(0, receipt[key])

    def test_every_pair_binding_field_and_both_raw_sources_are_independent(self):
        controls = 0
        for case in self.cases:
            for index in (0, 1, 4):
                for key, original in case[index].items():
                    values = [None, True, str(original) + "_changed"]
                    if type(original) is int:
                        values.extend([float(original), str(original), original + 1])
                    for value in values:
                        changed = copy.deepcopy(case)
                        changed[index][key] = value
                        with self.subTest(
                            source=case[0]["path"], index=index, field=key, value=value
                        ), self.assertRaises(ValueError):
                            binding.validate_source_pair(*changed)
                        controls += 1
                    changed = copy.deepcopy(case)
                    del changed[index][key]
                    with self.assertRaises(ValueError):
                        binding.validate_source_pair(*changed)
                    controls += 1
                changed = copy.deepcopy(case)
                changed[index]["undeclared"] = True
                with self.assertRaises(ValueError):
                    binding.validate_source_pair(*changed)
                controls += 1
            for index in (2, 3, 5, 6, 7):
                changed = copy.deepcopy(case)
                changed[index] += b" " if type(changed[index]) is bytes else "x"
                with self.assertRaises(ValueError):
                    binding.validate_source_pair(*changed)
                controls += 1
            old_as_current = copy.deepcopy(case)
            old_as_current[4] = {
                **binding.frozen.blob_identity(case[0]["path"], case[2]),
                "source_commit": self.source,
            }
            old_as_current[5] = case[2]
            old_as_current[7] = case[3]
            with self.assertRaisesRegex(ValueError, "SUCCESSOR_PAIR"):
                binding.validate_source_pair(*old_as_current)
            controls += 1
        self.assertEqual(156, controls)

    def test_rehashed_worktree_substitution_is_rejected_for_every_current_role(self):
        design = json.loads(binding.design_audit.DESIGN.read_bytes())
        paths = {
            binding.frozen.DESIGN,
            binding.design_audit.DESIGN.relative_to(ROOT).as_posix(),
            *binding.SOURCE_ROLES,
            *(entry["path"] for entry in design["bound_authorities"]),
        }
        for relative in sorted(paths):
            raw = (ROOT / relative).read_bytes()
            with self.subTest(path=relative), mock.patch.object(
                binding, "read_worktree_source", return_value=raw + b" "
            ), self.assertRaisesRegex(ValueError, "CURRENT_SOURCE"):
                binding.bind_current_source(relative, self.source)
        self.assertEqual(12, len(paths))

    def test_altered_root_declaration_and_ambiguous_commit_are_not_permissions(self):
        mutations = []
        changed = copy.deepcopy(self.root)
        changed["authored_parent_commit"] = self.source
        mutations.append(changed)
        for index in (7, 8, 13):
            changed = copy.deepcopy(self.root)
            changed["bound_authorities"][index]["byte_length"] = float(
                changed["bound_authorities"][index]["byte_length"]
            )
            mutations.append(changed)
        changed = copy.deepcopy(self.root)
        changed["bound_authorities"].pop()
        mutations.append(changed)
        for changed in mutations:
            with self.assertRaisesRegex(ValueError, "ROOT_DESIGN_PRESERVED"):
                binding.bind_root_sources(self.source, changed)
        for commit in ("HEAD", self.source[:12], None, True, 1, "f" * 39):
            with self.subTest(commit=commit), self.assertRaisesRegex(
                ValueError, "SOURCE_COMMIT"
            ):
                binding.bind_root_sources(commit, self.root)

    def test_actual_materializer_requires_explicit_mode_and_preserves_legacy_refusal(
        self,
    ):
        design, authorities = materializer.design_binding(
            self.source, require_l15_sources=True
        )
        self.assertEqual(self.root, design)
        self.assertEqual(self.root["bound_authorities"], authorities)
        self.assertEqual("QSDK-R10F-L14", materializer.REPAIR_ID)
        self.assertEqual(
            "qsdk_r10f_dependency_manifest_v19.json", materializer.MANIFEST_PATH.name
        )
        with self.assertRaisesRegex(
            materializer.MaterializationFailure, "DESIGN_AUTHORITY_7_IDENTITY"
        ):
            materializer.design_binding(self.source)
        for mode in (0, 1, "true", None):
            with self.assertRaisesRegex(
                materializer.MaterializationFailure, "DESIGN_L15_MODE_KIND"
            ):
                materializer.design_binding(self.source, require_l15_sources=mode)
            with self.assertRaisesRegex(
                implementation.AuditFailure, "PREFLIGHT_L15_MODE_KIND"
            ):
                implementation.audit_source_authority_preflight(
                    require_l15_sources=mode
                )

    def test_enclosing_materializer_rejects_changed_source_bytes_before_handoff(self):
        original = binding.read_worktree_source
        for target in binding.SOURCE_ROLES:

            def changed_source(relative):
                raw = original(relative)
                return raw + b" " if relative == target else raw

            with self.subTest(path=target), mock.patch.object(
                binding, "read_worktree_source", side_effect=changed_source
            ), self.assertRaisesRegex(
                materializer.MaterializationFailure,
                "DESIGN_L15_SOURCE_HANDOFF:.*CURRENT_SOURCE",
            ):
                materializer.design_binding(self.source, require_l15_sources=True)

    def test_complete_qualification_input_producer_and_actual_materializer_reader(self):
        receipt = implementation.audit_l15_qualification_inputs(
            self.source, official_qualification=False
        )
        self.assertEqual(240, receipt["qualified_source_path_count"])
        self.assertEqual(15, len(receipt["historical_root_authorities"]))
        self.assertEqual(2, receipt["root_source_binding"]["source_pair_count"])
        self.assertEqual(5, receipt["runtime_binding"]["image_count"])
        self.assertEqual(
            receipt["complete_dependency_receipt"]["qualified_source_paths"],
            [item["path"] for item in receipt["qualified_source_bindings"]],
        )
        self.assertEqual(
            receipt["complete_dependency_receipt"]["manifest_raw_sha256"],
            receipt["dependency_manifest"]["raw_sha256"],
        )
        self.assertIs(
            receipt["all_source_git_projections_equal_commit"],
            not receipt["changed_or_uncommitted_source_paths"],
        )
        for name in (
            "qualification_or_physical_identity_created",
            "complete_implementation_qualified",
            "official_expected_context_origin_authenticated",
            "worker_report_used_as_source",
            "source_or_evidence_files_written",
            "physics_state_modified",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(receipt[name], False)
        self.assertEqual("QSDK-R10F-L14", materializer.REPAIR_ID)
        self.assertEqual("QSDK-R10F-L14", implementation.REPAIR_ID)

    def test_complete_input_reader_refuses_every_field_and_individual_source_binding(
        self,
    ):
        receipt = binding.bind_qualification_inputs(self.source)
        controls = 0
        for name in receipt:
            for value, remove in ((None, True), (None, False), ("changed", False)):
                changed = copy.deepcopy(receipt)
                if remove:
                    del changed[name]
                else:
                    changed[name] = value
                with self.subTest(field=name, remove=remove), self.assertRaisesRegex(
                    ValueError, "QUALIFICATION_COMPLETE_INPUT_BINDING"
                ):
                    binding.validate_qualification_inputs(changed, expected=receipt)
                controls += 1
        source_controls = 0
        for index, item in enumerate(receipt["qualified_source_bindings"]):
            for name, value in item.items():
                changed = copy.deepcopy(receipt)
                changed["qualified_source_bindings"][index][name] = (
                    float(value) if type(value) is int else str(value) + "x"
                )
                with self.subTest(
                    source=item["path"], field=name
                ), self.assertRaisesRegex(
                    ValueError, "QUALIFICATION_COMPLETE_INPUT_BINDING"
                ):
                    binding.validate_qualification_inputs(changed, expected=receipt)
                source_controls += 1
        self.assertEqual(240 * 6, source_controls)
        for expected in (
            None,
            {},
            {key: receipt[key] for key in receipt if key != "root_source_binding"},
        ):
            with self.assertRaises(ValueError):
                binding.validate_qualification_inputs(receipt, expected=expected)
        # Adding a success alias or using bool/float for integer zero cannot
        # evade whole-record, exact-number-kind equality.
        for name, value in (
            ("extra", True),
            ("solver_step_count", False),
            ("solver_step_count", 0.0),
            ("physical_execution_authorized", 0),
        ):
            changed = {**receipt, name: value}
            with self.assertRaises(ValueError):
                binding.validate_qualification_inputs(changed, expected=receipt)
            controls += 1
        print("L15_QUALIFICATION_INPUT_HEADER_CONTROLS=" + str(controls), flush=True)
        print(
            "L15_QUALIFICATION_INPUT_SOURCE_CONTROLS=" + str(source_controls),
            flush=True,
        )

    def test_input_reader_requires_exact_mode_commit_and_committed_bytes(self):
        for mode in (None, 0, 1, "true"):
            with mock.patch.object(binding, "committed_source_objects") as unopened:
                with self.assertRaisesRegex(ValueError, "QUALIFICATION_MODE_KIND"):
                    binding.bind_qualification_inputs(
                        self.source, require_committed_source=mode
                    )
                unopened.assert_not_called()
            with self.assertRaisesRegex(
                implementation.AuditFailure, "QUALIFICATION_INPUT_MODE_KIND"
            ):
                implementation.audit_l15_qualification_inputs(
                    self.source, official_qualification=mode
                )
        for source in ("HEAD", self.source[:12], None, True, "f" * 39):
            with self.assertRaisesRegex(ValueError, "QUALIFICATION_SOURCE_COMMIT"):
                binding.bind_qualification_inputs(source)
        predecessor = binding.git("rev-parse", "HEAD^").decode().strip()
        with self.assertRaisesRegex(ValueError, "QUALIFICATION_SOURCE_NOT_HEAD"):
            binding.bind_qualification_inputs(predecessor)
        receipt = binding.bind_qualification_inputs(self.source)
        if receipt["changed_or_uncommitted_source_paths"]:
            with self.assertRaisesRegex(
                ValueError, "QUALIFICATION_SOURCE_GIT_PROJECTION_NOT_COMMITTED"
            ):
                binding.bind_qualification_inputs(
                    self.source, require_committed_source=True
                )
        else:
            committed = binding.bind_qualification_inputs(
                self.source, require_committed_source=True
            )
            self.assertIs(committed["all_source_git_projections_equal_commit"], True)
            self.assertIs(committed["committed_source_required"], True)

    def test_git_storage_projection_preserves_original_bytes_and_forbids_other_transforms(
        self,
    ):
        target = (
            "sdk/adapters/godot/gdscript/qsdk_r10f_native_impulse_pair_receipt_v1.gd"
        )
        raw = (ROOT / target).read_bytes()
        attributes = binding.qualification_git_attributes([target])[target]
        record = binding.qualification_source_projection(target, raw, attributes)
        self.assertIn(b"\r\n", raw)
        self.assertEqual(
            binding.git("hash-object", "--no-filters", "--", target).decode().strip(),
            record["git_blob_oid"],
        )
        self.assertEqual(
            binding.git("hash-object", "--", target).decode().strip(),
            record["git_storage_projection"]["git_blob_oid"],
        )
        self.assertEqual(
            binding.git("rev-parse", self.source + ":" + target).decode().strip(),
            record["git_storage_projection"]["git_blob_oid"],
        )
        self.assertNotEqual(
            record["git_blob_oid"], record["git_storage_projection"]["git_blob_oid"]
        )
        self.assertEqual(raw, (ROOT / target).read_bytes())
        objects = binding.committed_source_objects(self.source)
        sources, changed = binding.qualified_source_snapshot([target], objects)
        self.assertEqual([record], sources)
        self.assertEqual([], changed)

        for text in (
            b"first\nsecond\n",
            b"first\r\nsecond\r\n",
            b"first\r\nsecond\n",
            b"first\rsecond\n",
        ):
            projected = binding.qualification_source_projection(
                target, text, attributes
            )
            expected = binding.frozen.blob_identity(
                target, text.replace(b"\r\n", b"\n")
            )
            self.assertEqual(len(text), projected["byte_length"])
            self.assertEqual(
                binding.frozen.blob_identity(target, text)["raw_sha256"],
                projected["raw_sha256"],
            )
            self.assertEqual(
                expected["git_blob_oid"],
                projected["git_storage_projection"]["git_blob_oid"],
            )
        for name in attributes:
            for value in (None, True, "a_filter_or_conversion"):
                offered = {**attributes, name: value}
                with self.assertRaisesRegex(
                    ValueError, "QUALIFICATION_ATTRIBUTE_POLICY"
                ):
                    binding.qualification_source_projection(target, raw, offered)
            with self.assertRaisesRegex(ValueError, "QUALIFICATION_ATTRIBUTE_POLICY"):
                binding.qualification_source_projection(
                    target,
                    raw,
                    {key: attributes[key] for key in attributes if key != name},
                )
        for text in (b"binary\0payload", b"not_utf8_\xff", "not_bytes"):
            with self.assertRaises(ValueError):
                binding.qualification_source_projection(target, text, attributes)

        # Refuse corrupted real Git attribute output without running a filter.
        attribute_bytes = binding.git("check-attr", "-z", *attributes, "--", target)
        for output in (
            attribute_bytes[:-1],
            attribute_bytes + attribute_bytes,
            attribute_bytes.replace(b"\0filter\0unspecified\0", b"\0filter\0custom\0"),
            attribute_bytes.replace(b"\0ident\0", b"\0eol\0"),
        ):
            with mock.patch.object(binding, "git", return_value=output):
                with self.assertRaises(ValueError):
                    binding.qualification_git_attributes([target])

    def test_source_and_runtime_drift_during_input_read_refuse_without_writes(self):
        original = binding.qualified_source_snapshot
        calls = []

        def drifting_sources(*args):
            sources, changed = original(*args)
            calls.append(len(sources))
            if len(calls) == 2:
                sources[-1]["raw_sha256"] = "sha256:" + "0" * 64
            return sources, changed

        with mock.patch.object(
            binding, "qualified_source_snapshot", side_effect=drifting_sources
        ):
            with self.assertRaisesRegex(
                ValueError, "QUALIFICATION_SOURCE_DRIFT_DURING_READ"
            ):
                binding.bind_qualification_inputs(self.source)
        self.assertEqual([240, 240], calls)
        original_runtime = runtime.bind_runtime
        reads = []

        def drifting_runtime(*args, **kwargs):
            images = original_runtime(*args, **kwargs)
            reads.append(1)
            if len(reads) == 2:
                images["images"]["godot_engine"]["raw_sha256"] = "sha256:" + "0" * 64
            return images

        with mock.patch.object(runtime, "bind_runtime", side_effect=drifting_runtime):
            with self.assertRaisesRegex(ValueError, "QUALIFICATION_RUNTIME_DRIFT"):
                binding.bind_qualification_inputs(self.source)
        self.assertEqual(2, len(reads))
        original_dependency = dependency.audit
        populations = []

        def drifting_population(*args, **kwargs):
            actual = original_dependency(*args, **kwargs)
            populations.append(1)
            if len(populations) == 2:
                actual["qualified_source_paths"] = list(
                    reversed(actual["qualified_source_paths"])
                )
            return actual

        with mock.patch.object(dependency, "audit", side_effect=drifting_population):
            with self.assertRaisesRegex(ValueError, "QUALIFICATION_DEPENDENCY_DRIFT"):
                binding.bind_qualification_inputs(self.source)
        self.assertEqual(2, len(populations))

    def test_actual_enclosing_input_reader_reopens_instead_of_trusting_offered_sources(
        self,
    ):
        receipt = binding.bind_qualification_inputs(self.source)
        original = binding.read_worktree_source
        target = "sdk/conformance/qsdk_r10f_l15_source_binding.py"

        def changed_source(relative):
            raw = original(relative)
            return raw + b"\n# source drift control\n" if relative == target else raw

        with mock.patch.object(
            binding, "read_worktree_source", side_effect=changed_source
        ):
            with self.assertRaisesRegex(
                materializer.MaterializationFailure,
                "L15_QUALIFICATION_INPUTS:.*QUALIFICATION_COMPLETE_INPUT_BINDING",
            ):
                materializer.validate_l15_qualification_inputs(
                    receipt, self.source, require_committed_source=False
                )
        with mock.patch.object(
            binding, "read_worktree_source", side_effect=OSError("input unavailable")
        ):
            with self.assertRaisesRegex(
                materializer.MaterializationFailure,
                "L15_QUALIFICATION_INPUTS:input unavailable",
            ):
                materializer.validate_l15_qualification_inputs(
                    receipt, self.source, require_committed_source=False
                )

    def test_source_snapshot_rejects_ambiguous_populations_and_nonregular_git_entries(
        self,
    ):
        target = "sdk/conformance/qsdk_r10f_l15_source_binding.py"
        objects = binding.committed_source_objects(self.source)
        for paths in ([], [target, target], [True], None, (target,)):
            with self.assertRaisesRegex(ValueError, "QUALIFICATION_SOURCE_POPULATION"):
                binding.qualified_source_snapshot(paths, objects)
        for mode, kind in (("120000", "blob"), ("160000", "commit")):
            changed = {
                **objects,
                target: {**objects[target], "mode": mode, "kind": kind},
            }
            with self.assertRaisesRegex(ValueError, "QUALIFICATION_NOT_REGULAR_SOURCE"):
                binding.qualified_source_snapshot([target], changed)


if __name__ == "__main__":
    unittest.main(verbosity=2)
