# Repository requirements

These instructions apply to the entire repository. Preserve them in every
change, including experiments.

## Required project context

- Before inspecting, planning, or changing this repository, read
  `PROJECT_HANDOFF.md` completely. It records the implemented architecture,
  deployment sequence, safety model, validation evidence, and known caveats.
- Keep `PROJECT_HANDOFF.md` accurate when a change affects behavior,
  dependencies, platform support, deployment, rollback, or outstanding risks.
- Treat the handoff as context, not as a substitute for checking the current
  worktree and code. Verify `git status`, recent commits, and the relevant Salt
  states before acting.

## Minimize custom code

- Prefer declarative Salt states and configuration of stock Qubes programs
  over additional Python, shell, or other runtime helpers.
- Check existing program capabilities before adding or extending a helper.
  Keep unavoidable custom code small, shared, and documented with its reason.
- Putting a script inside Salt YAML does not remove its custom-code maintenance
  cost. Reduce the underlying runtime code while preserving required behavior.

## Offline Qubes deployment

- Treat the deployment target as a clean, supported Qubes OS installation
  whose dom0 has no direct Internet access and no default network route. Every
  normal install, apply, validation, and rollback path must work without
  enabling networking in dom0.
- The portable deployment path may use a configured networked UpdateVM. Dom0
  packages must be installed through Qubes' UpdateVM-backed Salt package
  provider. TemplateVM packages must use the normal Qubes UpdatesProxy and
  native distribution package manager path.
- Never rely on packages, caches, configuration, build output, or Internet
  access that exists only on the development machine.
- Persistent behavior must be encoded in the committed Salt formula or its
  committed assets. Do not leave required manual or live-only configuration
  steps for dom0, TemplateVMs, or qubes.
- The default and documented portable path must never make a direct network
  request from dom0. Any direct-dom0 maintainer override must remain explicitly
  opt-in, isolated from deployment, and unnecessary on the target machine.

## Dependency policy

- Deployment inputs must be either committed to this repository or supplied
  by repositories enabled by a stock supported Qubes installation: official
  Qubes repositories and their supported Fedora or Debian repositories. Fetch
  and signature-verify system packages through Qubes' native UpdateVM or
  UpdatesProxy path.
- Do not use third-party repositories, COPRs, PPAs, arbitrary download URLs,
  or language-specific package indexes in the portable build.
- Do not add deployment dependencies from pip/PyPI, npm, Cargo, Go modules,
  RubyGems, Conda, or similar ecosystems. Do not add another language runtime
  or framework.
- Python helpers must run with the Python interpreter already shipped in the
  relevant Qubes component and use only its standard library. Never install a
  Python module for this project.
- Deployment Salt states and scripts must not run `curl`, `wget`, `git clone`,
  a source build, or an equivalent network fetch.
- Minimize RPM and DEB dependencies. Treat the packages already declared in
  the Salt states as the dependency ceiling. Adding another package requires
  explicit user approval, confirmation that it is in the standard signed
  repositories above, and documentation of why existing Qubes tools or the
  Python standard library are insufficient.

## Maintainer builds and verification

- A networked maintainer-only source build is allowed only when it is clearly
  separated from deployment and is never invoked by a Salt state or deployment
  script. Commit the deployable output, pin and verify its hash, and retain
  reproducible source and provenance information.
- Before handing off or committing a change, audit every deployment entry
  point for direct network calls and new dependencies. Render or dry-run the
  affected Salt states with their default settings and confirm that dom0 uses
  the UpdateVM-backed package path.
- Test with stock installed tooling. Do not install a linter, test framework,
  or helper package merely to validate this repository.
