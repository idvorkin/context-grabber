import {
  GIT_SHA,
  GIT_COMMIT_URL,
  GIT_CURRENT_URL,
  GIT_BRANCH,
  BUILD_TIMESTAMP,
} from "./generated_version";

export type BuildInfo = {
  sha: string;
  shortSha: string;
  branch: string;
  timestamp: string;
  commitUrl: string;
  repoUrl: string;
};

export function getBuildInfo(): BuildInfo {
  return {
    sha: GIT_SHA,
    shortSha: GIT_SHA.slice(0, 7),
    branch: GIT_BRANCH,
    timestamp: BUILD_TIMESTAMP,
    commitUrl: GIT_COMMIT_URL,
    repoUrl: GIT_CURRENT_URL,
  };
}

export function formatBuildTimestamp(timestamp: string): string {
  if (!timestamp) return "";
  const date = new Date(timestamp);
  if (isNaN(date.getTime())) return timestamp;
  return date.toLocaleString();
}
