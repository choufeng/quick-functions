# Quick Functions 🚀

一个便捷的终端工具函数库，帮助开发者快速设置常用的 shell 函数。

A convenient terminal utility function library to help developers quickly set up commonly used shell functions.

## 功能 | Features

### `devup` - Node.js 本地包强制更新工具
强制更新本地 Node.js 包并启动开发服务器的自动化工具。特别适用于 monorepo 项目中的本地包开发。

- 🔄 自动执行 `pnpm pack` 构建最新包
- 📦 智能查找最新的 `.tgz` 文件（按修改时间）
- 🗑️ 强制移除并重新安装包（解决相同版本不更新问题）
- 🚀 自动启动开发服务器
- 🌍 中英文双语提示
- 💻 支持 zsh 和 bash
- 🖥️ 跨平台兼容（macOS/Linux）

## 快速安装 | Quick Installation

```bash
# 克隆项目
git clone <repository-url> ~/quick-functions
cd ~/quick-functions

# 安装
./install.sh

# 开始使用
devup
```

## 手动安装 | Manual Installation

```bash
# 1. 复制函数文件到主目录
cp functions/devup-functions.sh ~/

# 2. 添加到 shell 配置文件
# For zsh:
echo 'source $HOME/devup-functions.sh' >> ~/.zshrc

# For bash:
echo 'source $HOME/devup-functions.sh' >> ~/.bashrc

# 3. 重新加载配置
source ~/.zshrc  # or source ~/.bashrc
```

## 配置 | Configuration

### devup 函数默认配置
默认配置适用于 `uc-frontend` 项目，无需修改即可使用：

```bash
# 默认路径（适用于大多数情况）
package_dir="~/development/uc-frontend/packages/modal--agent-orders.react"
app_dir="~/development/uc-frontend/apps/lab"
package_name="@uc/modal--agent-orders.react"
```

### 自定义配置
如需修改，编辑 `~/devup-functions.sh`：

```bash
# 自定义配置示例
local package_dir="~/your-project/packages/your-package"
local app_dir="~/your-project/apps/your-app"
local package_name="@your-org/your-package-name"
```

## 使用方法 | Usage

### devup 命令
```bash
devup  # 执行完整的包更新和启动流程
```

该命令将：
1. 切换到包目录并执行 `pnpm pack`
2. 切换回应用目录
3. 移除现有的包
4. 安装最新打包的本地包
5. 启动开发服务器

## 支持的环境 | Supported Environments

- ✅ macOS (zsh/bash)
- ✅ Linux (zsh/bash)
- ✅ Windows WSL (zsh/bash)

## 贡献 | Contributing

欢迎提交 Issue 和 Pull Request！

Welcome to submit Issues and Pull Requests!

## 许可证 | License

MIT License
