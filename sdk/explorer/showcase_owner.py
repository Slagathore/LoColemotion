"""Standalone Windows showcase owner. Run with --help; no Git/lab dependency.

The viewer never owns physics. One owner holds the operation mutex and a
kill-on-close job. A contained Python leaf waits for its permit before it
starts a native worker; all descendants inherit containment.
"""
from __future__ import annotations

import argparse
import hashlib
import ctypes as C
from ctypes import wintypes as W
import json
import os
from pathlib import Path
import queue
import re
import shutil
import socket
import subprocess
import sys
import threading
import time
import uuid
import zipfile

from showcase_model import Compiler, ENGINES, FIELDS, PROTOCOL, S169, SCOPE, StreamIdentity, generated, impulse, runnable, sha

SDK = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SDK / "conformance"))
import r10v_windows_job as jobs


def source_binding():
    paths = list((SDK/"explorer").glob("*.py")) + list((SDK/"explorer").glob("*.gd"))
    paths += list((SDK/"explorer/native_recovery").glob("*.gd"))
    paths += list((SDK/"adapters/mujoco/sporespore_mujoco_adapter").glob("*.py"))
    paths += [SDK/"explorer/recovery_sources.zip",SDK/"explorer/recovery_sources.json",
        SDK/"explorer/showcase_contract_v1.json",SDK/"python/sporespore_locomotion.py",SDK/"conformance/r10v_windows_job.py"]
    bindings={p.relative_to(SDK).as_posix():sha(p) for p in sorted(set(paths))}
    return dict(files=bindings,sha256=hashlib.sha256(json.dumps(bindings,sort_keys=True).encode()).hexdigest())


def write(path: Path, data: dict, *, presentation=False):
    temp = path.with_suffix(".writing")
    raw=json.dumps(data,allow_nan=False)
    deadline=time.monotonic()+(.05 if presentation else 10)
    # Native stream retention is independent of this coalesced display file.
    # A Windows reader/scanner can keep a rename locked during a UI stall.
    while True:
        try:
            temp.write_text(raw,encoding="utf-8")
            temp.replace(path)
            return True
        except PermissionError:
            if time.monotonic()>=deadline:
                if presentation: return False
                raise RuntimeError(f"Could not publish {path}")
            time.sleep(.01)


def contained_leaf(config: Path):
    cfg = json.loads(config.read_text(encoding="utf-8"))
    end = time.monotonic() + 30
    while not Path(cfg["permit"]).exists():
        if time.monotonic() >= end:
            raise RuntimeError("Native launch refused: job permit timed out")
        time.sleep(.01)
    if not jobs.current_in_job():
        raise RuntimeError("Native launch refused: leaf is not job-contained")
    env = {k:v for k,v in os.environ.items() if not k.startswith("SPORESPORE_")}
    env.update(cfg["env"])
    return subprocess.call(cfg["command"], cwd=cfg["cwd"], env=env)


class OwnedChild:
    def __init__(self, command, cwd, env, folder):
        self.job = jobs.Job()
        self.stdout = (folder / "stdout.log").open("w", encoding="utf-8")
        self.stderr = (folder / "stderr.log").open("w", encoding="utf-8")
        self.process = None
        permit = folder / "contained.permit"
        config = folder / "leaf.json"
        write(config, dict(command=command, cwd=str(cwd), env=env, permit=str(permit)))
        try:
            self.process = subprocess.Popen([sys.executable, "-B", str(Path(__file__).resolve()), "--leaf", str(config)],
                cwd=SDK, stdout=self.stdout, stderr=self.stderr, creationflags=subprocess.CREATE_NO_WINDOW)
            self.job.add(self.process)
            if self.process.pid not in self.job.pids():
                raise RuntimeError("Native launch containment verification failed")
            permit.write_text(str(self.process.pid), encoding="ascii")
        except BaseException:
            self.close()
            raise

    def close(self):
        identities = [jobs.identity(pid) for pid in self.job.pids()] if self.job.handle else []
        self.job.close()
        if self.process is not None:
            self.process.wait(timeout=10)
        deadline = time.monotonic()+10
        while any(item and jobs.alive(item) for item in identities):
            if time.monotonic() >= deadline: raise RuntimeError("Contained descendant did not exit")
            time.sleep(.01)
        self.stdout.close()
        self.stderr.close()


class Owner:
    def __init__(self, config: dict, folder: Path):
        self.config, self.folder = config, folder
        self.compiler = Compiler(Path(config["core"]))
        self.commands = queue.Queue()
        self.stop = threading.Event()
        self.session_thread = None
        self.descriptor = dict(S169)
        self.preview_revision = 0
        self.status = dict(state="idle", event="Ready. Build a creature or start a native session.", live_evidence="unproven")
        self.frame = {}
        self.mutex = None
        self.status_lock = threading.RLock()
        self.identity = {k: dict(path=str(Path(v).resolve()), sha256=sha(Path(v)))
            for k, v in config.items() if k in ("godot", "recovery_engine", "recovery_console", "core", "rapier", "mujoco_python", "recovery_dll")}
        self.publish()
        self.preview(S169)

    def publish(self, **changes):
        with self.status_lock:
            self.status.update(changes)
            write(self.folder / "status.json", dict(self.status, runtime=self.identity,
                source_commit=self.config["source_commit"], session_directory=str(self.folder),
                release_authority=False, physical_acceptance_authority=False))

    def preview(self, descriptor):
        if self.session_thread and self.session_thread.is_alive():
            raise ValueError("Stop the native session before changing its construction")
        compiled = self.compiler.compile(descriptor)
        if compiled.get("world_build_count") != 0:
            raise RuntimeError("Construction compiler unexpectedly created a world")
        self.descriptor = dict(descriptor)
        self.preview_revision += 1
        write(self.folder / "preview.json", dict(revision=self.preview_revision, descriptor=descriptor,
            compiled=compiled, runnable=descriptor == S169, fields=FIELDS))
        self.publish(state="idle", event="Construction valid. " + ("Exact S169 native sessions available." if descriptor == S169 else "Edited construction preview; native walking is unsupported."))

    def command(self, value):
        kind = value.get("kind")
        if kind == "generate": self.preview(generated(value["seed"]))
        elif kind == "edit": self.preview(value["descriptor"])
        elif kind == "stop": self.stop.set()
        elif kind == "kick":
            if not self.session_thread or not self.session_thread.is_alive(): raise ValueError("No live native session")
            if self.status.get("state")!="running" or not self.frame or self.frame.get("session_id")!=self.status.get("native_session"):
                raise ValueError("Wait for the first native frame before applying an impulse")
            if self.status.get("engine") == "godot_jolt":
                raise ValueError("Godot recovery has one scheduled 0.25 N·s kick at 5 simulated seconds; extra impulses are unsupported")
            self.commands.put(value)
        elif kind == "start":
            if self.session_thread and self.session_thread.is_alive(): raise ValueError("A native session already owns the app")
            runnable(self.descriptor, value["engine"], value["phase"])
            self.stop.clear()
            while not self.commands.empty(): self.commands.get_nowait()
            self.session_thread = threading.Thread(target=self.run_session, args=(value,), daemon=False)
            self.session_thread.start()
        else: raise ValueError("Unknown showcase command")

    def run_session(self, request):
        self.frame = {}
        folder = self.folder / ("native-" + uuid.uuid4().hex)
        folder.mkdir()
        engine = request["engine"]
        create = jobs.api("CreateMutexW", [C.c_void_p, W.BOOL, W.LPCWSTR], W.HANDLE)
        release = jobs.api("ReleaseMutex", [W.HANDLE])
        handle = jobs.checked(create(None, False, "Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
        acquired = False
        receipt = dict(ledger_scope=SCOPE, engine=engine, descriptor=self.descriptor, request=request,
            runtime=self.identity, source_commit=self.config["source_commit"],
            source_binding=source_binding(),
            physical_acceptance_authority=False, release_authority=False, ok=False)
        try:
            if jobs.wait(handle, 0) not in (0, 128): raise RuntimeError("Another native operation owns the global physics mutex")
            acquired = True
            for binding in self.identity.values():
                if sha(Path(binding["path"])) != binding["sha256"]: raise RuntimeError("Runtime changed after app startup")
            write(folder / "declaration.json", receipt)
            self.publish(state="preflight", engine=engine, native_session="", event="Running native zero-world checks before physics…", native_directory=str(folder))
            env=dict(os.environ, EXPLORER_TEST_CORE=self.config["core"],EXPLORER_TEST_OUTPUT=str(folder))
            safety=subprocess.run([sys.executable,"-B",str(SDK/"explorer/test_showcase.py")],cwd=SDK,env=env,capture_output=True,text=True,timeout=90)
            (folder/"safety.log").write_text(safety.stdout+safety.stderr,encoding="utf-8")
            if safety.returncode: raise RuntimeError("Showcase construction/ownership safety gate failed")
            project = self.prepare_recovery(folder,engine) if engine in ("godot_jolt","mujoco") else None
            receipt["preflight"] = self.stream_run(engine, folder / "preflight", True, request, project)
            check = receipt["preflight"]["completed"]
            if check.get("ok") is not True or check.get("summary", {}).get("world_build_count") != 0:
                raise RuntimeError("Complete worker preflight refused native launch")
            if self.stop.is_set(): raise RuntimeError("Cancelled before world construction")
            if source_binding()!=receipt["source_binding"]: raise RuntimeError("Source changed during qualification")
            self.publish(state="running", event="Live native physics • finite development session • recovery not presumed")
            receipt["physical"] = self.stream_run(engine, folder / "physical", False, request, project)
            receipt["ok"] = receipt["physical"]["completed"].get("ok") is True
            if source_binding()!=receipt["source_binding"]: raise RuntimeError("Source changed during native execution")
            if not receipt["ok"]: raise RuntimeError("Native session finalized with an infrastructure refusal")
            self.publish(state="complete", event="Native session complete. Observed outcome: " + receipt["physical"]["completed"].get("outcome", "unknown"))
        except BaseException as exc:
            receipt["error"] = f"{type(exc).__name__}: {exc}"
            self.publish(state="stopped" if self.stop.is_set() else "refused", event=receipt["error"])
        finally:
            write(folder / "receipt.json", receipt)
            if acquired: release(handle)
            jobs.close(handle)

    def prepare_recovery(self, folder, engine="godot_jolt"):
        manifest = json.loads((SDK/"explorer/recovery_sources.json").read_text())
        archive = SDK/"explorer/recovery_sources.zip"
        if sha(archive) != manifest["archive_sha256"]: raise RuntimeError("Recovery resource archive digest mismatch")
        project = folder/"recovery_app"; project.mkdir()
        with zipfile.ZipFile(archive) as packed:
            expected = {row["path"] for row in manifest["files"]}
            if set(packed.namelist()) != expected: raise RuntimeError("Recovery resource inventory mismatch")
            for row in manifest["files"]:
                destination = (project/row["path"]).resolve()
                if not destination.is_relative_to(project.resolve()): raise RuntimeError("Recovery resource path escape")
                data = packed.read(row["path"])
                if hashlib.sha256(data).hexdigest()!=row["sha256"] or len(data)!=row["byte_length"]: raise RuntimeError("Recovery resource bytes mismatch")
                destination.parent.mkdir(parents=True,exist_ok=True); destination.write_bytes(data)
        if engine=="mujoco":
            # The production bridge's dynamic canary requires the library at
            # its own SDK release path. Relocate identical bytes with the SDK.
            core=project/"sdk/target/release/sporespore_locomotion_core.dll"
            core.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(self.config["core"],core)
            if sha(core)!=self.identity["core"]["sha256"]: raise RuntimeError("Relocated MuJoCo core digest mismatch")
            return project
        shutil.copytree(SDK/"explorer/native_recovery",project/"sdk/explorer/native_recovery")
        dll = project/"sdk/target/development-candidate-r10ap-progressive-headroom-core-v1/release/sporespore_godot_adapter.dll"
        dll.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(self.config["recovery_dll"],dll)
        if sha(dll)!="76d05482da331ee4ed423f82672e2bf429222cd0efdeafa2f4f20c50a6023b81": raise RuntimeError("Recovery requires the exact V28 DLL")
        (project/"project.godot").write_text('[application]\nconfig/name="Explorer recovery worker"\n[debug]\ngdscript/warnings/shadowed_global_identifier=0\n[physics]\n3d/physics_engine="Jolt Physics"\njolt_physics_3d/simulation/velocity_steps=20\njolt_physics_3d/simulation/position_steps=4\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding="utf-8")
        # Godot's headless --script entrypoint does not run the editor's global
        # class scan. Build only that name index from these verified sources.
        classes=[]
        for source in project.rglob("*.gd"):
            text=source.read_text(encoding="utf-8-sig")
            match=re.search(r"^class_name\s+(\w+)",text,re.M)
            base=re.search(r"^extends\s+(\w+)",text,re.M)
            if match and base:
                classes.append(dict(base=base[1],**{"class":match[1]},icon="",is_abstract=False,
                    is_tool="@tool" in text,language="GDScript",path="res://"+source.relative_to(project).as_posix()))
        (project/".godot").mkdir()
        (project/".godot/global_script_class_cache.cfg").write_text("list="+json.dumps(classes,indent=2),encoding="utf-8")
        return project

    def stream_run(self, engine, folder, validate, request=None, project=None):
        folder.mkdir()
        session = uuid.uuid4().hex
        listener = socket.socket()
        listener.bind(("127.0.0.1", 0)); listener.listen(1); listener.settimeout(.1)
        address = f"127.0.0.1:{listener.getsockname()[1]}"
        env = {}
        env["PYTHONPATH"] = str(SDK / "adapters/mujoco")
        if engine=="mujoco" and project is not None: env["PYTHONPATH"]=str(project/"sdk/adapters/mujoco")
        env["SPORESPORE_LOCOMOTION_LIBRARY"] = self.config["core"]
        if engine=="mujoco" and project is not None:
            env["SPORESPORE_LOCOMOTION_LIBRARY"]=str(project/"sdk/target/release/sporespore_locomotion_core.dll")
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        base = [self.config["rapier"]] if engine == "rapier_parry" else [self.config["mujoco_python"], "-B", "-m", "sporespore_mujoco_adapter.live_explorer_worker"]
        args = ["--connect", address, "--session", session]
        args += ["--validate-only"] if validate else ["--source-commit", self.config["source_commit"], "--realtime", "--wait-for-start"]
        if engine == "godot_jolt":
            config = dict(id=session,parent_id=uuid.uuid4().hex,phase=request["phase"],connect=address,
                validate_only=validate,permit=str(folder/"contained.permit"),output=str(folder/"recovery.json"),
                source_commit=self.config["source_commit"],images={})
            for role, key in (("engine","recovery_engine"),("console","recovery_console")):
                config["images"][role]=dict(self.identity[key],length=Path(self.config[key]).stat().st_size)
            write(folder/"recovery_config.json",config)
            env["SPORESPORE_EXPLORER_CONFIG"]=str(folder/"recovery_config.json")
            base=[self.config["recovery_console"],"--headless","--path",str(project),"--script","res://sdk/explorer/native_recovery/worker.gd"]
            args=[]
        child, peer = None, None
        started = time.monotonic(); completed = None; total = 0; last_frame = 0; kicks = []; hello = None
        presentation_drops=0
        guard = StreamIdentity(session,engine,self.config["source_commit"],validate)
        try:
            child = OwnedChild(base + args, SDK, env, folder)
            with (folder / "stream.jsonl").open("wb") as retained:
                while peer is None:
                    if self.stop.is_set(): raise RuntimeError("Session cancelled")
                    if child.process.poll() is not None: raise RuntimeError("Native worker exited before connecting; see stderr.log")
                    if time.monotonic()-started > 45: raise TimeoutError("Worker connection deadline")
                    try: peer, _ = listener.accept()
                    except socket.timeout: pass
                peer.settimeout(.1); pending = b""
                def send(packet):
                    with (folder / "commands.jsonl").open("a", encoding="utf-8") as out: out.write(json.dumps(packet)+"\n")
                    peer.sendall((json.dumps(packet)+"\n").encode())
                while completed is None:
                    if self.stop.is_set(): raise RuntimeError("Session cancelled; contained descendants reaped")
                    if time.monotonic()-started > (600 if validate else 3600): raise TimeoutError("Bounded native wall-time deadline")
                    try:
                        block = peer.recv(65536)
                        if not block: raise RuntimeError("Native stream closed without completion")
                    except socket.timeout: block = None
                    if block:
                        retained.write(block); retained.flush(); total += len(block); pending += block
                        if total > 268435456 or len(pending) > 4194304: raise RuntimeError("Native stream exceeded declared byte bound")
                        while b"\n" in pending:
                            line, pending = pending.split(b"\n", 1)
                            message = json.loads(line)
                            guard.accept(message)
                            if message.get("schema_version") != PROTOCOL or message.get("session_id") != session or message.get("engine_id") != engine:
                                raise RuntimeError("Crossed native protocol identity")
                            kind = message.get("message_type")
                            if kind == "hello":
                                if hello is not None or not message.get("native_physics") or message.get("replay") is not False: raise RuntimeError("Invalid native hello")
                                if not validate and message.get("source_commit") != self.config["source_commit"]: raise RuntimeError("Source identity mismatch")
                                hello = message
                                if not validate: self.publish(native_session=session)
                                if "scene" in message: write(self.folder / "scene.json", dict(message["scene"], session_id=session))
                            elif hello is None: raise RuntimeError("Native message before hello")
                            elif kind == "scene": write(self.folder / "scene.json", dict(message["scene"], session_id=session))
                            elif kind == "ready_to_start":
                                if validate: raise RuntimeError("Preflight attempted physical start")
                                send(dict(schema_version=PROTOCOL, message_type="start", session_id=session, command_id="owner_start"))
                            elif kind == "frame":
                                n = message.get("frame_index")
                                if validate or type(n) is not int or n <= last_frame or n > 12000 or message.get("replay") is not False or message.get("native_physics") is not True:
                                    raise RuntimeError("Invalid native frame progression")
                                last_frame = n; self.frame = message
                                kicks.extend(message.get("applied_impulses", []))
                                if not write(self.folder / "frame.json", message,presentation=True): presentation_drops+=1
                            elif kind == "completed": completed = message
                            elif kind == "error": raise RuntimeError(str(message.get("error")))
                            elif kind not in ("started", "command_scheduled"): raise RuntimeError("Unknown worker message")
                    while not self.commands.empty() and not validate:
                        command = self.commands.get_nowait()
                        send(impulse(session, last_frame, command["magnitude"], command["direction"], uuid.uuid4().hex))
                # Completion is terminal. Close the duplex command channel so
                # a worker command-reader cannot keep process shutdown waiting.
                peer.shutdown(socket.SHUT_RDWR)
                if child.process.wait(timeout=20) != 0: raise RuntimeError("Native worker returned nonzero exit status")
            return dict(completed=completed, hello=hello, last_frame=last_frame, applied_impulses=kicks,
                stream_sha256=sha(folder/"stream.jsonl"), elapsed_s=time.monotonic()-started,
                presentation_frames_coalesced_due_to_file_lock=presentation_drops)
        finally:
            if peer: peer.close()
            listener.close()
            if child: child.close()

    def close(self):
        self.stop.set()
        if self.session_thread: self.session_thread.join(timeout=20)
        if self.session_thread and self.session_thread.is_alive(): raise RuntimeError("Native session did not terminate")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--evidence-root", type=Path, help="Create a fresh UUID session below this durable directory")
    parser.add_argument("--leaf", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--headless-ui", action="store_true")
    parser.add_argument("--ui-self-test", action="store_true")
    parser.add_argument("--exercise-engine", choices=ENGINES, help="Run the declared fresh UI/native diagnostic, retain it and exit")
    args = parser.parse_args()
    if args.leaf: return contained_leaf(args.leaf)
    if not args.config or bool(args.output)==bool(args.evidence_root): parser.error("--config and exactly one of --output or --evidence-root are required")
    cfg = json.loads(args.config.read_text(encoding="utf-8-sig"))
    if len(cfg.get("source_commit", "")) != 40 or any(c not in "0123456789abcdef" for c in cfg["source_commit"]): raise ValueError("A full source commit binding is required")
    folder = (args.output if args.output else args.evidence_root/("explorer-"+uuid.uuid4().hex)).resolve()
    folder.mkdir(parents=True, exist_ok=False)
    (folder / "commands").mkdir()
    project = folder / "app"
    (project / "sdk/explorer").mkdir(parents=True)
    (project / "sdk/recovery").mkdir()
    for name in ("showcase.gd", "recovery_evidence.gd"):
        shutil.copy2(SDK/"explorer"/name, project/"sdk/explorer"/name)
    for name in ("r10dh_release_gate_adoption_v2.json", "r10dh_held_out_physical_closure_v2.json"):
        source = SDK/"recovery"/name
        if source.exists(): shutil.copy2(source, project/"sdk/recovery"/name)
    (project / "project.godot").write_text('[application]\nconfig/name="SporeSpore Explorer"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
    write(folder / "config.json", cfg)
    owner = Owner(cfg, folder)
    ui_job = jobs.Job()
    ui = None
    try:
        command = [cfg["godot"], "--path", str(project), "--script", "res://sdk/explorer/showcase.gd"]
        if args.headless_ui: command.insert(1, "--headless")
        command += ["--", "--channel", str(folder)]
        if args.ui_self_test: command += ["--self-test"]
        if args.exercise_engine: command += ["--exercise-engine", args.exercise_engine]
        with (folder/"ui.stdout.log").open("w", encoding="utf-8") as out, (folder/"ui.stderr.log").open("w", encoding="utf-8") as err:
            ui = subprocess.Popen(command, cwd=project, stdout=out, stderr=err)
            ui_job.add(ui)
            print(json.dumps(dict(viewer_pid=ui.pid, folder=str(folder))), flush=True)
            ui_started = time.monotonic()
            while ui.poll() is None:
                if args.ui_self_test and time.monotonic()-ui_started > 45:
                    raise TimeoutError("UI self-test deadline")
                for path in sorted((folder/"commands").glob("*.json")):
                    try:
                        value = json.loads(path.read_text(encoding="utf-8"))
                        path.rename(path.with_suffix(".consumed"))
                        owner.command(value)
                    except Exception as exc: owner.publish(event=str(exc))
                time.sleep(.05)
            return ui.returncode
    finally:
        owner.close()
        ui_job.close()
        if ui: ui.wait(timeout=10)


if __name__ == "__main__":
    raise SystemExit(main())
