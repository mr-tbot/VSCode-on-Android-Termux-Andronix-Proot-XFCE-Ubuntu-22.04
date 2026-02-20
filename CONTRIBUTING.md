# Contributing to VSCode on Android

Thank you for considering contributing to this project! This guide will help you get started.

## How Can I Contribute?

### Reporting Bugs

If you find a bug, please open an issue with:
- Your device and Android version
- Termux/Andronix version
- Ubuntu version
- Steps to reproduce the issue
- Expected vs actual behavior
- Any error messages or logs

### Suggesting Enhancements

We welcome suggestions for improvements! Please open an issue with:
- Clear description of the enhancement
- Why this enhancement would be useful
- Any examples or mockups

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Make your changes** following our coding standards
3. **Test your changes** thoroughly
4. **Update documentation** if needed
5. **Submit a pull request** with a clear description

## Development Guidelines

### Bash Script Standards

- Use `#!/bin/bash` shebang
- Include `set -e` for error handling
- Use meaningful variable names
- Add comments for complex logic
- Follow existing code style
- Make scripts executable (`chmod +x`)

### Testing

Before submitting a PR:
1. Run `bash -n script.sh` to check syntax
2. Run `./test-scripts.sh` to validate functionality
3. Test on actual proot environment if possible
4. Document any limitations or known issues

### Commit Messages

Use clear, descriptive commit messages:
- Start with a verb (Add, Fix, Update, Remove, etc.)
- Keep first line under 72 characters
- Add detailed description if needed

Examples:
```
Add support for Ubuntu 24.04
Fix permission issues with VSCode extensions
Update README with troubleshooting steps
```

## Project Structure

```
.
├── setup-vscode.sh      # Main setup script
├── quick-start.sh       # User-friendly wrapper
├── uninstall.sh         # Cleanup script
├── test-scripts.sh      # Test suite
├── README.md            # Main documentation
├── CONTRIBUTING.md      # This file
├── LICENSE              # MIT License
└── .gitignore           # Git ignore rules
```

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers
- Accept constructive criticism
- Focus on what's best for the community
- Show empathy towards others

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or insulting comments
- Personal or political attacks
- Publishing others' private information
- Other unprofessional conduct

## Questions?

If you have questions, feel free to:
- Open an issue with the "question" label
- Reach out to maintainers

## Recognition

Contributors will be recognized in:
- Git commit history
- Release notes for significant contributions
- README acknowledgments section (coming soon)

Thank you for contributing! 🎉
