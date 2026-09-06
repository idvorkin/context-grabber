/**
 * The call log as a private gist — created, described, and deleted, with
 * no React and no network in it beyond a `fetch` handed in (#92 gist path).
 *
 * One gist per upload, never a rolling one: a stable URL would be a
 * permanently live copy of Igor's calls. Each gist opens with a note asking
 * the reader to delete it when processed, and the app keeps the ids so it
 * can delete what it made.
 *
 * Spec: docs/superpowers/specs/2026-09-05-diagnostics-gist-upload-design.md
 */

export const GISTS_URL = "https://api.github.com/gists";

/** How many of the app's gists may exist at once; the oldest beyond this go on the next upload. */
export const KEEP_UPLOADS = 10;

export type Upload = { id: string; url: string; at: string };

/**
 * A call whose log says something went wrong: the audio healed itself, a
 * problem reached the screen, or it ended badly. The trigger is what the
 * log says, so anything it learns to say is covered.
 */
const TROUBLE = [
  /→ re-arming/i,
  /→ resetting audio/i,
  /→ redialing/i,
  /→ reopening playback/i,
  /mic stalled/i,
  /output clock (stalled|has not started|still not running)/i,
  /mic_ack missed/i,
  /delivering zeros/i,
  /still delivering zeros/i,
  /not reaching Larry/i,
  /not arriving/i,
  /not playing/i,
  /stopped delivering/i,
  /ended BADLY/i,
  /recorder (ERROR|start FAILED)/i,
  /FAILED/,
  /giving up/i,
];

export function callHadTrouble(lines: readonly string[]): boolean {
  return lines.some((l) => TROUBLE.some((re) => re.test(l)));
}

export type GistBody = {
  description: string;
  public: false;
  files: Record<string, { content: string }>;
};

/** The note at the top of every upload — for whoever reads it, human or Larry. */
export function readerNote(): string {
  return [
    "This is Igor's phone's call log, uploaded by Context Grabber. It contains call",
    "transcripts and device details. DELETE THIS GIST ONCE YOU HAVE PROCESSED IT —",
    "`gh gist delete <this gist's id>`. It is one of several; the app can also delete",
    "everything it uploaded from Settings → Diagnostics uploads.",
  ].join("\n");
}

export function renderDiagnosticsGist(input: {
  at: Date;
  why: string;
  /** The header lines Copy diagnostics puts first (build, state, route…), already rendered with the log. */
  text: string;
}): GistBody {
  const when = input.at.toISOString().replace("T", " ").slice(0, 16);
  return {
    description: `Context Grabber call diagnostics · ${when} UTC · ${input.why}`,
    public: false,
    files: {
      "call-log.txt": { content: `${readerNote()}\n\nupload reason: ${input.why}\n${input.text}\n` },
    },
  };
}

type FetchLike = (
  url: string,
  init: { method: string; headers: Record<string, string>; body?: string },
) => Promise<{ status: number; json(): Promise<unknown>; text(): Promise<string> }>;

function headers(token: string): Record<string, string> {
  return {
    Authorization: `Bearer ${token}`,
    Accept: "application/vnd.github+json",
    "Content-Type": "application/json",
    "X-GitHub-Api-Version": "2022-11-28",
  };
}

/** GitHub's answer, or the reason it was not one. Never carries the token. */
export function parseGistResponse(status: number, body: unknown): { ok: true; id: string; url: string } | { ok: false; error: string } {
  const b = body && typeof body === "object" ? (body as Record<string, unknown>) : null;
  if (status === 201 || status === 200) {
    const id = typeof b?.id === "string" ? b.id : "";
    const url = typeof b?.html_url === "string" ? b.html_url : "";
    if (id && url) return { ok: true, id, url };
    return { ok: false, error: `GitHub answered ${status} without a gist id` };
  }
  const message = typeof b?.message === "string" ? b.message : "";
  return { ok: false, error: `GitHub said ${status}${message ? `: ${message}` : ""}` };
}

export async function uploadGist(token: string, body: GistBody, fetchFn: FetchLike = fetch): Promise<Upload> {
  let res: { status: number; json(): Promise<unknown> };
  try {
    res = await fetchFn(GISTS_URL, { method: "POST", headers: headers(token), body: JSON.stringify(body) });
  } catch (e) {
    throw new Error(`upload failed: ${e instanceof Error ? e.message : String(e)}`);
  }
  let json: unknown = null;
  try {
    json = await res.json();
  } catch {
    // no body — the status says enough
  }
  const parsed = parseGistResponse(res.status, json);
  if (!parsed.ok) throw new Error(parsed.error);
  return { id: parsed.id, url: parsed.url, at: new Date().toISOString() };
}

/** True when deleted now; false when it was already gone (404) — the intended outcome. Throws on anything else. */
export async function deleteGist(token: string, id: string, fetchFn: FetchLike = fetch): Promise<boolean> {
  let res: { status: number; text(): Promise<string> };
  try {
    res = await fetchFn(`${GISTS_URL}/${encodeURIComponent(id)}`, { method: "DELETE", headers: headers(token) });
  } catch (e) {
    throw new Error(`delete failed: ${e instanceof Error ? e.message : String(e)}`);
  }
  if (res.status === 204) return true;
  if (res.status === 404) return false;
  throw new Error(`GitHub said ${res.status}`);
}

/** Newest first; what to keep and what to delete, once a new upload is added. */
export function pruneUploads(uploads: readonly Upload[], keep = KEEP_UPLOADS): { keep: Upload[]; drop: Upload[] } {
  const sorted = [...uploads].sort((a, b) => (a.at < b.at ? 1 : a.at > b.at ? -1 : 0));
  return { keep: sorted.slice(0, keep), drop: sorted.slice(keep) };
}

/**
 * After an upload: the newest KEEP_UPLOADS stay, the rest are deleted from GitHub. A delete that fails
 * (offline, GitHub down) keeps its gist on the list — *Delete uploaded diagnostics* still counts it and
 * the next upload tries again. One already gone (404) is dropped: that is the intended outcome.
 */
export async function retireOldUploads(
  token: string,
  uploads: readonly Upload[],
  deleteFn: (token: string, id: string) => Promise<boolean> = deleteGist,
): Promise<Upload[]> {
  const { keep, drop } = pruneUploads(uploads);
  const stuck = await Promise.all(
    drop.map(async (u) => {
      try {
        await deleteFn(token, u.id);
        return null;
      } catch {
        return u;
      }
    }),
  );
  return [...keep, ...stuck.filter((u): u is Upload => u !== null)];
}

export function parseUploads(raw: string | null | undefined): Upload[] {
  if (!raw) return [];
  try {
    const v = JSON.parse(raw);
    if (!Array.isArray(v)) return [];
    return v.filter(
      (u): u is Upload =>
        !!u && typeof u === "object" && typeof u.id === "string" && typeof u.url === "string" && typeof u.at === "string",
    );
  } catch {
    return [];
  }
}
