import { getBuildInfo, formatBuildTimestamp } from "../lib/version";

jest.mock("../lib/generated_version", () => ({
  GIT_SHA: "abc1234def5678901234567890abcdef12345678",
  GIT_COMMIT_URL: "https://github.com/test/repo/commit/abc1234",
  GIT_CURRENT_URL: "https://github.com/test/repo/tree/main",
  GIT_BRANCH: "main",
  BUILD_TIMESTAMP: "2025-01-15T10:30:00Z",
}));

describe("getBuildInfo", () => {
  it("returns full build info", () => {
    const info = getBuildInfo();
    expect(info.sha).toBe("abc1234def5678901234567890abcdef12345678");
    expect(info.shortSha).toBe("abc1234");
    expect(info.branch).toBe("main");
    expect(info.timestamp).toBe("2025-01-15T10:30:00Z");
    expect(info.commitUrl).toBe(
      "https://github.com/test/repo/commit/abc1234"
    );
    expect(info.repoUrl).toBe("https://github.com/test/repo/tree/main");
  });
});

describe("formatBuildTimestamp", () => {
  it("formats valid ISO timestamp", () => {
    const result = formatBuildTimestamp("2025-01-15T10:30:00Z");
    expect(result).toBeTruthy();
    expect(result).not.toBe("");
  });

  it("returns empty string for empty input", () => {
    expect(formatBuildTimestamp("")).toBe("");
  });

  it("returns original string for invalid date", () => {
    expect(formatBuildTimestamp("not-a-date")).toBe("not-a-date");
  });
});
