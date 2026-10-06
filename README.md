# You Should Know for Codex

Catch the important caveats, failed checks, skipped validation, and hidden limitations that are easy to miss in a long Codex run.

## Install

Requirements: the Codex CLI and Node.js 18+.

### Windows

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/Divyansh-0909/codex-you-should-know/main/install.ps1 -OutFile "$env:TEMP\you-should-know-install.ps1"
& "$env:TEMP\you-should-know-install.ps1"
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/Divyansh-0909/codex-you-should-know/main/install.sh -o /tmp/you-should-know-install.sh
bash /tmp/you-should-know-install.sh
```

The installer:

1. Adds this repository as a Codex plugin marketplace.
2. Installs `you-should-know`.
3. Detects whether your Codex build supports hooks bundled by plugins.
4. If needed, adds a small compatibility hook block to `~/.codex/config.toml`.
5. Leaves hook trust to Codex. On the next launch, review the two hooks and choose **Trust all and continue** if you are happy with them.

### Manual install

```bash
codex plugin marketplace add Divyansh-0909/codex-you-should-know
codex plugin add you-should-know@you-should-know
```

On Codex builds where bundled plugin hooks are unavailable, use `install.ps1` or `install.sh` once so the compatibility hooks are registered too.

## How it works

The plugin uses two Codex lifecycle hooks:

```text
Codex uses a tool
      ↓
PostToolUse
      ↓
Keep a small redacted log of noteworthy outcomes
      ↓
Codex tries to finish the turn
      ↓
Stop
      ↓
Review the final answer + noteworthy tool outcomes
      ↓
Surface a concise "You should know" warning when useful
```

For example, Codex might finish with a normal implementation summary while a test failure is buried earlier in the run. The plugin can surface:

```text
You should know: the payment webhook change was made, but one validation failed because the webhook test timed out.
```

It looks for things such as:

- failed commands, tests, or validation
- skipped or unverified checks
- temporary workarounds and limitations
- incomplete required work
- material assumptions and follow-up items
- higher-severity security, credential, corruption, or data-loss signals

Clean successful turns stay quiet.

## Reviewer behavior

The Stop hook first tries a small isolated Codex review using `gpt-5.6-luna` and your existing Codex authentication. The nested review is read-only, ephemeral, and runs with plugins disabled.

If the reviewer model is unavailable, rate-limited, or out of quota, the plugin automatically falls back to deterministic local checks. A reviewer failure never blocks a normal Codex turn.

The plugin is advisory by default. It does **not** automatically force Codex to keep working. If you explicitly want that behavior, set:

```text
YSK_AUTOCONTINUE=1
```

Then a review that identifies clearly unfinished required work can return a Stop `block` decision and send Codex back for another pass.

## Privacy

The PostToolUse hook does not save the full transcript. It keeps a small context window around noteworthy signals and redacts common credential forms, bearer tokens, API keys, email addresses, and Indian phone-number patterns before persistence.

Data is stored locally under:

```text
~/.codex/you-should-know-data
```

The optional model review sends the compact final-message/event context through your normal Codex account, just like a regular Codex request.

## Configuration

Environment variables:

| Variable | Effect |
| --- | --- |
| `YSK_AI_REVIEW=0` | Disable the model reviewer and use local checks only |
| `YSK_MODEL=<model>` | Choose another supported Codex reviewer model |
| `YSK_REVIEW_TIMEOUT_MS=<ms>` | Change the model-review timeout; default is `25000` |
| `YSK_AUTOCONTINUE=1` | Allow clearly unfinished work to send Codex back for another pass |

## Development

Run the complete test suite from the repository root:

```bash
node --test plugins/you-should-know/tests/*.test.mjs
```

The tests cover the real hook executables, event persistence, Stop output, clean-turn silence, loop prevention, redaction, compatibility user-hook mode, and model-review fallback.

## License

MIT. See [LICENSE](LICENSE).
