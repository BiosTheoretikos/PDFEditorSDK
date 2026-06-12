# AGENTS.md

## Project Overview



## Current Architecture



## Coding Guidelines

- Prefer SwiftUI and PDFKit patterns already used in the project. But if currently used patterns do not match best practices, ask for guidance.
- Keep platform differences behind the existing platform aliases or narrow `#if os(iOS)` / `#elseif os(macOS)` blocks. Try to maximize use of cross-platform code and minimize use of `#if` blocks.
- Use Swift Observation (`@Observable`, `@Environment`) rather than introducing Combine for new state flow.
- Keep PDFKit object mutation coordinated through `PDFAnnotatorDocument.withPDFDocument` unless there is a clear reason to work directly with an already-owned PDFKit instance.
- Avoid force unwraps. Prefer `guard`, optional binding, and clear thrown errors.
- Keep changes tightly scoped to the requested behavior. Do not perform broad refactors unless they are necessary for the task.
- By default, prefer 4-space indentation and the existing file organization. But if a .editorconfig file is present, respect any settings in that file.

## Validation

- Prefer Xcode MCP tools when working from Xcode.
- Use `XcodeRefreshCodeIssuesInFile` for quick diagnostics after editing Swift files.
- Use `BuildProject` before finishing meaningful implementation changes.
- Use `RunAllTests` or focused `RunSomeTests` when behavior, document persistence, selection synchronization, or annotation handling changes.
- Unit tests use the Swift `Testing` framework in `PDFAnnotator/PDFAnnotatorTests/PDFAnnotatorTests.swift`.
- UI tests use XCTest/XCUIAutomation in `PDFAnnotator/PDFAnnotatorUITests/`.

## Workflow

- Do not alter any sections of this `AGENTS.md` file (except for the [Project Overview](#project-overview) and [Current Architecture](#current-architecture) sections) unless explicitly requested to do so. However, if any paragraph (or bracketed section) begins with "AGENT:" the remainder of the paragraph or bracketed section will contain instructions regarding what the content of that paragraph or bracketed section should be. Replace the paragraph or bracketed section according to the instructions, which you can do without asking for permission.
- When Apple APIs, SwiftUI behavior, PDFKit behavior, or newly introduced Apple frameworks are uncertain, use the local Apple documentation search tool before assuming API details.
- Include a detailed and commit message with each commit.
- Do not sign commits; non-interactive authorization for signed commits is not available.
- Before committing, review `git status` and ensure the commit includes only the intended files for that phase.
- Before committing, rewiew the [Project Overview](#project-overview) and [Current Architecture](#current-architecture) sections of this `AGENTS.md` file to ensure it reflects the current state of the project including any changes. If necessary, update those two sections to ensure that they reflect the current state of the project. The purpose of these two sections is to provide future agents with any context necessary to begin working intelligently on the project without having to review the entire project from scratch.
- For significant or structural changes, try to break the process into discrete steps, committing after each step, if there is a meaningful way of doing so that will aid understandability or make it easier to identify the source of any bugs introduced. But if changes to one part of the code require changes to other parts of the code in order to make the code correct, keep all such changes together in the same commit.
- When the current branch is the `master` branch, always use the following procedure: Before making any changes, create a new branch to make the changes in. Choose a succinct name for the branch that will help identify the changes to be made. After all changes have been made and committed on the new branch (whether it required one commit or multiple commits), merge the branch back into the `master` branch using a merge commit (i.e. do not use fast-forward).
- Never revert existing user changes or unrelated work without obtaining explicit authorization first.

