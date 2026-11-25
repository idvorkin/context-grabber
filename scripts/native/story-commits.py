#!/usr/bin/env python3
"""Check story commit links against the commits reachable from HEAD.

A rebase can leave the old commit object in Git even though it is no longer in
the branch's history. The host check is documented in docs/TESTING.md.

A link to a commit a rebase replaced (story 1638, bead context-grabber-zisx) is
matched by patch-id to the one commit on the branch that carries the same
change. The check passes it with a note, and --fix rewrites the link to that
commit, which `just pre-merge` does on the branch before it merges, so a
pipeline rebase no longer costs a review round. A link with no such commit, or
more than one, still fails.

Usage: story-commits.py [--rev REV] [--base REF] [--repo DIR] [--fix] [stories-dir]
  --rev REV  judge against REV's history (default HEAD)
  --base REF the branch's base, whose commits are never a replacement (default origin/main); when it
             doesn't resolve, no link is matched as replaced
  --repo DIR the repository to read history from (default: the one holding stories-dir)
  --fix      rewrite each replaced commit's links in place, printing each rewrite
  stories-dir defaults to docs/stories
"""

import argparse
import os
import re
import subprocess
import sys

LINK = re.compile(r"(github\.com/idvorkin/context-grabber/commit/)([0-9a-fA-F]{7,40})\b")


def git(*args, cwd, stdin=None, check=True):
    return subprocess.run(
        ["git", *args], cwd=cwd, input=stdin, capture_output=True, text=True, check=check
    ).stdout


def commit(ref, repo):
    out = subprocess.run(
        ["git", "rev-parse", "-q", "--verify", ref + "^{commit}"],
        cwd=repo, capture_output=True, text=True,
    )
    return out.stdout.strip() if out.returncode == 0 else None


def patch_id(sha, repo):
    """The stable patch-id of one commit's change, or None (an empty commit, a merge, an unknown object)."""
    show = subprocess.run(
        ["git", "show", "--no-color", "--pretty=format:", "--no-ext-diff", sha],
        cwd=repo, capture_output=True, text=True,
    )
    if show.returncode != 0 or not show.stdout.strip():
        return None
    out = git("patch-id", "--stable", cwd=repo, stdin=show.stdout, check=False).split()
    return out[0] if out else None


class Replacements:
    """Finds, for a sha not in the history, the one branch commit with the same patch-id."""

    def __init__(self, repo, rev, base):
        self.repo, self.rev, self.base, self.ids = repo, rev, commit(base, repo), None

    def _branch_ids(self):
        if self.ids is None:
            self.ids = {}
            if self.base is None:
                return self.ids
            for sha in git("rev-list", "--no-merges", self.rev, "--not", self.base, cwd=self.repo).split():
                pid = patch_id(sha, self.repo)
                if pid:
                    self.ids.setdefault(pid, []).append(sha)
        return self.ids

    def find(self, sha):
        full = commit(sha, self.repo)
        pid = patch_id(full, self.repo) if full else None
        matches = self._branch_ids().get(pid, []) if pid else []
        return matches[0] if len(matches) == 1 else None


def main(argv):
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument("--rev", default="HEAD")
    p.add_argument("--fix", action="store_true")
    p.add_argument("--repo")
    p.add_argument("--base", default="origin/main")
    p.add_argument("root", nargs="?", default="docs/stories")
    a = p.parse_args(argv)
    root = a.root
    repo = a.repo or git("rev-parse", "--show-toplevel", cwd=root).strip()
    shallow = git("rev-parse", "--is-shallow-repository", cwd=repo).strip() == "true"
    missing = (
        "which is not in this checkout's available history"
        if shallow
        else "which is not in this branch's history (a sha from before a rebase? name the commit as it is on the branch)"
    )
    by_prefix = {}
    for sha in git("rev-list", a.rev, cwd=repo).split():
        by_prefix.setdefault(sha[:7], []).append(sha)
    repl = Replacements(repo, a.rev, a.base)
    problems, notes = [], []
    links = 0
    for name in sorted(os.listdir(root)):
        if not name.endswith(".md"):
            continue
        path = os.path.join(root, name)
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
        changed = False
        for n, line in enumerate(lines, 1):
            for prefix, linked_sha in LINK.findall(line):
                links += 1
                sha = linked_sha.lower()
                if any(h.startswith(sha) for h in by_prefix.get(sha[:7], ())):
                    continue
                new = repl.find(sha)
                if new is None:
                    problems.append(f"FAIL {name}:{n}: links commit {linked_sha}, {missing}")
                    continue
                short = new[: len(linked_sha)]
                notes.append(f"{name}:{n}: {linked_sha} was rebased to {short}")
                if a.fix:
                    line = line.replace(prefix + linked_sha, prefix + short)
                    line = line.replace(f"[{linked_sha}]", f"[{short}]")
                    lines[n - 1] = line
                    changed = True
        if changed:
            with open(path, "w", encoding="utf-8") as f:
                f.writelines(lines)
    for problem in problems:
        print(problem)
    for note in notes:
        print(("fixed " if a.fix else "note ") + note)
    if problems:
        if shallow:
            print(
                "story-commits: this clone is shallow. Fetch the full history (git fetch --unshallow) and rerun."
            )
        return 1
    tail = ""
    if notes and not a.fix:
        tail = f"; {len(notes)} name a commit a rebase replaced (just pre-merge renames them, or story-commits.py --fix)"
    print(f"story-commits: {links} commit links, every one in this branch's history{tail}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
