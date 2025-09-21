# CICD系统 - 代理地址使用说明

## 🔗 正确的代理地址格式

### Git仓库地址
- **代理克隆地址**: `https://xget.xi-xu.me/gh/hanxiaochi/CICD-pate.git`
- **原始GitHub地址**: `https://github.com/hanxiaochi/CICD-pate.git`

### Raw文件下载地址
- **代理Raw地址**: `https://xget.xi-xu.me/gh/hanxiaochi/CICD-pate/raw/master/文件名`
- **原始Raw地址**: `https://raw.githubusercontent.com/hanxiaochi/CICD-pate/master/文件名`

## 🚀 云服务器一键部署命令（已修复）

### 方式1：完整流程一键部署
```bash
curl -fsSL https://xget.xi-xu.me/gh/hanxiaochi/CICD-pate/raw/master/cloud_test_workflow.sh | bash -s full
```

### 方式2：分步部署
```bash
# 清理环境
curl -fsSL https://xget.xi-xu.me/gh/hanxiaochi/CICD-pate/raw/master/cloud_cleanup.sh | bash -s -- --force

# 部署系统
curl -fsSL https://xget.xi-xu.me/gh/hanxiaochi/CICD-pate/raw/master/cloud_deploy.sh | bash

# 验证测试  
curl -fsSL https://xget.xi-xu.me/gh/hanxiaochi/CICD-pate/raw/master/cloud_verify.sh | bash
```

### 方式3：快速代理部署
```bash
curl -fsSL https://xget.xi-xu.me/gh/hanxiaochi/CICD-pate/raw/master/quick_proxy_deploy.sh | bash
```

### 方式4：交互式菜单
```bash
# 下载工作流脚本
curl -fsSL https://xget.xi-xu.me/gh/hanxiaochi/CICD-pate/raw/master/cloud_test_workflow.sh -o workflow.sh
chmod +x workflow.sh

# 运行交互式菜单
./workflow.sh
```

## 📋 各个脚本的功能

| 脚本名称 | 功能 | 推荐使用场景 |
|---------|------|-------------|
| `cloud_test_workflow.sh` | 完整测试流程管理 | 自动化测试、完整部署 |
| `cloud_cleanup.sh` | 清理所有CICD相关内容 | 重置环境、清理旧部署 |
| `cloud_deploy.sh` | 自动部署CICD系统 | 全新环境部署 |  
| `cloud_verify.sh` | 验证系统功能 | 部署后验证、状态检查 |
| `quick_proxy_deploy.sh` | 代理加速快速部署 | 网络较慢时使用 |

## ✅ URL修复说明

修复了以下错误的URL格式：
- ❌ 错误：`https://raw.xget.xi-xu.me/gh/hanxiaochi/CICD-pate/master/`
- ✅ 正确：`https://xget.xi-xu.me/gh/hanxiaochi/CICD-pate/raw/master/`

主要差异：
1. 删除了开头的 `raw.` 前缀
2. 将 `/master/` 改为 `/raw/master/`

## 🧪 测试验证

在云服务器上测试正确的URL：
```bash
# 测试文件下载
curl -I https://xget.xi-xu.me/gh/hanxiaochi/CICD-pate/raw/master/cloud_deploy.sh

# 应该返回 200 OK 状态码
```

## 💡 使用建议

1. **首次部署**：使用完整流程一键部署
2. **重新部署**：先清理再部署
3. **网络较慢**：使用快速代理部署脚本
4. **调试测试**：使用交互式菜单逐步操作

现在所有URL都已修复，可以正常使用代理加速功能！