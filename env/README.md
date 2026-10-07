# Local environment files

Store local runtime env files here when you need to keep credentials outside the
repository root.

Rules:

- Do not commit real merchant credentials.
- Use `freedompay.local.env` for local Freedom Pay values.
- Keep only placeholder examples in git.
- Load the file explicitly before running backend commands.

Example:

```bash
set -a
source env/freedompay.local.env
set +a
```
