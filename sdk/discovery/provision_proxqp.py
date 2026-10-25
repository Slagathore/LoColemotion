"""Add pinned CPU QP wheels without replacing the scientific runtime."""
import ctypes as C,importlib.metadata as md,json,platform,shutil,subprocess,sys,urllib.request,uuid,zipfile
from ctypes import wintypes as W
from pathlib import Path
from contact_force_observer_task import ROOT,HERE,read,sha,require
from audit_contact_force_observer_closure import validate_bindings
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity,jobs

MANIFEST=HERE/"proxqp_dependencies_v1.json"


def installed():
    return {d.metadata["Name"].lower().replace("_","-"):d.version for d in md.distributions()}


def main():
    source=source_identity(False);c=read(MANIFEST)
    require(Path(sys.executable).resolve()==(ROOT/"sdk/adapters/mujoco/.venv/Scripts/python.exe").resolve()
        and sys.version_info[:2]==(3,11) and platform.machine()=="AMD64","QP exact local interpreter")
    before=installed()
    require(all(md.version(n)==v for n,v in c["existing_versions"].items()),"QP unchanged base package versions")
    for p in c["packages"]:
        require(p["name"] not in before or before[p["name"]]==p["version"],"QP refuses replacing existing package")
    evidence=ROOT.parent/"SporeSpore_Evidence";folder=evidence/("sdk2-proxqp-runtime-"+uuid.uuid4().hex)
    folder.mkdir();print(str(folder),flush=True)
    old=read(evidence/"sdk2-conditioned-contact-refusal-de48e37ef3ce4a94909d92a57962e4db/declaration.json")["binding"]
    receipt=dict(schema_version="locolemotion_proxqp_provision_receipt_v1",ok=False,ledger_scope=c["ledger_scope"],
        source_commit=source,manifest_sha256=sha(MANIFEST),script_sha256=sha(Path(__file__)),world_build_count=0,solver_steps=0)
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"));owned=False
    try:
        require(jobs.wait(handle,0) in (0,128),"QP provisioning operation mutex");owned=True
        validate_bindings(old);write_new(folder/"before-packages.json",before)
        for path in (MANIFEST,Path(__file__)):
            with (folder/path.name).open("xb") as out:out.write(path.read_bytes())
        wheels=[]
        for p in c["packages"]:
            target=folder/p["filename"]
            require(Path(p["filename"]).name==p["filename"] and p["url"].startswith("https://files.pythonhosted.org/"),
                "QP wheel provenance/path")
            with urllib.request.urlopen(p["url"],timeout=60) as response,target.open("xb") as out:shutil.copyfileobj(response,out)
            require(sha(target)==p["sha256"],"QP wheel digest")
            with zipfile.ZipFile(target) as archive:require(archive.testzip() is None,"QP wheel CRC")
            if p["name"] not in before:wheels.append(str(target))
        commands=[]
        if wheels:commands.append(("install",[sys.executable,"-B","-m","pip","--disable-pip-version-check",
            "install","--no-index","--no-deps","--no-cache-dir","--no-compile",*wheels]))
        commands.append(("dependency-check",[sys.executable,"-B","-m","pip","--disable-pip-version-check","check"]))
        for name,command in commands:
            with (folder/(name+".stdout.log")).open("xb") as out,(folder/(name+".stderr.log")).open("xb") as err:
                code=subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,check=False).returncode
            require(code==0,"QP "+name+" failed")
        after=installed();write_new(folder/"after-packages.json",after)
        require(all(after.get(n)==v for n,v in before.items()),"QP existing package versions changed")
        require(all(md.version(p["name"])==p["version"] for p in c["packages"]),"QP pinned packages")
        validate_bindings(old)
        receipt.update(ok=True,old_source_bindings_unchanged=len(old["source"]),old_runtime_bindings_unchanged=len(old["runtime"]),
            added_packages={n:v for n,v in after.items() if n not in before},pip_check_passed=True)
    except BaseException as exc:receipt["error"]=f"{type(exc).__name__}: {exc}"
    finally:
        receipt["artifacts"]={p.name:sha(p) for p in folder.iterdir() if p.is_file()}
        write_new(folder/"receipt.json",receipt)
        if owned:release(handle)
        jobs.close(handle)
    print(json.dumps(dict(ok=receipt["ok"],output=str(folder),error=receipt.get("error"))))
    return 0 if receipt["ok"] else 1
if __name__=="__main__":raise SystemExit(main())
