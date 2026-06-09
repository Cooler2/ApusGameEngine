# Demo Execution Plan

Date: 2026-06-09

This document turns `demo_plan.md` into an ordered backlog. The target layout and
final migration map live in `demo_plan.md`; this file says what to do next.

## Execution Rules

- Keep each task small enough to validate and commit independently.
- Prefer modern maintained demos as templates: `SimpleDemo`, `Draw2D`,
  `InputDemo`, `TextDemo`, `MultiWindow`, `NormalMap`.
- Every new or moved demo must have: `.dpr`, Delphi `.dproj`, FPC build via
  `demo\build_demo_fpc.cmd`, and `demo\demos.groupproj` entry parity.
- Delphi builds are manual-only. The task owner should prepare `.dproj` files
  and note that Delphi validation must be done manually.
- Do not physically move many demos at once. First make each demo modern and
  self-contained, then move it into the numbered directory layout.
- When a task exposes a reusable engine gap, record it in the problem knowledge
  base and decide whether it belongs in the demo, in R-15, or in another roadmap item.

## Progress

- Done: `R15-S00`, `R15-S01`, `R15-S02`, `R15-S03`, `R15-S10`, `R15-S11`.
- Next: `R15-S12`.

## Stage 0: Inventory and Build Metadata

Goal: make the current flat demo tree truthful and diagnosable before larger moves.

### R15-S00: Refresh the current inventory

- Update `demo/demo_inventory.md` with all currently present demos.
- Include `StyleDemo`, `TextDemo`, `NormalMap`, `Shaders`, `Borderless`, and
  any project folders that are missing from the old inventory.
- Mark demos as `engine5`, `engine4`, `legacy`, `scaffold`, or `blocked`.
- Validation: inventory rows match `demo/*` project folders; no known current demo is omitted.

### R15-S01: Fix demo group project drift

- Check every `<Projects Include=...>` in `demo\demos.groupproj`.
- Check every aggregate Build/Clean/Make target references an existing target.
- Add missing `.dproj` files or remove/disable stale group references.
- Known issues: `StyleDemo.dproj` is missing; `UIScaleDPI` aggregate targets are
  referenced without target declarations and no `UIScaleDPI.dproj` exists.
- Validation: XML parses; every referenced `.dproj` exists; aggregate target names resolve.

### R15-S02: Add a group-project validation helper

- Add a small repo-local script that validates `demo\demos.groupproj` paths and targets.
- Keep it read-only and fast so it can run before manual Delphi checks.
- Implementation: `demo\validate_demo_group.cmd` / `demo\validate_demo_group.ps1`.
- Validation: the helper catches missing `.dproj` files, missing project Build/Clean/Make
  targets, and dangling or incomplete aggregate target lists.

### R15-S03: Standardize new-demo checklist/template

- Document the required files and settings for a new demo.
- Use `NormalMap.dproj` or another current maintained `.dproj` as the template baseline.
- Include FPC wrapper build, Delphi manual check, group project entry, and ignored output cleanup.
- Implementation: `demo\new_demo_checklist.md`.
- Validation: the checklist is sufficient to recreate the NormalMap, StyleDemo,
  and UIScaleDPI integration steps.

## Stage 1: Small Standalone Demos

Goal: add or finish demos that do not require large merges.

### R15-S10: Create `HelloEngine`

- Build a compact first-run demo that replaces `SimpleDemo` as onboarding.
- Include a sprite/texture, text, a button/signal, and one tiny effect or sound trigger.
- Keep it intentionally small and readable.
- Implementation: `demo\HelloEngine`.
- Validation: FPC wrapper build passes; Delphi project is present for manual build;
  runtime check can be done manually or through Robot API when requested.

### R15-S11: Update `ProjectTemplate`

- Modernize imports and structure.
- Keep it a copy-and-go skeleton, not a feature showcase.
- Align `.dproj` and output paths with maintained demos.
- Implementation: compact current `demo\ProjectTemplate` starter plus group-project entry.
- Validation: FPC wrapper build passes; no deprecated `Apus.Common` or
  `Apus.CrossPlatform` imports remain in template code.

### R15-S12: Finish `StyleDemo` integration

- Add/repair `StyleDemo.dproj`.
- Ensure it is listed correctly in `demo\demos.groupproj`.
- Keep the demo focused on R-05 style behavior.
- Validation: FPC wrapper build passes if supported; Delphi project is ready for manual build.

### R15-S13: Keep `NormalMap` as feature-tier demo

- Leave current standalone demo intact while R-06 is still local/prototype code.
- Once R-06 is engine-level, replace local shader/material plumbing with the engine material path.
- Preserve camera/light diagnostics because they make the feature easy to inspect.
- Validation: FPC wrapper build passes; visual check confirms normal-map response is still obvious.

## Stage 2: Feature Merge Demos

Goal: remove redundant demos by merging them into one clear feature demo each.

### R15-S20: Merge `NinePatch` into `Draw2D`

- Add nine-patch examples to `Draw2D`.
- Keep standalone `NinePatch` until the merged demo is validated.
- After validation, remove `NinePatch` from group/project lists and mark it migrated.
- Validation: `Draw2D` shows nine-patch cases; old `NinePatch` coverage is not lost.

### R15-S21: Merge `ControllerDemo` into `Input`

- Add gamepad/joystick screens to `InputDemo`.
- Keep keyboard/mouse diagnostics intact.
- Rename/move to final `Input` only after merged coverage works.
- Validation: FPC wrapper build passes; manual controller check path is documented.

### R15-S22: Build `Sound` GUI demo

- Rewrite `SoundDemo` as a regular engine GUI demo.
- Cover music, samples, volume, pan, backend status, and signal-driven playback.
- Keep old console behavior only as reference until parity is reached.
- Validation: FPC wrapper build passes; manual audio playback checklist is documented.

### R15-S23: Build `Platform` demo

- Merge `MultiWindow`, `UIScaleDPI`, and `Borderless`.
- Keep platform concerns separated by screens/tabs: windows, DPI, borderless/fullscreen.
- Do not block this task on unresolved R-02 engine work; document blocked subcases.
- Validation: FPC wrapper build passes; manual checks cover window creation, DPI scale, and borderless toggle.

### R15-S24: Build `AdvancedGfx` demo

- Merge `AdvTex` and `ShadowMap`.
- Keep `NormalMap` out of this demo unless it is used as part of a larger combined effect.
- Validation: FPC wrapper build passes; texture-array/mipmap/shadow-map cases remain visible.

## Stage 3: Modernize Existing Feature Demos

Goal: make retained demos current before physical folder restructuring.

### R15-S30: Expand `Scene3D`

- Rename or evolve `Simple3D` into `Scene3D`.
- Cover mesh loading, camera controls, lighting, textures, materials, and basic transforms.
- Keep it simpler than `Game3DShowcase`; it is a reference demo, not a scene architecture probe.
- Validation: FPC wrapper build passes; no avoidable deprecated imports remain in demo code.

### R15-S31: Modernize `Shaders`

- Expand shader examples around custom uniforms, sampling, and post effects.
- Remove direct dependencies on obsolete graphics APIs where practical.
- Validation: FPC wrapper build passes; shader examples still render visibly different outputs.

### R15-S32: Modernize `CharAnimation`

- Update imports and project settings.
- Keep focus on skeletal animation, blending, skeleton visualization, and attachment points.
- Validation: FPC wrapper build passes or a concrete engine/model-loader blocker is recorded.

### R15-S33: Expand `Animation`

- Rename/evolve `Tweenings` into `Animation`.
- Show tweens, easing, chained animations, interrupted transitions, and UI transition examples.
- Validation: FPC wrapper build passes; examples are deterministic enough for manual inspection.

### R15-S34: Move performance demos as-is

- Move `Particles`, `Billboards`, and `VertexBuffer` to `3-advanced/` after build metadata is clean.
- Avoid scope creep; performance demo rewrites are out of R-15 MVP.
- Validation: FPC wrapper build passes or each legacy blocker is recorded before move.

## Stage 4: EngineTest Distribution

Goal: retire `EngineTest` without losing manual coverage.

### R15-S40: Inventory `EngineTest` cases

- List each visible/testable `EngineTest` mode and resource dependency.
- Assign every case to a target demo: `Draw2D`, `Text`, `Scene3D`, `Shaders`,
  `Resources`, `AdvancedGfx`, or archive/remove.
- Validation: every mode has an owner and a disposition.

### R15-S41: Move text cases into `Text`

- Transfer bitmap font, FreeType, Unicode, alignment, formatting, and scaling cases.
- Keep resources local or shared deliberately; avoid hidden dependencies on `EngineTest\res`.
- Validation: `Text` still builds and can demonstrate each assigned case.

### R15-S42: Move drawing/resource/3D cases into owner demos

- Transfer remaining assigned cases in small batches.
- Keep each batch independently validated and committed.
- Validation: owner demo builds after each batch; removed `EngineTest` case has a visible replacement.

### R15-S43: Remove `EngineTest`

- Remove only after all assigned cases are migrated or explicitly archived.
- Update inventory, group project, CI/demo lists, and docs.
- Validation: no active docs or project files point to `EngineTest` except historical notes.

## Stage 5: Numbered Layout Migration

Goal: move from the flat demo tree to the final `1-start/`, `2-features/`,
`3-advanced/`, `4-complex/` layout.

### R15-S50: Add build support for nested demo paths

- Update `demo\build_demo_fpc.cmd` and group-project conventions as needed.
- Ensure output paths still go to `bin`/`bin64` and unit outputs stay outside source roots.
- Validation: one nested demo builds through the wrapper.

### R15-S51: Move start-tier demos

- Move `ProjectTemplate` and `HelloEngine` into `1-start/`.
- Update project files, group project, docs, and any template repository metadata.
- Validation: both demos build through the wrapper.

### R15-S52: Move feature-tier demos

- Move feature demos into `2-features/` in small groups.
- Update relative resource paths and project metadata per move.
- Validation: each moved demo builds before moving the next group.

### R15-S53: Move advanced-tier demos

- Move advanced/performance demos into `3-advanced/`.
- Keep performance demos otherwise unchanged.
- Validation: each moved demo builds or has a documented legacy blocker.

### R15-S54: Add `4-complex/Game3DShowcase`

- Create the home for R-017.
- Keep the first slice skeleton-first: scene organization, camera, material path,
  multi-pass/post-process placeholders, and diagnostics.
- Validation: FPC wrapper build passes; R-017 architecture gaps are documented as they appear.

## Stage 6: CI and Closure

Goal: make the suite maintainable after restructuring.

### R15-S60: Refresh demo CI list

- Update CI smoke builds to use stable demo paths.
- Keep blocked legacy demos out of required CI until their blockers are closed and documented.
- Validation: CI demo build list matches the restructured stable set.

### R15-S61: Add Robot smoke hooks for key demos

- Add or document minimal Robot API checks for representative demos.
- Suggested first set: `HelloEngine`, `Draw2D`, `Text`, `Input`, `Scene3D`, `NormalMap`.
- Validation: each selected demo has a launch/capture/exit path or a documented manual-only reason.

### R15-S62: Close R-15 MVP

- Verify target layout, inventory, group project, CI list, and roadmap status.
- Confirm obsolete demos are removed only after their coverage is migrated.
- Validation: R-15 acceptance criteria in `engine5_feature_roadmap.md` can be checked off honestly.

## Suggested Next Task

Continue with `R15-S12`: finish `StyleDemo` integration.
