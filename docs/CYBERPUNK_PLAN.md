# OpenClaw HQ — Lofi Cyberpunk Overhaul Plan

## Objective
Deliver a full visual/interaction overhaul (intensity C: immersive cyberpunk terminal aesthetic) while preserving all existing functionality and workflows.

## Team Roles
- **Atlas**: Design language + constraints + accessibility guardrails
- **Matrix**: Implementation blueprint + componentization strategy
- **Prism**: QA + security validation checklist and ship gate
- **Scope**: Phased delivery plan + risk register + DoD

## Implementation Principles
1. Preserve logic, transport, and persistence behavior.
2. Change visual system and UX polish only.
3. Keep keyboard usability and contrast acceptable.
4. Apply style tokens consistently across all tabs.

## Current Pass (implemented)
- Themed palette update across shared `Theme.swift`
- Global cyberpunk backdrop + scanline overlay
- Sidebar/app shell header retheme to terminal-style branding
- Chat page restyled as terminal conversation surface
- Monospace-forward style for high-signal entities (agents/tasks/activity)

## Next Passes
1. Shared reusable primitives (HQPanel, HQBadge, HQButton) and migrate all views
2. Per-screen polish pass for Agents/Tasks/Usage/Activity/Settings
3. Accessibility hardening pass (reduced motion option + contrast audit)
4. Full Prism signoff gate
