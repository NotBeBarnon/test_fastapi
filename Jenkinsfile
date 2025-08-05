pipeline {
    agent {
        docker {
            image 'python:3.11-slim'
            args '-v /var/run/docker.sock:/var/run/docker.sock --pull never'   // 本地有就不再 pull
        }
    }

    environment {
        // 镜像名（不含 tag）
        IMAGE_NAME = 'frp.z33.fun:23827/test_fastapi-demo'
        REGISTRY   = 'http://frp.z33.fun:23827'

        // 凭据 ID（与 Jenkins 全局凭据保持一致）
        REGISTRY_CREDS = credentials('registry-auth')   // Username/Password
        SSH_CREDS      = 'prod-ssh'                     // SSH Username with private key
        DEPLOY_HOST    = 'frp.z33.fun'
        DEPLOY_PORT    = '23822'
        DEPLOY_USER    = 'bistu'
        APP_PORT       = '8099'
        DOCKER_PORT    = '8089'
    }

    stages {
        /* ---------- 1. 拉取源码 ---------- */
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    // 获取当前分支名称
                    BRANCH_NAME = env.BRANCH_NAME
                    echo "当前分支：${BRANCH_NAME}"
                }
            }
        }

        /* ---------- 2. 单元测试 ---------- */
        stage('Test') {
            steps {
                sh 'python3 -m pip install --upgrade pip'
                sh 'python3 -m pip install -r requirements.txt'
                sh 'pytest app/ -v'  // 确保测试运行
            }
        }

        /* ---------- 3. 构建镜像 ---------- */
        stage('Build & Tag') {
            steps {
                script {
                    dockerImage = docker.build("${IMAGE_NAME}:${BUILD_NUMBER}")
                }
            }
        }

        /* ---------- 4. 推送镜像 ---------- */
        stage('Push') {
            steps {
                script {
                    docker.withRegistry("${REGISTRY}", 'registry-auth') {
                        dockerImage.push()
                    }
                }
            }
        }


        /* ---------- 5. 部署到目标服务器 ---------- */
        stage('Deploy') {
            when {
                // 如果是开发或测试分支，自动部署
                expression {
                    return BRANCH_NAME == 'dev' || BRANCH_NAME == 'test'
                }
            }
            steps {
                sh 'apt-get update && apt-get install -y openssh-client'   // 先装 ssh
                sshagent(credentials: ["${SSH_CREDS}"]) {
                    sh """
                       ssh -o StrictHostKeyChecking=no \
                           -p ${DEPLOY_PORT} \
                           ${DEPLOY_USER}@${DEPLOY_HOST} << 'ENDSSH'
set -e
echo "Pulling Docker image: ${IMAGE_NAME}:${BUILD_NUMBER}"
docker pull ${IMAGE_NAME}:${BUILD_NUMBER}
echo "Stopping and removing existing container: fastapi-demo"
docker stop fastapi-demo || true
docker rm fastapi-demo || true
echo "Running new container: fastapi-demo"
docker run -d --name fastapi-demo \
           -p ${APP_PORT}:${DOCKER_PORT} \
           --restart unless-stopped \
           ${IMAGE_NAME}:${BUILD_NUMBER}
echo "Deployment completed successfully."
ENDSSH
                    """
                }
            }
        }

        /* ---------- 6. 手动部署到生产环境 ---------- */
        stage('Manual Deploy to Production') {
            when {
                // 如果是生产分支，手动触发部署
                expression {
                    return BRANCH_NAME == 'main' || BRANCH_NAME == 'master'
                }
            }
            steps {
                input {
                    message: "是否确认部署到生产环境？",
                    ok: "确认部署",
                    timeout(time: 1, unit: 'HOURS')
                }
                sh 'apt-get update && apt-get install -y openssh-client'   // 先装 ssh
                sshagent(credentials: ["${SSH_CREDS}"]) {
                    sh """
                       ssh -o StrictHostKeyChecking=no \
                           -p ${DEPLOY_PORT} \
                           ${DEPLOY_USER}@${DEPLOY_HOST} << 'ENDSSH'
set -e
echo "Pulling Docker image: ${IMAGE_NAME}:${BUILD_NUMBER}"
docker pull ${IMAGE_NAME}:${BUILD_NUMBER}
echo "Stopping and removing existing container: fastapi-demo"
docker stop fastapi-demo || true
docker rm fastapi-demo || true
echo "Running new container: fastapi-demo"
docker run -d --name fastapi-demo \
           -p ${APP_PORT}:${DOCKER_PORT} \
           --restart unless-stopped \
           ${IMAGE_NAME}:${BUILD_NUMBER}
echo "Deployment completed successfully."
ENDSSH
                    """
                }
            }
        }
    }

    post {
        always  { echo 'Pipeline finished.' }
        failure {
            echo 'Build failed! Check logs for details.'
            // 可选：发送通知或保存日志
        }
    }
}