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
  provider. TemplateVM distribution packages must use the normal Qubes
  UpdatesProxy and native distribution package manager path. Other guest
  software may use the upstream installation methods permitted below;
  perform its downloads and builds inside a qube, with a reproducible,
  documented guest networking or proxy setup. Dom0 must remain offline.
- Never rely on packages, caches, configuration, build output, or Internet
  access that exists only on the development machine.
- Persistent behavior must be encoded in the committed Salt formula or its
  committed assets. Do not leave required manual or live-only configuration
  steps for dom0, TemplateVMs, or qubes.
- The default and documented portable path must never make a direct network
  request from dom0. Any direct-dom0 maintainer override must remain explicitly
  opt-in, isolated from deployment, and unnecessary on the target machine.

## Dom0 dependency policy

The restrictions in this section apply to software installed or executed in
dom0, including shared helpers that also run there. They do not apply to
software installed and executed only inside guest qubes.

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
- Dom0 Python helpers must run with the Python interpreter already shipped in
  dom0 and use only its standard library. Never install a Python module in
  dom0 for this project.
- Deployment Salt states and scripts executing in dom0 must not run `curl`,
  `wget`, `git clone`, a source build, or an equivalent network fetch.
- Minimize RPM and DEB dependencies. Treat the packages already declared in
  the Salt states as the dependency ceiling. Adding another package requires
  explicit user approval, confirmation that it is in the standard signed
  repositories above, and documentation of why existing Qubes tools or the
  Python standard library are insufficient.

## Guest-qube dependency policy

- Inside TemplateVMs, AppVMs, StandaloneVMs and DispVMs, third-party
  repositories, upstream downloads, language package indexes (including
  pip/PyPI and npm), additional runtimes/frameworks, Python modules and source
  builds are allowed when needed for the user's requested software or work.
  The dom0 dependency ceiling and package-by-package approval requirement do
  not apply inside these qubes; do not request a separate policy exception.
- Prefer native distribution packages where suitable. For upstream software,
  use the project's documented sources, record versions and provenance, and
  use version pins, lockfiles and hash/signature verification as appropriate
  for reproducible deployment. Document how these components receive updates.
- Keep persistent guest installation and configuration in Salt and committed
  assets. Downloads, dependency installation and builds must execute inside a
  qube, not in dom0. Do not rely on development-machine caches or manual setup.
- Minimize custom code and unnecessary dependencies in guests too, without
  imposing dom0's standard-library-only or stock-repository-only restrictions.

## Maintainer builds and verification

- A maintainer source build producing an artifact for dom0 must be clearly
  separated from deployment and never invoked by a Salt state or deployment
  script. Perform any networked build inside a qube, commit the deployable
  output, pin and verify its hash, and retain reproducible source and
  provenance information. Guest-only builds follow the guest policy above
  and may be part of guest Salt deployment.
- Before handing off or committing a change, audit every deployment entry
  point for network calls and new dependencies, distinguishing dom0 execution
  from guest execution. Render or dry-run affected Salt states with their
  default settings and confirm that dom0 uses the UpdateVM-backed package
  path. Documentation-only changes need no Salt apply or VM startup.
- Test dom0 changes with stock installed tooling. Do not install a linter,
  test framework or helper package in dom0 merely to validate this repository.
  Guest validation tooling follows the guest dependency policy.
