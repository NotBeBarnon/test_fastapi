# 一、Docker compose安装jenkins
运行地址：http://frp.z33.fun:23825/
###  1. 编写docker-compose.yml
```
version: '3.8'

services:
  jenkins:
    image: jenkins/jenkins:lts #选择最新的长期维护版本即可
    container_name: jenkins-docker #容器名称
    restart: always #
    privileged: true # 启用权限以便容器内能使用 docker
    user: root  # 避免权限问题
    ports:
      - "8080:8080"   # Web UI 端口映射
      - "50000:50000" # Agent 连接端口
    volumes:
      - ./jenkins_home:/var/jenkins_home  # 数据持久化
      - /var/run/docker.sock:/var/run/docker.sock # 宿主机docker控制
      - /usr/bin/docker:/usr/bin/docker   # 宿主机docker命令‘
    environment:
      - TZ=Asia/Shanghai  # 时区设置

```
### 2. Jenkins 插件
####Git
####Pipeline
####Docker Pipeline（可选，方便写脚本）
####SSH Agent（用于远程部署）

### 3. 凭据（Credentials）
(系统管理 → Manage Credentials → 全局)
，要与Jenkinsfile变量匹配
####3.1 CODING Git
Kind: Username with password

ID: coding-git
####3.2 自建 Registry
Kind: 
Username with password

ID: registry-auth
####3.3 目标服务器 ssh key
(注意：使用ed25519，并且保证authorized_keys文件存了公钥

部署服务器须设置可以通过ssh私钥登录：
```
/etc/ssh/sshd_config

PubkeyAuthentication yes
AuthorizedKeysFile	.ssh/authorized_keys)
```


Kind: SSH Username with private key

ID: prod-ssh

# 二、Docker compose 部署docker-registry
运行地址： http://frp.z33.fun:23828/

###1. 账号密码认证
admin:123456
```
# 1. 安装 htpasswd（若已装可跳过）
sudo apt-get update && sudo apt-get install -y apache2-utils

# 2. 建目录
mkdir -p /opt/registry/auth

# 3. 创建第一个用户 admin / 123456 （可随意改）
htpasswd -Bc /opt/registry/auth/htpasswd admin
# 后续再加用户：
# htpasswd -B /opt/registry/auth/htpasswd user2
```
###2.docker-compose.yml
#### 2.1 registry 私有库
#### 2.2 browser UI
```
version: "3.8"

services:
  registry:
    image: registry:2.8.3
    container_name: registry
    restart: unless-stopped
    ports:
      - "9090:5000"
    environment:
      - TZ=Asia/Shanghai
      - REGISTRY_STORAGE_DELETE_ENABLED=true
      - REGISTRY_AUTH=htpasswd
      - REGISTRY_AUTH_HTPASSWD_REALM=Registry-Realm
      - REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd
    volumes:
      - ./data:/var/lib/registry
      - /opt/registry/auth:/auth        # 挂载密码文件

  browser:
    image: klausmeyer/docker-registry-browser:latest
    container_name: registry-browser
    restart: unless-stopped
    ports:
      - "9091:8080"
    environment:
      - TZ=Asia/Shanghai
      - DOCKER_REGISTRY_URL=http://registry:5000/v2
      - ENABLE_DELETE_IMAGES=true
      - SECRET_KEY_BASE=a1b2c3d4e
      # 如需汉化界面，可再挂载汉化 views 目录
      # - ./zh-CN-views:/app/app/views
    depends_on:
      - registry

```
###3. 异常：server gave HTTP response to HTTPS client
#### 3.1 给 Registry 配 TLS 证书（Let's Encrypt、自签、Nginx 反向代理均可）
#### 3.2 快速绕过：告诉 Docker 客户端这个地址允许 HTTP
```
/etc/docker/daemon.json 增加：
{
  "insecure-registries": ["frp.z33.fun:23827"]
}
```

# 三、项目配置

### 1. Jenkinsfile（根目录放置）
```
pipeline {
    agent any

    environment {
        // 镜像名
        IMAGE_NAME      = "frp.z33.fun:23827/fastapi-demo"
        IMAGE_TAG       = "${env.BUILD_NUMBER}"
        CONTAINER_NAME  = "fastapi-demo"
        // 远程部署目录
        DEPLOY_PATH     = "/opt/fastapi-demo"
        // 远程 compose 文件
        COMPOSE_FILE    = "docker-compose.yml"
    }

    stages {
        stage('Checkout') {
            steps {
                git credentialsId: 'coding-git',
                    url: 'https://serverless-100037545359.coding.net/p/test_fastapi/d/test_fastapi/git',
                    branch: 'main'
            }
        }

        stage('Unit Test') {
            steps {
                sh '''
                  python -m pip install --upgrade pip
                  pip install -r requirements.txt
                  pytest -q
                '''
            }
        }

        stage('Build & Push') {
            steps {
                script {
                    docker.withRegistry("http://frp.z33.fun:23827", "registry-auth") {
                        def img = docker.build("${IMAGE_NAME}:${IMAGE_TAG}", ".")
                        img.push()
                        img.push("latest")
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                sshagent (credentials: ['prod-ssh']) {
                    sh """
                       ssh -o StrictHostKeyChecking=no root@frp.z33.fun << 'ENDSSH'
                         cd ${DEPLOY_PATH}
                         # 更新 compose 文件里的 image tag
                         sed -i "s|image: .*|image: ${IMAGE_NAME}:${IMAGE_TAG}|" ${COMPOSE_FILE}
                         docker-compose pull ${CONTAINER_NAME}
                         docker-compose up -d --no-deps --force-recreate ${CONTAINER_NAME}
                       ENDSSH
                    """
                }
            }
        }
    }
}
```
#### Dockerfile
```
FROM python:3.11-slim AS builder
WORKDIR /code
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim
WORKDIR /code
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
EXPOSE 8089
CMD ["python", "main.py"]
```
