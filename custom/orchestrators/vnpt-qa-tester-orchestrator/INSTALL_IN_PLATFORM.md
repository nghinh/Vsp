# VNPT Platform Installation Notes

This package is now organized in the same style as existing VNPT orchestrator packages:

```text
vnpt-bmad-custom/vnpt-qa-tester-orchestrator/
├── .opencode/
│   ├── agents/vnpt-qa-tester-orchestrator.md
│   └── commands/vnpt-qa-test-loop.md
├── README.md
├── ORCHESTRATOR.md
├── config/
├── phases/
├── skills/
├── templates/
├── schemas/
└── scripts/
```

## Manual install into an existing project

From the target repository root:

```bash
mkdir -p .opencode/agents .opencode/commands custom/orchestrators docs
cp vnpt-qa-tester-orchestrator/.opencode/agents/*.md .opencode/agents/
cp vnpt-qa-tester-orchestrator/.opencode/commands/*.md .opencode/commands/
rm -rf custom/orchestrators/vnpt-qa-tester-orchestrator
cp -R vnpt-qa-tester-orchestrator custom/orchestrators/vnpt-qa-tester-orchestrator
cp vnpt-qa-tester-orchestrator/README.md docs/vnpt-qa-tester-orchestrator.README.md
```

Then restart OpenCode and run:

```text
/vnpt-qa-test-loop <feature-or-module-scope>
```

## Installer integration required for full automatic install

The root `install_vnpt_bmad_custom_all.py` in `vnpt-ai-driven-platform` should copy this orchestrator into the target repo. It needs to copy:

- `.opencode/commands/vnpt-qa-test-loop.md`
- `.opencode/agents/vnpt-qa-tester-orchestrator.md`
- full package resources to `custom/orchestrators/vnpt-qa-tester-orchestrator/`
- README to `docs/vnpt-qa-tester-orchestrator.README.md`

If you are installing manually, the copy commands in the previous section still work.
