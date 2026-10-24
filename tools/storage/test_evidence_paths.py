"""Exercise production output guards through native junctions; no worlds or builds."""
import contextlib
import importlib
import io
import os
from pathlib import Path
import subprocess
import sys
import types
import unittest
from unittest.mock import patch
import uuid
import zipfile

ROOT=Path(os.environ.get("LOCOLEMOTION_STORAGE_TEST_REPO",Path(__file__).resolve().parents[2]))
for folder in ("sdk/explorer/studio","sdk/explorer","sdk/release"):
    sys.path.insert(0,str(ROOT/folder))
OUTPUT=Path(os.environ["STORAGE_TEST_OUTPUT"])

class OutputBoundaryReached(Exception):
    pass

class JunctionOutputControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture=OUTPUT/("junction-output-fixture-"+uuid.uuid4().hex)
        cls.fixture.mkdir()
        cls.project=cls.fixture/"logical"/"LoColemotion"
        cls.project.mkdir(parents=True)
        cls.logical=cls.project.parent/"SporeSpore_Evidence"
        cls.physical=cls.fixture/"store";cls.physical.mkdir()
        cls.outside=cls.fixture/"outside";cls.outside.mkdir()
        for link,target in ((cls.logical,cls.physical),(cls.physical/"escape",cls.outside)):
            # These are new fixture paths only; preserve all fixtures and links.
            script=cls.fixture/("junction-"+uuid.uuid4().hex+".ps1")
            script.write_text("param([string]$Path,[string]$Target)\n$ErrorActionPreference='Stop'\nNew-Item -ItemType Junction -Path $Path -Target $Target | Out-Null\n",encoding="utf-8",newline="\n")
            subprocess.run(["pwsh","-NoProfile","-File",str(script),str(link),str(target)],
                cwd=ROOT,check=True,capture_output=True,text=True)
        assert cls.logical.resolve()==cls.physical
        assert (cls.logical/"escape").resolve()==cls.outside
        cls.config=cls.fixture/"config.json";cls.config.write_text("{}",encoding="utf-8")
        cls.modules={name:importlib.import_module(name) for name in (
            "materialize_studio","build_optimized_godot","run_godot_cache_diagnostic",
            "run_mujoco_sandbox","build_engine_integration_figures",
            "test_sdk1_package_adoption")}
        # Importing the runtime is allowed; all world constructors and stepping
        # are forbidden before any production entrypoint is exercised.
        import mujoco
        cls.world_guards=[]
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guard=patch.object(mujoco,name,side_effect=AssertionError("World opened by path control"))
            guard.start();cls.world_guards.append(guard)
        cls.addClassCleanup(lambda:[g.stop() for g in reversed(cls.world_guards)])

    def git_or_metadata(self,command,**kwargs):
        if command[0]!="git":
            raise AssertionError("Unexpected subprocess: "+repr(command))
        words=command[1:]
        if words[:2]==["rev-parse","--show-toplevel"]:
            return self.project.as_posix()
        if words[:2]==["remote","get-url"]:
            return "https://github.com/Slagathore/LoColemotion.git"
        if words and words[0]=="status":return ""
        if words and words[0]=="ls-files":return ""
        if words and words[0]=="ls-remote":return "1"*40+"\trefs/heads/main"
        if words and words[0]=="archive":
            data=io.BytesIO()
            with zipfile.ZipFile(data,"w"):pass
            return data.getvalue()
        if words and words[0]=="rev-parse":return "1"*40
        raise AssertionError("Unexpected Git invocation: "+repr(command))

    def invoke_guard(self,name,target):
        module=self.modules[name]
        expected_directory=target
        def stop_at_output(path,*args,**kwargs):
            if path.resolve()!=expected_directory.resolve():
                raise AssertionError("Unexpected filesystem mutation: "+str(path))
            raise OutputBoundaryReached()
        fake_mpl=types.ModuleType("matplotlib");fake_mpl.__path__=[]
        fake_mpl.use=lambda *a,**k:None
        fake_plot=types.ModuleType("matplotlib.pyplot")
        fake_patches=types.ModuleType("matplotlib.patches")
        fake_patches.FancyBboxPatch=object
        with contextlib.ExitStack() as stack:
            stack.enter_context(patch.object(module,"ROOT",self.project))
            stack.enter_context(patch.object(subprocess,"check_output",side_effect=self.git_or_metadata))
            stack.enter_context(patch.object(subprocess,"Popen",side_effect=AssertionError("Unexpected child")))
            stack.enter_context(patch.object(Path,"mkdir",stop_at_output))
            if name=="materialize_studio":
                stack.enter_context(patch.object(module,"EVIDENCE",self.logical))
                stack.enter_context(patch.object(module,"verify_source",return_value="1"*40))
                return module.materialize(target,self.config)
            if name=="build_engine_integration_figures":
                stack.enter_context(patch.dict(sys.modules,{"matplotlib":fake_mpl,
                    "matplotlib.pyplot":fake_plot,"matplotlib.patches":fake_patches}))
                stack.enter_context(patch.object(module,"load_trace",return_value=(None,None,None,None)))
                return module.export(target)
            if name=="test_sdk1_package_adoption":
                return module.run(target)
            argv=[name,"--output",str(target)]
            argv+=["--config",str(self.config)]
            if name=="run_mujoco_sandbox":
                argv+=["--spec",str(self.config)]
                stack.enter_context(patch.object(module,"validate",return_value={}))
            if name=="build_optimized_godot":
                original_exists=Path.exists
                stack.enter_context(patch.object(Path,"exists",lambda p: False if p.name=="custom.py" else original_exists(p)))
                stack.enter_context(patch.object(module.shutil,"disk_usage",
                    return_value=types.SimpleNamespace(free=100*2**30)))
            stack.enter_context(patch.object(sys,"argv",argv))
            return module.main()

    def check_entrypoint(self,name):
        for root in (self.logical,self.physical):
            target=root/"new-output"
            with self.subTest(entrypoint=name,accepted=str(root)):
                with self.assertRaises(OutputBoundaryReached):
                    self.invoke_guard(name,target)
        for root in (self.outside,self.logical/"escape"):
            target=root/"forbidden-output"
            with self.subTest(entrypoint=name,rejected=str(root)):
                with self.assertRaises((ValueError,AssertionError)) as caught:
                    self.invoke_guard(name,target)
                expected={"materialize_studio":"Use the durable evidence root",
                    "test_sdk1_package_adoption":"Use durable evidence root"}.get(name,"Durable evidence root required")
                self.assertEqual(str(caught.exception),expected)
                self.assertFalse(target.exists())

    def test_materialization(self):self.check_entrypoint("materialize_studio")
    def test_optimized_engine_output(self):self.check_entrypoint("build_optimized_godot")
    def test_godot_diagnostic_output(self):self.check_entrypoint("run_godot_cache_diagnostic")
    def test_mujoco_sandbox_output(self):self.check_entrypoint("run_mujoco_sandbox")
    def test_integration_figure_output(self):self.check_entrypoint("build_engine_integration_figures")
    def test_package_adoption_output(self):self.check_entrypoint("test_sdk1_package_adoption")

if __name__=="__main__":
    unittest.main(verbosity=2)
