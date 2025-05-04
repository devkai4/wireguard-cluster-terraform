# Contributing to VPN Server Cluster Project

Thank you for your interest in contributing to this project! This document provides guidelines and information for contributors.

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to:
- Use welcoming and inclusive language
- Be respectful of differing viewpoints and experiences
- Gracefully accept constructive criticism
- Focus on what is best for the project
- Show empathy towards other contributors

## How to Contribute

### Reporting Issues

Before creating an issue, please check existing issues to avoid duplicates. When creating a new issue, include:

1. **Clear description** of the issue
2. **Steps to reproduce** (if applicable)
3. **Expected behavior** vs **actual behavior**
4. **Environment details** (OS, tools versions)
5. **Logs or error messages** (if available)

### Submitting Changes

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Test your changes thoroughly
5. Submit a pull request

## Development Process

### Branch Naming Convention

- `feature/` - New features (e.g., `feature/add-prometheus-dashboards`)
- `bugfix/` - Bug fixes (e.g., `bugfix/fix-vpc-routing`)
- `hotfix/` - Critical production fixes (e.g., `hotfix/security-patch`)
- `docs/` - Documentation updates (e.g., `docs/update-deployment-guide`)
- `refactor/` - Code refactoring (e.g., `refactor/terraform-modules`)

### Commit Message Format

Follow the conventional commits format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, missing semi-colons, etc.)
- `refactor`: Code refactoring
- `test`: Adding missing tests
- `chore`: Changes to build process or auxiliary tools
- `security`: Security improvements

Examples:
```
feat(terraform): add auto-scaling group for VPN servers
fix(ansible): correct WireGuard configuration template
docs(readme): update deployment instructions
security(iam): implement least privilege policies
```

### Code Standards

#### Terraform
- Use consistent formatting (`terraform fmt`)
- Follow official [Terraform style guide](https://www.terraform.io/docs/language/syntax/style.html)
- Include meaningful descriptions for variables and outputs
- Use semantic versioning for modules
- Always include validation rules for critical variables

#### Ansible
- Follow [Ansible best practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- Use YAML formatting consistently
- Include meaningful names for tasks
- Use variables for configurable values
- Always include tags for selective execution

#### General
- No hardcoded credentials or secrets
- Use environment variables or secure vaults
- Include comments for complex logic
- Keep functions/modules focused and single-purpose
- Write self-documenting code where possible

### Testing Requirements

Before submitting changes:

1. **Infrastructure Tests**
   - Run `terraform validate`
   - Run `terraform plan` to check for issues
   - Use `terraform fmt` to format code
   - Run `tflint` for additional validation

2. **Ansible Tests**
   - Run playbooks with `--syntax-check`
   - Test with `--check` mode first
   - Verify idempotency

3. **Security Tests**
   - Run `tfsec` on Terraform code
   - Check for exposed secrets
   - Validate IAM permissions follow least privilege

4. **Documentation**
   - Update relevant documentation
   - Ensure README is current
   - Update CHANGELOG.md

### Pull Request Process

1. **Before Creating PR**
   - Ensure all tests pass
   - Update documentation
   - Add CHANGELOG entry
   - Squash commits if needed

2. **PR Description Should Include**
   - Summary of changes
   - Related issue(s)
   - Testing performed
   - Screenshots (if UI changes)
   - Breaking changes (if any)

3. **Review Process**
   - Address review comments promptly
   - Keep discussions focused and professional
   - Be open to feedback and suggestions

## Security Considerations

When contributing:

1. **Never commit secrets** (API keys, passwords, tokens)
2. **Use secure defaults** in configurations
3. **Follow security best practices** for the specific technology
4. **Report security vulnerabilities** privately
5. **Include security implications** in PR descriptions

## Documentation

### What to Document

- Architecture decisions
- Configuration options
- Deployment procedures
- Troubleshooting guides
- API interfaces
- Security considerations

### Documentation Style

- Use clear, concise language
- Include examples where helpful
- Use proper markdown formatting
- Keep diagrams up to date
- Explain the "why" not just the "what"

## Release Process

1. Update version in relevant files
2. Update CHANGELOG.md
3. Create a pull request for release
4. After approval, merge to main
5. Tag the release
6. Create GitHub release with notes

## Questions or Need Help?

- Create an issue for questions
- Review existing documentation
- Check closed issues for similar questions

## Recognition

Contributors will be recognized in:
- CHANGELOG.md
- GitHub contributors page
- Project documentation (for significant contributions)

Thank you for contributing to make this project better!