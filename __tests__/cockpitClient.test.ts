import { clientTaggedUrl } from "../lib/cockpitClient";

describe("clientTaggedUrl (#78)", () => {
  it("adds the client and the build to a bare URL", () => {
    expect(clientTaggedUrl("https://c-5004.squeaker-teeth.ts.net", "abc1234")).toBe(
      "https://c-5004.squeaker-teeth.ts.net?client=context-grabber&v=abc1234",
    );
  });

  it("joins an existing query with &, and keeps the #route after the query", () => {
    expect(clientTaggedUrl("https://h/?x=1#call/abc", "s")).toBe("https://h/?x=1&client=context-grabber&v=s#call/abc");
    expect(clientTaggedUrl("https://h/#calls", "s")).toBe("https://h/?client=context-grabber&v=s#calls");
  });

  it("names the client even with no build, and escapes the build", () => {
    expect(clientTaggedUrl("https://h", "")).toBe("https://h?client=context-grabber");
    expect(clientTaggedUrl("https://h", "a b")).toBe("https://h?client=context-grabber&v=a%20b");
  });
});
