# Doris通过JDBC Catalog连接达梦数据库

## 支持情况

Doris 从 2.0.0 版本开始支持通过 JDBC Catalog 连接外部数据库，包括达梦数据库。JDBC Catalog 允许 Doris 直接查询和操作外部数据库中的表，而无需将数据导入到 Doris 中。

## 连接案例

### 1. 创建JDBC Catalog

```sql
-- 创建达梦数据库的JDBC Catalog
CREATE CATALOG dm_catalog PROPERTIES (
    "type" = "jdbc",
    "user" = "SYSDBA",
    "password" = "SYSDBA",
    "jdbc_url" = "jdbc:dm://192.168.1.100:5236",
    "driver_url" = "dmjdbc8-8.1.2.131.jar",
    "driver_class" = "dm.jdbc.driver.DmDriver"
);
```

### 2. 查看达梦数据库中的表

```sql
-- 查看达梦数据库中的数据库
SHOW DATABASES FROM dm_catalog;

-- 查看达梦数据库中的表
SHOW TABLES FROM dm_catalog.数据库名;

-- 查看表结构
DESC dm_catalog.数据库名.表名;
```

### 3. 查询达梦数据库中的数据

```sql
-- 直接查询达梦数据库中的数据
SELECT * FROM dm_catalog.数据库名.表名 LIMIT 10;

-- 与Doris表进行联合查询
SELECT a.*, b.* 
FROM doris_table a
JOIN dm_catalog.数据库名.表名 b
ON a.id = b.id;
```

### 4. 导入达梦数据到Doris

```sql
-- 导入达梦数据到Doris表
INSERT INTO doris_table
SELECT * FROM dm_catalog.数据库名.表名;
```

## 配置说明

### 必需参数

| 参数 | 说明 | 示例 |
|------|------|------|
| type | 固定为 "jdbc" | "jdbc" |
| user | 达梦数据库用户名 | "SYSDBA" |
| password | 达梦数据库密码 | "SYSDBA" |
| jdbc_url | 达梦数据库JDBC连接URL | "jdbc:dm://192.168.1.100:5236" |
| driver_url | 达梦JDBC驱动jar包路径 | "dmjdbc8-8.1.2.131.jar" |
| driver_class | 达梦JDBC驱动类名 | "dm.jdbc.driver.DmDriver" |

### 注意事项

1. **驱动配置**：需要将达梦JDBC驱动jar包放置在Doris的`fe/lib`目录下，或通过`driver_url`指定jar包路径
2. **权限配置**：确保Doris FE节点能够访问到达梦数据库
3. **版本兼容性**：建议使用Doris 2.0.0及以上版本，达梦数据库8.0及以上版本
4. **性能优化**：对于大表查询，建议使用分区裁剪和索引优化

## 完整示例

### 1. 准备工作

1. 下载达梦JDBC驱动：从达梦官网下载对应版本的JDBC驱动
2. 将驱动jar包复制到Doris FE节点的`fe/lib`目录
3. 重启Doris FE服务

### 2. 创建Catalog

```sql
-- 登录Doris客户端
mysql -h 127.0.0.1 -P 9030 -u root

-- 创建达梦JDBC Catalog
CREATE CATALOG dm_catalog PROPERTIES (
    "type" = "jdbc",
    "user" = "SYSDBA",
    "password" = "SYSDBA",
    "jdbc_url" = "jdbc:dm://192.168.1.100:5236",
    "driver_url" = "dmjdbc8-8.1.2.131.jar",
    "driver_class" = "dm.jdbc.driver.DmDriver"
);
```

### 3. 使用Catalog查询数据

```sql
-- 查看达梦数据库
SHOW DATABASES FROM dm_catalog;

-- 查看表
SHOW TABLES FROM dm_catalog.TESTDB;

-- 查询数据
SELECT * FROM dm_catalog.TESTDB.USER_INFO LIMIT 10;

-- 导入数据到Doris
CREATE TABLE doris_user_info LIKE dm_catalog.TESTDB.USER_INFO;
INSERT INTO doris_user_info SELECT * FROM dm_catalog.TESTDB.USER_INFO;
```

## 故障排查

### 常见问题

1. **驱动加载失败**：确保驱动jar包路径正确，且Doris FE服务已重启
2. **连接失败**：检查达梦数据库地址、端口、用户名和密码是否正确
3. **权限不足**：确保达梦数据库用户有足够的权限
4. **性能问题**：对于大表查询，考虑使用分区裁剪和索引优化

### 调试命令

```sql
-- 查看Catalog状态
SHOW CATALOGS;

-- 查看Catalog详细信息
SHOW CREATE CATALOG dm_catalog;
```

通过以上配置和示例，您可以在Doris中成功连接和使用达梦数据库的数据。