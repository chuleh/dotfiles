---
name: sec-python
description: Python security guidance — input validation, dependency pinning/scanning, safe subprocess and SQL usage, cryptography, and error handling. Use when writing or reviewing Python code, requirements.txt, or scripts that run shell commands or touch databases.
---

# Python Security

## Input Validation & Sanitization
- **Always validate inputs** using Pydantic, marshmallow, or similar
- Use parameterized queries - never string concatenation for SQL
- Sanitize data for shell commands - prefer libraries over subprocess

## Dependency Management
- Pin exact versions in requirements.txt
- Use `pip-audit` or `safety` for vulnerability scanning
- Keep dependencies minimal - audit what you include
- Use virtual environments for isolation

## Code Patterns
```python
# GOOD - Parameterized query
cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))

# BAD - SQL injection risk
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")

# GOOD - Subprocess safety
subprocess.run(["kubectl", "get", "pods", namespace], check=True)

# BAD - Command injection risk
os.system(f"kubectl get pods {namespace}")
```

## Error Handling
- Never expose stack traces or internal errors to users
- Log errors with context but sanitize sensitive data
- Use structured logging (JSON format preferred)

## Cryptography
- Use `cryptography` library, not `pycrypto`
- Never implement custom crypto algorithms
- Use strong key derivation (PBKDF2, bcrypt, Argon2)
- Generate secure random values with `secrets` module
