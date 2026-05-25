from pathlib import Path
import json

src = Path(__file__).with_name("Cleaning.ipynb")
dst = Path(__file__).with_name("Cleaning_fixed.ipynb")

lines = src.read_text(encoding="utf-8", errors="replace").splitlines(True)

out = []
mode = "normal"   # normal | skip_head | take_theirs
for line in lines:
    if line.startswith("<<<<<<<"):
        mode = "skip_head"          # skip HEAD part
        continue
    if mode == "skip_head" and line.startswith("======="):
        mode = "take_theirs"        # now take theirs
        continue
    if mode == "take_theirs" and line.startswith(">>>>>>>"):
        mode = "normal"
        continue

    if mode == "normal" or mode == "take_theirs":
        out.append(line)
    # if mode == skip_head: drop lines

dst.write_text("".join(out), encoding="utf-8")

# validate JSON
json.loads(dst.read_text(encoding="utf-8"))
print("Wrote valid notebook:", dst)
