# Contributing to OPTIX

Thank you for considering contributing to OPTIX!

This project was originally built by a beginner (Watrxx) with heavy help
from AI assistants. Any help — fixes, translations, new themes, better
docs — is very welcome. Here is how to do it in a way that is easy for us
to handle.

## Before you start

- Please be kind. This is a learning project; code style may be unusual.
- Check the [existing issues](https://github.com/Watrxx/Optixscript/issues)
  to avoid duplicates.
- For large changes, open an issue or discussion first so we agree on the
  direction before you invest time.

## Reporting bugs

Use the bug report template in `.github/ISSUE_TEMPLATE/bug_report.md`.
Always include:

- Windows version and PowerShell version (`$PSVersionTable.PSVersion`).
- Whether you ran `run_optix.bat` as administrator.
- The console output (or a screenshot) of the failure.
- The relevant lines from the `logs/` folder if possible.

## Submitting changes

1. Fork the repository.
2. Create a branch: `git checkout -b feature/your-change`.
3. Make your changes, keeping the existing structure and scripts intact.
4. Test with `run_optix.bat` (as administrator if possible).
5. Commit with a short, clear message, push, and open a pull request
   using the pull request template.

## Code style

- Keep everything in PowerShell 5.1 compatible syntax (no `pwsh`-only
  features).
- Match the existing structure: config lives in `config/`, new interface
  strings go into both the language files in `config/lang/` and the
  default dictionary in `optimization_script.ps1`.
- If you add a new UI string, add translations for all languages in
  `config/lang/` (you may leave them as English placeholders if you do
  not speak the language).
- Do not commit anything from `logs/`.

## License

By contributing, you agree that your contributions are licensed under the
same [MIT License](LICENSE) as the rest of the project.