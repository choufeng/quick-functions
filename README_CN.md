# Quick Functions 🚀

> **Language | 语言**: [🇺🇸 English](README.md) | [🇨🇳 中文](README_CN.md)

一个便捷的终端工具函数库，帮助开发者快速设置常用的 shell 函数。

## 功能特性

### `devup` - Node.js 本地包强制更新工具
强制更新本地 Node.js 包并启动开发服务器的自动化工具。特别适用于 monorepo 项目中的本地包开发。

- 🔄 自动执行 `pnpm pack` 构建最新包
- 📦 智能查找最新的 `.tgz` 文件（按修改时间排序）
- 🗑️ 强制移除并重新安装包（解决相同版本不更新问题）
- 🚀 自动启动开发服务器
- 🌍 中英文双语提示
- 💻 支持 zsh 和 bash
- 🖥️ 跨平台兼容（macOS/Linux）
- 🛡️ 安全路径处理（支持空格和特殊字符）

## 快速安装

```bash
# 克隆项目
git clone https://github.com/choufeng/quick-functions ~/quick-functions
cd ~/quick-functions

# 安装
./install.sh

# 开始使用
devup
```

## 手动安装

```bash
# 1. 复制函数文件到主目录
cp functions/devup-functions.sh ~/.quick-functions/functions/

# 2. 添加到 shell 配置文件
# 对于 zsh：
echo 'source $HOME/.quick-functions/load.sh' >> ~/.zshrc

# 对于 bash：
echo 'source $HOME/.quick-functions/load.sh' >> ~/.bashrc

# 3. 重新加载配置
source ~/.zshrc  # 或 source ~/.bashrc
```

## 配置

### devup 函数默认配置
默认配置适用于 `uc-frontend` 项目，无需修改即可使用：

```bash
# 默认路径（适用于大多数情况）
package_dir="~/development/uc-frontend/packages/modal--agent-orders.react"
app_dir="~/development/uc-frontend/apps/lab"
package_name="@uc/modal--agent-orders.react"
```

### 自定义配置
如需修改，请编辑 `~/.quick-functions/functions/devup-functions.sh`：

```bash
# 自定义配置示例
local package_dir="~/your-project/packages/your-package"
local app_dir="~/your-project/apps/your-app"
local package_name="@your-org/your-package-name"
```

## 使用方法

### devup 命令
```bash
devup  # 执行完整的包更新和启动流程
```

该命令将执行以下步骤：
1. 切换到包目录并执行 `pnpm pack`
2. 切换回应用目录
3. 移除现有的包
4. 安装最新打包的本地包
5. 启动开发服务器

### 配置助手
```bash
devup_config  # 显示当前配置
```

## 管理

### 更新函数
```bash
~/.quick-functions/update.sh  # 从 git 仓库更新
```

## 安装位置

安装程序会创建一个安全的安装目录：

```
~/.quick-functions/
├── functions/
│   └── devup-functions.sh
├── load.sh              # 所有函数的自动加载器
└── update.sh            # 更新脚本
```

## 支持的环境

- ✅ macOS (zsh/bash)
- ✅ Linux (zsh/bash)
- ✅ Windows WSL (zsh/bash)
- ✅ 支持路径中包含空格和特殊字符

## 路径安全

本项目处理路径安全问题：
- ✅ 支持包含空格的克隆路径（例如：`/Users/John Doe/My Projects/`）
- ✅ 支持路径中的特殊字符
- ✅ 使用固定安装目录 `~/.quick-functions`
- ✅ 所有路径都经过适当的引用和转义

## 贡献

欢迎提交 Issues 和 Pull Requests！

### 开发流程
```bash
# 1. Fork 并克隆
git clone <your-fork>

# 2. 在 functions/ 目录中进行修改
# 3. 使用 ./test.sh 进行测试
# 4. 提交 PR
```

## 许可证

MIT License

---

**Quick Functions** - 让终端开发更快更简单！🚀
