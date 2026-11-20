#!/usr/bin/env python3
"""Riftguard asset QA with EL4CTEO/blender-skills (MIT), run headless on COPIES of delivered GLBs.

  python tools/qa/run_qa.py asset  --glb path.glb --pose idle --parts Warden WeaponMesh [--fps 30]
  python tools/qa/run_qa.py loops  --glb path.glb --object Armature --clips walk,idle [--fps 30]
  python tools/qa/run_qa.py contact --glb path.glb --clip walk --speed 0.04674 --bones Toe.L,Toe.R

env/flags: --blender (Blender 5.2+, default $BLENDER or "blender"), --skills (blender-skills clone, default $BLENDER_SKILLS
or ../blender-skills), --blender42 (only for contact: the Blender our contact_check.py was written for; 5.x also works).
Never edits the GLB: it is copied to a temp folder first. Never passes --fix / --save to the skill scripts.
Prints a short summary; full JSON goes to --out (default qa_out/).
"""
import argparse, json, os, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))


def blender(exe, args):
    p = subprocess.run([exe, "-b", *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    return p.stdout + p.stderr


def marked(out, mark="@@JSON@@"):
    for line in out.splitlines():
        if line.startswith(mark):
            return json.loads(line[len(mark):])
    return {"ok": False, "error": "no result line", "tail": out[-1500:]}


def prep(a, tmp, fps):
    glb = os.path.join(tmp, os.path.basename(a.glb))
    shutil.copy2(a.glb, glb)                      # work on a copy, always
    bl = os.path.join(tmp, "prepped.blend")
    out = blender(a.blender, ["--factory-startup", "--python", os.path.join(HERE, "prep_glb.py"), "--", glb, str(fps), bl])
    if not os.path.exists(bl):
        sys.exit("prep failed:\n" + out[-2000:])
    return bl


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["asset", "loops", "contact"])
    ap.add_argument("--glb", required=True)
    ap.add_argument("--fps", type=int, default=30, help="the clip's native rate (enemies/heroes 30, merge towers 60)")
    ap.add_argument("--pose", default="idle", help="asset: action to pose every object with (frame 0) before QA")
    ap.add_argument("--parts", nargs="*", help="asset: mesh objects of THIS asset (skip importer helpers like Icosphere)")
    ap.add_argument("--profile", default="game")
    ap.add_argument("--object", default="Armature")
    ap.add_argument("--clips", default="")
    ap.add_argument("--clip"); ap.add_argument("--speed", type=float); ap.add_argument("--bones")
    ap.add_argument("--blender", default=os.environ.get("BLENDER", "blender"))
    ap.add_argument("--blender42", default=os.environ.get("BLENDER42", ""))
    ap.add_argument("--skills", default=os.environ.get("BLENDER_SKILLS", os.path.join(HERE, "..", "..", "..", "blender-skills")))
    ap.add_argument("--out", default="qa_out")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    tag = os.path.splitext(os.path.basename(a.glb))[0]
    S = os.path.abspath(a.skills)
    with tempfile.TemporaryDirectory() as tmp:
        if a.mode == "contact":
            glb = os.path.join(tmp, os.path.basename(a.glb)); shutil.copy2(a.glb, glb)
            js = os.path.join(tmp, "c.json")
            out = blender(a.blender42 or a.blender, ["--factory-startup", "--python", os.path.join(HERE, "contact_check.py"), "--",
                                                     glb, a.clip, str(a.speed), a.bones, js])
            line = next((l for l in out.splitlines() if l.startswith("SUMMARY")), out[-1500:])
            print(line)
            if os.path.exists(js):
                shutil.copy2(js, os.path.join(a.out, f"{tag}_contact_{a.clip}.json"))
            return
        bl = prep(a, tmp, a.fps)
        if a.mode == "asset":
            posed = os.path.join(tmp, "posed.blend")
            blender(a.blender, [bl, "--python", os.path.join(HERE, "pose_blend.py"), "--", a.pose, "0", posed])
            q = os.path.join(S, "skills", "blender-asset-qa", "scripts", "qa_check.py")
            args = [posed if os.path.exists(posed) else bl, "--python", q, "--", "--profile", a.profile]
            if a.parts:
                args += ["--objects", *a.parts]
            r = marked(blender(a.blender, args))
            json.dump(r, open(os.path.join(a.out, f"{tag}_asset.json"), "w"), indent=1)
            if "errors" not in r:
                print("QA did not run:", r); return
            print(f"{tag}: pass={r['pass']} ground_z={r['ground_z']} floating={len(r['floating'])}")
            for e in r["errors"]: print("  E", e)
            for w in r["warnings"]: print("  W", w)
        else:
            L = os.path.join(S, "skills", "blender-animation", "scripts", "loop_check.py")
            res = []
            for c in [c for c in a.clips.split(",") if c]:
                r = marked(blender(a.blender, [bl, "--python", L, "--", "--object", a.object, "--action", c]))
                res.append(r)
                if "error" in r:
                    print(c, "ERROR", r["error"]); continue
                print(f"{c}: frames {r['frames']} loops={r['loops']} pops={[(p['bone'], p['rot_deg'], p['loc_m']) for p in r['pops'][:4]]} "
                      f"hitches={[(h['bone'], h['kind']) for h in r['hitches'][:5]]}")
            out = blender(a.blender, [bl, "--python", os.path.join(HERE, "seam_vs_interior.py"), "--", a.object, a.clips])
            seam = marked(out, "@@SEAM@@")
            for c, d in seam.items() if isinstance(seam, dict) and "error" not in seam else []:
                print(f"  {c}: bones whose seam kink is >1.5x anything mid-cycle (worth a look): {d['bones_where_seam_is_the_max'] or 'none'}")
            json.dump({"loop_check": res, "seam_vs_interior": seam}, open(os.path.join(a.out, f"{tag}_loops.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
