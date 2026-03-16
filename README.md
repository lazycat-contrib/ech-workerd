# ECH-Workerd

ECH (Encrypted Client Hello) 加密代理服务，支持 SOCKS5/HTTP 代理协议。

## 功能特性

- 🔐 **ECH 加密** - 支持 Encrypted Client Hello，增强隐私保护
- 🌐 **双协议支持** - 同时支持 SOCKS5 和 HTTP 代理
- 📊 **状态面板** - 内置 Web 状态监控面板
- 🔄 **智能分流** - 支持全局代理、国内直连、无规则三种模式
- 📝 **详细日志** - 完善的日志系统，支持多种日志级别和自动轮转

## 安装说明

### 必填参数

| 参数 | 说明 | 示例 |
|------|------|------|
| 代理服务器 (`proxy_server`) | 后端代理服务器地址 | `example.com:443` |

### 可选参数

#### 身份验证
| 参数 | 说明 | 默认值 |
|------|------|--------|
| 代理令牌 (`proxy_token`) | 身份验证令牌 | 空 |
| 服务器 IP (`proxy_server_ip`) | 直接指定 IP，跳过 DNS | 空 |

#### SOCKS5 鉴权
| 参数 | 说明 | 默认值 |
|------|------|--------|
| SOCKS5 用户名 (`proxy_socks5_user`) | SOCKS5 代理用户名 | 空 |
| SOCKS5 密码 (`proxy_socks5_pass`) | SOCKS5 代理密码 | 空 |

#### ECH 配置
| 参数 | 说明 | 默认值 |
|------|------|--------|
| DNS 服务器 (`proxy_dns`) | DoH 服务器 | `dns.alidns.com/dns-query` |
| ECH 域名 (`proxy_ech_domain`) | ECH 查询域名 | `cloudflare-ech.com` |

#### 分流配置
| 参数 | 说明 | 默认值 |
|------|------|--------|
| 分流模式 (`proxy_routing`) | 流量路由模式 | `global` |

**分流模式说明：**
- `global` - 全局代理：所有流量都通过代理
- `bypass_cn` - 国内直连：中国 IP 直连，其他流量走代理
- `none` - 无规则：不应用分流规则

#### IP 列表配置（用于 bypass_cn 模式）
| 参数 | 说明 | 默认值 |
|------|------|--------|
| IPv4 列表文件 (`proxy_ipv4_file`) | 自定义 IPv4 文件路径 | 空（使用默认） |
| IPv6 列表文件 (`proxy_ipv6_file`) | 自定义 IPv6 文件路径 | 空（使用默认） |
| IPv4 列表 URL (`proxy_ipv4_url`) | 自定义下载地址 | 空（GitHub 默认源） |
| IPv6 列表 URL (`proxy_ipv6_url`) | 自定义下载地址 | 空（GitHub 默认源） |
| 自动更新 IP 列表 (`proxy_ip_auto_update`) | 每次启动重新下载 | `false` |

#### GeoIP 数据库配置
| 参数 | 说明 | 默认值 |
|------|------|--------|
| 启用 GeoIP (`proxy_geoip_enabled`) | 启用 GeoIP 数据库 | `true` |
| GeoIP 文件路径 (`proxy_geoip_file`) | GeoIP 数据库路径 | 空（使用默认） |
| GeoIP 下载地址 (`proxy_geoip_url`) | GeoIP 下载地址 | 空（自动获取最新） |

#### 日志配置
| 参数 | 说明 | 默认值 |
|------|------|--------|
| 日志级别 (`proxy_log_level`) | debug/info/warn/error | `info` |
| 日志文件最大大小 (`proxy_log_max_mb`) | 单文件最大 MB | `100` |
| 日志备份数量 (`proxy_log_backup`) | 保留文件数量 | `7` |
| 压缩旧日志 (`proxy_log_compress`) | 是否压缩旧日志 | `true` |

## 使用方法

### 1. 配置代理客户端

安装完成后，在代理客户端（如 Clash、Surge 等）配置：

```yaml
proxies:
  - name: "ECH-Workerd"
    type: socks5
    server: <your-lazycat-domain>
    port: 1080
```

### 2. 访问状态面板

打开浏览器访问：`https://<your-subdomain>.lazycat.cloud/`

### 3. 查看健康状态

```bash
curl https://<your-subdomain>.lazycat.cloud/api/health
```

## 端口说明

| 端口 | 协议 | 说明 |
|------|------|------|
| 1080 | TCP | SOCKS5/HTTP 代理端口（对外） |
| 30001 | HTTP | 状态面板（内部映射） |

## 目录结构

```
/lzcapp/var/logs/    # 日志文件
/lzcapp/var/data/    # IP 列表数据（bypass_cn 模式）
```

## 构建与发布

```bash
# 赋予执行权限
chmod +x build.sh

# 运行构建工具
./build.sh
```

### 构建选项

1. **构建应用** - 生成 .lpk 安装包
2. **复制镜像** - 将镜像复制到懒猫仓库
3. **发布应用** - 发布到应用商店
4. **一键发布** - 完整的发布流程
5. **查看信息** - 显示应用配置
6. **验证配置** - 检查配置文件语法

## 资源限制

- 内存: 128MB
- CPU: 0.5 核

## 故障排查

### 查看日志

```bash
# 进入容器
docker exec -it ech-workerd sh

# 查看日志
cat /app/logs/proxy.log

# 实时查看日志
tail -f /app/logs/proxy.log
```

### 健康检查

```bash
# 内部检查
docker exec ech-workerd wget -qO- http://localhost:30001/api/health

# 外部检查
curl https://<your-subdomain>.lazycat.cloud/api/health
```

### 常见问题

1. **代理无法连接**
   - 检查 `proxy_server` 配置是否正确
   - 检查后端服务是否可用

2. **分流不生效**
   - 确保 `proxy_routing` 设置为 `bypass_cn`
   - 检查 IP 列表是否下载成功（查看日志）

3. **内存不足**
   - 检查日志文件大小
   - 调整 `proxy_log_max_mb` 和 `proxy_log_backup` 参数

## 许可证

MIT License

## 作者

ECH-Workerd Team