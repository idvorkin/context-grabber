import {
  KEEP_UPLOADS,
  callHadTrouble,
  deleteGist,
  parseGistResponse,
  parseUploads,
  pruneUploads,
  retireOldUploads,
  readerNote,
  renderDiagnosticsGist,
  uploadGist,
} from "../lib/gistUpload";

describe("callHadTrouble", () => {
  it("a clean call is not trouble", () => {
    expect(
      callHadTrouble(["+0.0s start backend=eleven", "+1.2s ready", "+1.5s first mic frame", "+30.0s hang up", "+30.1s ended: stopped (…)"]),
    ).toBe(false);
  });

  it("a self-heal, a banner, or a bad ending is", () => {
    expect(callHadTrouble(["+2.0s mic stalled: no buffer for 1600 ms → re-arming (1/3)"])).toBe(true);
    expect(callHadTrouble(["+3.0s no mic buffer within 1.5s of recorder start (0 frames sent) → resetting audio"])).toBe(true);
    expect(callHadTrouble(["+9.0s output clock stalled at 3.10s with 1.2s due → reopening playback"])).toBe(true);
    expect(callHadTrouble(["+8.0s Tony is talking (text) but no audio has arrived for 5 s"])).toBe(false);
    expect(callHadTrouble(["+8.0s audio: Tony's audio is not arriving from the bridge"])).toBe(true);
    expect(callHadTrouble(["+40s ended BADLY: connection lost (…)"])).toBe(true);
    expect(callHadTrouble(["+6s mic_ack missed (0 frames sent, 12 buffers) → re-arming the mic once"])).toBe(true);
  });
});

describe("renderDiagnosticsGist", () => {
  it("is one secret file that opens with the delete-me note, then the reason, then the text", () => {
    const g = renderDiagnosticsGist({ at: new Date("2026-09-05T15:12:00Z"), why: "troubled call", text: "build: abc\n---\n+0.0s start" });
    expect(g.public).toBe(false);
    expect(g.description).toBe("Context Grabber call diagnostics · 2026-09-05 15:12 UTC · troubled call");
    expect(Object.keys(g.files)).toEqual(["call-log.txt"]);
    const content = g.files["call-log.txt"].content;
    expect(content.startsWith(readerNote())).toBe(true);
    expect(readerNote()).toMatch(/DELETE THIS GIST ONCE YOU HAVE PROCESSED IT/);
    expect(content).toContain("\nupload reason: troubled call\nbuild: abc\n---\n+0.0s start\n");
  });
});

describe("GitHub's answers", () => {
  it("201 with an id and html_url is an upload; anything else is the reason", () => {
    expect(parseGistResponse(201, { id: "abc123", html_url: "https://gist.github.com/idvorkin/abc123" })).toEqual({
      ok: true,
      id: "abc123",
      url: "https://gist.github.com/idvorkin/abc123",
    });
    expect(parseGistResponse(401, { message: "Bad credentials" })).toEqual({ ok: false, error: "GitHub said 401: Bad credentials" });
    expect(parseGistResponse(201, {})).toEqual({ ok: false, error: "GitHub answered 201 without a gist id" });
    expect(parseGistResponse(502, "html")).toEqual({ ok: false, error: "GitHub said 502" });
  });

  it("uploadGist posts the body with the token in the header and never in the error", async () => {
    const calls: { url: string; init: { method: string; headers: Record<string, string>; body?: string } }[] = [];
    const fetchFn = async (url: string, init: { method: string; headers: Record<string, string>; body?: string }) => {
      calls.push({ url, init });
      return { status: 201, json: async () => ({ id: "g1", html_url: "https://gist.github.com/x/g1" }), text: async () => "" };
    };
    const up = await uploadGist("ghp_secret", renderDiagnosticsGist({ at: new Date(0), why: "upload requested", text: "t" }), fetchFn);
    expect(up).toMatchObject({ id: "g1", url: "https://gist.github.com/x/g1" });
    expect(calls[0].url).toBe("https://api.github.com/gists");
    expect(calls[0].init.method).toBe("POST");
    expect(calls[0].init.headers.Authorization).toBe("Bearer ghp_secret");
    expect(JSON.parse(calls[0].init.body!).public).toBe(false);

    const failing = async () => ({ status: 401, json: async () => ({ message: "Bad credentials" }), text: async () => "" });
    await expect(uploadGist("ghp_secret", renderDiagnosticsGist({ at: new Date(0), why: "x", text: "t" }), failing)).rejects.toThrow(
      "GitHub said 401: Bad credentials",
    );
    const offline = async () => {
      throw new Error("Network request failed");
    };
    await expect(uploadGist("ghp_secret", renderDiagnosticsGist({ at: new Date(0), why: "x", text: "t" }), offline)).rejects.toThrow(
      /^upload failed: Network request failed$/,
    );
  });

  it("deleteGist: 204 deleted, 404 already gone, anything else throws", async () => {
    const mk = (status: number) => async () => ({ status, json: async () => null, text: async () => "" });
    expect(await deleteGist("t", "g1", mk(204))).toBe(true);
    expect(await deleteGist("t", "g1", mk(404))).toBe(false);
    await expect(deleteGist("t", "g1", mk(403))).rejects.toThrow("GitHub said 403");
  });
});

describe("the app's own list", () => {
  const u = (id: string, at: string) => ({ id, url: `https://gist.github.com/x/${id}`, at });

  it("keeps the newest KEEP_UPLOADS and names the rest for deletion", () => {
    const list = Array.from({ length: KEEP_UPLOADS + 3 }, (_, i) => u(`g${i}`, `2026-09-0${1 + (i % 9)}T00:00:${String(i).padStart(2, "0")}Z`));
    const { keep, drop } = pruneUploads(list);
    expect(keep).toHaveLength(KEEP_UPLOADS);
    expect(drop).toHaveLength(3);
    expect(keep[0].at >= keep[keep.length - 1].at).toBe(true);
    expect(drop.every((d) => d.at <= keep[keep.length - 1].at)).toBe(true);
  });

  it("retireOldUploads: the newest stay, the rest go; a failed delete keeps its gist on the list, a 404 does not", async () => {
    const list = Array.from({ length: KEEP_UPLOADS + 3 }, (_, i) => u(`g${i}`, `2026-09-01T00:00:${String(i).padStart(2, "0")}Z`));
    const tried: string[] = [];
    const del = jest.fn(async (_t: string, id: string) => {
      tried.push(id);
      if (id === "g1") throw new Error("delete failed: offline");
      return id !== "g0"; // g0: already gone (404)
    });
    const kept = await retireOldUploads("t", list, del);
    expect(tried.sort()).toEqual(["g0", "g1", "g2"]);
    expect(kept).toHaveLength(KEEP_UPLOADS + 1);
    expect(kept.map((k) => k.id)).toContain("g1");
    expect(kept.map((k) => k.id)).not.toContain("g0");
    expect(kept.map((k) => k.id)).not.toContain("g2");
    expect(kept[0].id).toBe(`g${KEEP_UPLOADS + 2}`); // newest first
  });

  it("parseUploads tolerates junk", () => {
    expect(parseUploads(null)).toEqual([]);
    expect(parseUploads("nope")).toEqual([]);
    expect(parseUploads(JSON.stringify([u("a", "2026-09-05T00:00:00Z"), { id: 1 }, null]))).toEqual([u("a", "2026-09-05T00:00:00Z")]);
  });
});
