#!/usr/bin/env node
const { execSync } = require("child_process");
const { writeFileSync } = require("fs");

const sha = execSync("git rev-parse HEAD").toString().trim();
const branch = execSync("git rev-parse --abbrev-ref HEAD").toString().trim();
const repoUrl = execSync("git remote get-url origin")
	.toString()
	.trim()
	.replace(/\.git$/, "")
	.replace(/git@github\.com:/, "https://github.com/");
const buildTime = new Date().toISOString();

const content = `// Auto-generated at build time - DO NOT EDIT
export const GIT_SHA = "${sha}";
export const GIT_COMMIT_URL = "${repoUrl}/commit/${sha}";
export const GIT_CURRENT_URL = "${repoUrl}/tree/${branch}";
export const GIT_BRANCH = "${branch}";
export const BUILD_TIMESTAMP = "${buildTime}";
`;

writeFileSync("lib/generated_version.ts", content);
console.log("Generated lib/generated_version.ts");
