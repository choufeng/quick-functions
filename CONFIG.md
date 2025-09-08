# devup 配置说明 | devup Configuration Guide

## 📁 配置文件位置 | Configuration File Location

配置文件位于：`~/.quick-functions/devup-configs.json`

The configuration file is located at: `~/.quick-functions/devup-configs.json`

## 📝 配置文件格式 | Configuration File Format

```json
{
  "configs": [
    {
      "name": "配置名称",
      "description": "配置描述",
      "package_dir": "$HOME/项目路径/packages/包目录",
      "app_dir": "$HOME/项目路径/apps/应用目录",
      "package_name": "@组织名/包名",
      "start_command": "启动命令"
    }
  ]
}
```

## 🔧 配置项说明 | Configuration Fields

| 字段 Field | 必需 Required | 说明 Description |
|------------|---------------|------------------|
| `name` | ✅ | 配置名称，用于 `devup -name` | Configuration name for `devup -name` |
| `description` | ✅ | 配置描述 | Configuration description |
| `package_dir` | ✅ | 包目录路径 | Package directory path |
| `app_dir` | ✅ | 应用目录路径 | Application directory path |
| `package_name` | ✅ | npm/pnpm 包名 | npm/pnpm package name |
| `start_command` | ❌ | 启动命令，默认为 `./pnpm start` | Start command, defaults to `./pnpm start` |

## 📖 使用示例 | Usage Examples

### 单个配置 | Single Configuration

```json
{
  "configs": [
    {
      "name": "my-react-app",
      "description": "My React application",
      "package_dir": "$HOME/development/my-project/packages/react-components",
      "app_dir": "$HOME/development/my-project/apps/web-app",
      "package_name": "@myorg/react-components",
      "start_command": "./pnpm start"
    }
  ]
}
```

### 多个配置 | Multiple Configurations

```json
{
  "configs": [
    {
      "name": "frontend",
      "description": "Frontend React components",
      "package_dir": "$HOME/development/myapp/packages/ui-components", 
      "app_dir": "$HOME/development/myapp/apps/frontend",
      "package_name": "@myapp/ui-components",
      "start_command": "./pnpm start"
    },
    {
      "name": "admin",
      "description": "Admin dashboard",
      "package_dir": "$HOME/development/myapp/packages/admin-components",
      "app_dir": "$HOME/development/myapp/apps/admin",
      "package_name": "@myapp/admin-components", 
      "start_command": "pnpm dev"
    },
    {
      "name": "mobile",
      "description": "Mobile app components",
      "package_dir": "$HOME/development/myapp/packages/mobile-ui",
      "app_dir": "$HOME/development/myapp/apps/mobile",
      "package_name": "@myapp/mobile-ui",
      "start_command": "npm run dev"
    }
  ]
}
```

## 🚀 使用方法 | Usage

```bash
# 使用第一个配置 | Use first configuration
devup

# 使用指定配置 | Use specific configuration  
devup -frontend
devup -admin
devup -mobile

# 查看所有配置 | View all configurations
devup --list

# 查看配置详情 | View configuration details
devup --show
devup --show frontend

# 查看帮助 | View help
devup --help
```

## 💡 提示 | Tips

1. **环境变量**：可以使用 `$HOME` 等环境变量 | You can use environment variables like `$HOME`
2. **默认启动命令**：如果没有设置 `start_command`，默认使用 `./pnpm start` | Default start command is `./pnpm start` if not specified
3. **配置验证**：使用 `devup --show` 检查路径是否正确 | Use `devup --show` to verify paths are correct
4. **立即生效**：修改配置后立即生效，无需重启 | Changes take effect immediately, no restart needed

## ⚠️ 常见问题 | Common Issues

1. **路径不存在**：确保 `package_dir` 和 `app_dir` 路径正确存在 | Make sure `package_dir` and `app_dir` paths exist
2. **JSON 格式**：确保 JSON 格式正确，可以使用在线 JSON 验证工具 | Ensure valid JSON format, use online JSON validators
3. **权限问题**：确保对配置的目录有读写权限 | Ensure read/write permissions for configured directories