# Bundle Update with Version Constraints

This feature allows you to specify version constraints when updating gems with `bundle update`.

## Usage

### Basic Syntax

```bash
bundle update [gem_name] ["gem_name, version_constraint"]
```

### Examples

#### Update a gem to the latest version
```bash
bundle update nokogiri
```

#### Update a gem with a specific version constraint
```bash
bundle update "rails, >=8.0.2"
```

#### Update multiple gems with mixed constraints
```bash
bundle update nokogiri "rails, >=8.0.2" "activesupport, ~>7.0"
```

#### Update with complex version constraints
```bash
bundle update "activesupport, >=3.0, <4.0"
```

## Version Constraint Syntax

The version constraints follow the same syntax as RubyGems requirements:

- `>= 1.0` - Greater than or equal to version 1.0
- `<= 2.0` - Less than or equal to version 2.0
- `~> 1.2` - Greater than or equal to 1.2, less than 1.3
- `= 1.0` - Exactly version 1.0
- `> 1.0, < 2.0` - Greater than 1.0 and less than 2.0

## Use Cases

This feature is particularly useful for:

1. **Security Updates**: Quickly update to a specific version that fixes a security vulnerability
2. **Rollback Scenarios**: Downgrade to a previous version if a newer version introduces issues
3. **Automated Updates**: Script-based updates that need to respect version constraints
4. **Minimal Updates**: Update only specific dependencies while keeping others at their current versions

## Examples in Practice

### Security Patch Update
```bash
# Update nokogiri to the latest version that fixes a security issue
bundle update "nokogiri, >=1.13.0"
```

### Framework Version Update
```bash
# Update Rails to a specific minor version
bundle update "rails, ~>7.0.0"
```

### Rollback After Issues
```bash
# Rollback to a previous working version
bundle update "some_gem, =2.1.0"
```

### Multiple Constrained Updates
```bash
# Update multiple gems with different constraints
bundle update "rails, >=7.0.0" "nokogiri, ~>1.13" "rack, >=2.2.0"
```

## Notes

- Version constraints are applied during the resolution phase
- If a constraint cannot be satisfied, the update will fail
- The lockfile will be updated to reflect the new versions
- This feature works with all existing `bundle update` options like `--conservative`, `--group`, etc. 