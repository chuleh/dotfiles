---
name: sec-ruby-rails
description: Ruby on Rails security guidance — CSRF/strong params, safe ActiveRecord queries, auth/authorization, dependency auditing, and safe command execution. Use when writing or reviewing Ruby/Rails code.
---

# Ruby Security

## Rails Security Features
- **Always enable CSRF protection** (enabled by default)
- Use Strong Parameters for mass assignment protection
- Enable Content Security Policy (CSP)
- Set secure cookie flags: `httponly`, `secure`, `samesite`

## SQL & Query Safety
```ruby
# GOOD - Parameterized query
User.where("email = ?", params[:email])

# BAD - SQL injection risk
User.where("email = '#{params[:email]}'")
```

## Authentication & Authorization
- Use bcrypt for password hashing (built into Rails)
- Implement proper session management
- Use Pundit or CanCanCan for authorization
- Enforce MFA for privileged accounts

## Dependency Management
- Run `bundle audit` regularly
- Keep Rails and gems updated
- Review dependencies before adding
- Use `Gemfile.lock` for version pinning

## Command Execution
```ruby
# GOOD - Array form prevents shell injection
system("kubectl", "get", "pods", namespace)

# BAD - Shell injection risk
system("kubectl get pods #{namespace}")
```
